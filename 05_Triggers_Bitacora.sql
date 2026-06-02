
/* ============================================================
   1. SECUENCIAS DE APOYO
   ------------------------------------------------------------
   Se crean secuencias para generar identificadores automáticos
   en la bitácora y en los movimientos de cuenta.

   Se usa bloque PL/SQL para evitar error si la secuencia ya existe.
   ============================================================ */

BEGIN
    EXECUTE IMMEDIATE '
        CREATE SEQUENCE SEQ_BITACORA_AUDITORIA
        START WITH 1
        INCREMENT BY 1
        NOCACHE
    ';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -955 THEN
            RAISE;
        END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE '
        CREATE SEQUENCE SEQ_MOVIMIENTOS_CUENTA
        START WITH 1
        INCREMENT BY 1
        NOCACHE
    ';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -955 THEN
            RAISE;
        END IF;
END;
/


/* ============================================================
   2. PROCEDIMIENTO PARA REGISTRAR BITÁCORA
   ------------------------------------------------------------
   Este procedimiento centraliza el registro de acciones en la
   tabla BITACORA_AUDITORIA.

   Se utiliza PRAGMA AUTONOMOUS_TRANSACTION para que la bitácora
   se guarde aunque una operación falle y se haga ROLLBACK.
   Esto es importante para registrar intentos fallidos.
   ============================================================ */

CREATE OR REPLACE PROCEDURE SP_REGISTRAR_BITACORA (
    P_TABLA_AFECTADA IN VARCHAR2,
    P_ID_REGISTRO    IN VARCHAR2,
    P_ACCION         IN VARCHAR2,
    P_VALOR_ANTERIOR IN CLOB,
    P_VALOR_NUEVO    IN CLOB,
    P_RESULTADO      IN VARCHAR2,
    P_DESCRIPCION    IN VARCHAR2
)
IS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO BITACORA_AUDITORIA (
        ID_BITACORA,
        USUARIO_BD,
        FECHA_EVENTO,
        TABLA_AFECTADA,
        ID_REGISTRO,
        ACCION,
        VALOR_ANTERIOR,
        VALOR_NUEVO,
        RESULTADO,
        DESCRIPCION
    )
    VALUES (
        SEQ_BITACORA_AUDITORIA.NEXTVAL,
        USER,
        SYSDATE,
        P_TABLA_AFECTADA,
        P_ID_REGISTRO,
        P_ACCION,
        P_VALOR_ANTERIOR,
        P_VALOR_NUEVO,
        P_RESULTADO,
        P_DESCRIPCION
    );

    COMMIT;
END;
/


/* ============================================================
   3. TRIGGER PARA VALIDAR MONTO DEL CHEQUE
   ------------------------------------------------------------
   Este trigger valida que el usuario que genera el cheque tenga
   permitido emitir cheques dentro del rango configurado en la
   tabla USUARIOS_SISTEMA.

   También marca automáticamente si el cheque requiere auditoría
   o gerencia:
   - Q 5,000.00 o más requiere auditoría.
   - Q 25,000.00 o más requiere gerencia.
   ============================================================ */

CREATE OR REPLACE TRIGGER TRG_CHEQUES_VALIDAR_MONTO
BEFORE INSERT OR UPDATE OF MONTO, ID_ESTADO ON CHEQUES
FOR EACH ROW
DECLARE
    V_MONTO_MINIMO  USUARIOS_SISTEMA.MONTO_MINIMO%TYPE;
    V_MONTO_MAXIMO  USUARIOS_SISTEMA.MONTO_MAXIMO%TYPE;
    V_USUARIO       USUARIOS_SISTEMA.USUARIO_BD%TYPE;
BEGIN
    /* Si el cheque está disponible, no se valida monto porque todavía no se genera. */
    IF :NEW.ID_ESTADO = 1 THEN
        :NEW.REQUIERE_AUDITORIA := 'N';
        :NEW.REQUIERE_GERENCIA := 'N';
        RETURN;
    END IF;

    V_USUARIO := NVL(:NEW.USUARIO_GENERA, USER);

    SELECT MONTO_MINIMO, MONTO_MAXIMO
    INTO V_MONTO_MINIMO, V_MONTO_MAXIMO
    FROM USUARIOS_SISTEMA
    WHERE UPPER(USUARIO_BD) = UPPER(V_USUARIO)
      AND ESTADO = 'A';

    /* Asignación automática de niveles de autorización. */
    IF :NEW.MONTO >= 5000 THEN
        :NEW.REQUIERE_AUDITORIA := 'S';
    ELSE
        :NEW.REQUIERE_AUDITORIA := 'N';
    END IF;

    IF :NEW.MONTO >= 25000 THEN
        :NEW.REQUIERE_GERENCIA := 'S';
    ELSE
        :NEW.REQUIERE_GERENCIA := 'N';
    END IF;

    /* Validación del rango permitido para el usuario. */
    IF :NEW.MONTO < V_MONTO_MINIMO OR :NEW.MONTO > V_MONTO_MAXIMO THEN

        SP_REGISTRAR_BITACORA(
            'CHEQUES',
            TO_CHAR(:NEW.ID_CHEQUE),
            'INTENTO FALLIDO',
            NULL,
            'Usuario: ' || V_USUARIO ||
            ', Monto intentado: Q' || TO_CHAR(:NEW.MONTO),
            'FALLIDO',
            'El usuario intentó generar un cheque fuera del rango permitido.'
        );

        RAISE_APPLICATION_ERROR(
            -20001,
            'El usuario no tiene permiso para generar cheques por este monto.'
        );
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        SP_REGISTRAR_BITACORA(
            'CHEQUES',
            TO_CHAR(:NEW.ID_CHEQUE),
            'INTENTO FALLIDO',
            NULL,
            'Usuario: ' || V_USUARIO,
            'FALLIDO',
            'El usuario no existe, está inactivo o no tiene rango de emisión configurado.'
        );

        RAISE_APPLICATION_ERROR(
            -20002,
            'Usuario no configurado para emitir cheques.'
        );
END;
/


/* ============================================================
   4. TRIGGER PARA VALIDAR LIBERACIÓN DE AUDITORÍA Y GERENCIA
   ------------------------------------------------------------
   Este trigger evita que un cheque avance de estado sin las
   autorizaciones necesarias.

   Reglas:
   - Si el monto es Q 5,000.00 o más, necesita firma de auditoría.
   - Si el monto es Q 25,000.00 o más, necesita firma de gerencia
     antes de ser entregado.
   ============================================================ */

CREATE OR REPLACE TRIGGER TRG_CHEQUES_VALIDAR_LIBERACION
BEFORE UPDATE OF ID_ESTADO ON CHEQUES
FOR EACH ROW
BEGIN
    /* Validación de auditoría para cheques iguales o mayores a Q 5,000.00 */
    IF :NEW.MONTO >= 5000 AND :NEW.ID_ESTADO IN (3, 4) THEN
        IF :NEW.FIRMA_AUDITORIA IS NULL THEN

            SP_REGISTRAR_BITACORA(
                'CHEQUES',
                TO_CHAR(:NEW.ID_CHEQUE),
                'INTENTO FALLIDO',
                'Estado anterior: ' || TO_CHAR(:OLD.ID_ESTADO),
                'Estado intentado: ' || TO_CHAR(:NEW.ID_ESTADO),
                'FALLIDO',
                'El cheque requiere liberación de auditoría.'
            );

            RAISE_APPLICATION_ERROR(
                -20003,
                'El cheque requiere liberación de auditoría antes de continuar.'
            );
        END IF;
    END IF;

    /* Validación de gerencia para cheques iguales o mayores a Q 25,000.00 */
    IF :NEW.MONTO >= 25000 AND :NEW.ID_ESTADO = 4 THEN
        IF :NEW.FIRMA_GERENCIA IS NULL THEN

            SP_REGISTRAR_BITACORA(
                'CHEQUES',
                TO_CHAR(:NEW.ID_CHEQUE),
                'INTENTO FALLIDO',
                'Estado anterior: ' || TO_CHAR(:OLD.ID_ESTADO),
                'Estado intentado: ' || TO_CHAR(:NEW.ID_ESTADO),
                'FALLIDO',
                'El cheque requiere liberación de gerencia.'
            );

            RAISE_APPLICATION_ERROR(
                -20004,
                'El cheque requiere liberación de gerencia antes de ser entregado.'
            );
        END IF;
    END IF;
END;
/


/* ============================================================
   5. TRIGGER DE BITÁCORA AL INSERTAR CHEQUES
   ------------------------------------------------------------
   Registra en bitácora cada cheque creado en el sistema.
   ============================================================ */

CREATE OR REPLACE TRIGGER TRG_BITACORA_INSERT_CHEQUE
AFTER INSERT ON CHEQUES
FOR EACH ROW
BEGIN
    SP_REGISTRAR_BITACORA(
        'CHEQUES',
        TO_CHAR(:NEW.ID_CHEQUE),
        'INSERT',
        NULL,
        'Cheque No. ' || TO_CHAR(:NEW.NUMERO_CHEQUE) ||
        ', Monto: Q' || NVL(TO_CHAR(:NEW.MONTO), '0') ||
        ', Estado: ' || TO_CHAR(:NEW.ID_ESTADO),
        'EXITO',
        'Se registró un nuevo cheque en el sistema.'
    );
END;
/


/* ============================================================
   6. TRIGGER DE BITÁCORA AL MODIFICAR CHEQUES
   ------------------------------------------------------------
   Registra cambios importantes realizados sobre un cheque.
   ============================================================ */

CREATE OR REPLACE TRIGGER TRG_BITACORA_UPDATE_CHEQUE
AFTER UPDATE ON CHEQUES
FOR EACH ROW
BEGIN
    SP_REGISTRAR_BITACORA(
        'CHEQUES',
        TO_CHAR(:OLD.ID_CHEQUE),
        'UPDATE',
        'Monto anterior: Q' || NVL(TO_CHAR(:OLD.MONTO), '0') ||
        ', Estado anterior: ' || TO_CHAR(:OLD.ID_ESTADO) ||
        ', Beneficiario anterior: ' || NVL(TO_CHAR(:OLD.ID_BENEFICIARIO), 'SIN BENEFICIARIO'),
        'Monto nuevo: Q' || NVL(TO_CHAR(:NEW.MONTO), '0') ||
        ', Estado nuevo: ' || TO_CHAR(:NEW.ID_ESTADO) ||
        ', Beneficiario nuevo: ' || NVL(TO_CHAR(:NEW.ID_BENEFICIARIO), 'SIN BENEFICIARIO'),
        'EXITO',
        'Se modificó información del cheque.'
    );
END;
/


/* ============================================================
   7. TRIGGER DE BITÁCORA AL ELIMINAR CHEQUES
   ------------------------------------------------------------
   Registra la información del cheque antes de eliminarlo.
   ============================================================ */

CREATE OR REPLACE TRIGGER TRG_BITACORA_DELETE_CHEQUE
BEFORE DELETE ON CHEQUES
FOR EACH ROW
BEGIN
    SP_REGISTRAR_BITACORA(
        'CHEQUES',
        TO_CHAR(:OLD.ID_CHEQUE),
        'DELETE',
        'Cheque No. ' || TO_CHAR(:OLD.NUMERO_CHEQUE) ||
        ', Monto: Q' || NVL(TO_CHAR(:OLD.MONTO), '0') ||
        ', Estado: ' || TO_CHAR(:OLD.ID_ESTADO),
        NULL,
        'EXITO',
        'Se eliminó un cheque del sistema.'
    );
END;
/


/* ============================================================
   8. TRIGGER PARA ACTUALIZAR SALDOS POR MOVIMIENTOS DE CUENTA
   ------------------------------------------------------------
   Cada vez que se registra un movimiento en MOVIMIENTOS_CUENTA,
   este trigger actualiza automáticamente el saldo de la cuenta.

   Naturaleza:
   - C = Crédito, suma al saldo.
   - D = Débito, resta al saldo.
   ============================================================ */

CREATE OR REPLACE TRIGGER TRG_MOVIMIENTOS_ACTUALIZAR_SALDO
BEFORE INSERT ON MOVIMIENTOS_CUENTA
FOR EACH ROW
DECLARE
    V_SALDO_ACTUAL CUENTAS_BANCARIAS.SALDO_ACTUAL%TYPE;
    V_SALDO_NUEVO  CUENTAS_BANCARIAS.SALDO_ACTUAL%TYPE;
BEGIN
    SELECT SALDO_ACTUAL
    INTO V_SALDO_ACTUAL
    FROM CUENTAS_BANCARIAS
    WHERE ID_CUENTA = :NEW.ID_CUENTA
    FOR UPDATE;

    IF :NEW.ID_MOVIMIENTO IS NULL THEN
        :NEW.ID_MOVIMIENTO := SEQ_MOVIMIENTOS_CUENTA.NEXTVAL;
    END IF;

    :NEW.SALDO_ANTERIOR := V_SALDO_ACTUAL;

    IF :NEW.NATURALEZA = 'C' THEN
        V_SALDO_NUEVO := V_SALDO_ACTUAL + :NEW.MONTO;

    ELSIF :NEW.NATURALEZA = 'D' THEN
        IF V_SALDO_ACTUAL < :NEW.MONTO THEN

            SP_REGISTRAR_BITACORA(
                'MOVIMIENTOS_CUENTA',
                TO_CHAR(:NEW.ID_MOVIMIENTO),
                'INTENTO FALLIDO',
                'Saldo actual: Q' || TO_CHAR(V_SALDO_ACTUAL),
                'Monto intentado: Q' || TO_CHAR(:NEW.MONTO),
                'FALLIDO',
                'No hay saldo suficiente para registrar el movimiento.'
            );

            RAISE_APPLICATION_ERROR(
                -20005,
                'Saldo insuficiente en la cuenta bancaria.'
            );
        END IF;

        V_SALDO_NUEVO := V_SALDO_ACTUAL - :NEW.MONTO;
    ELSE
        RAISE_APPLICATION_ERROR(
            -20006,
            'Naturaleza de movimiento no válida.'
        );
    END IF;

    :NEW.SALDO_NUEVO := V_SALDO_NUEVO;

    UPDATE CUENTAS_BANCARIAS
    SET SALDO_ACTUAL = V_SALDO_NUEVO
    WHERE ID_CUENTA = :NEW.ID_CUENTA;

    SP_REGISTRAR_BITACORA(
        'MOVIMIENTOS_CUENTA',
        TO_CHAR(:NEW.ID_MOVIMIENTO),
        'INSERT',
        'Saldo anterior: Q' || TO_CHAR(V_SALDO_ACTUAL),
        'Saldo nuevo: Q' || TO_CHAR(V_SALDO_NUEVO),
        'EXITO',
        'Se registró movimiento de cuenta y se actualizó el saldo bancario.'
    );
END;
/


/* ============================================================
   9. TRIGGER PARA RESERVAR Y LIBERAR SALDOS POR CHEQUE
   ------------------------------------------------------------
   Este trigger controla el saldo reservado de las cuentas cuando
   un cheque cambia de estado.

   Reglas:
   - Al pasar a GENERADO, se reserva el monto del cheque.
   - Al pasar a ENTREGADO, se descuenta el saldo real mediante
     un movimiento de cuenta.
   - Al pasar a ANULADO, se libera el saldo reservado.
   ============================================================ */

CREATE OR REPLACE TRIGGER TRG_CHEQUES_CONTROL_SALDO
AFTER UPDATE OF ID_ESTADO, MONTO ON CHEQUES
FOR EACH ROW
DECLARE
    V_SALDO_ACTUAL     CUENTAS_BANCARIAS.SALDO_ACTUAL%TYPE;
    V_SALDO_RESERVADO  CUENTAS_BANCARIAS.SALDO_RESERVADO%TYPE;
    V_DISPONIBLE       NUMBER(14,2);
BEGIN
    /* Cuando el cheque pasa a estado GENERADO se reserva el monto. */
    IF :NEW.ID_ESTADO = 2 AND :OLD.ID_ESTADO <> 2 THEN

        SELECT SALDO_ACTUAL, SALDO_RESERVADO
        INTO V_SALDO_ACTUAL, V_SALDO_RESERVADO
        FROM CUENTAS_BANCARIAS
        WHERE ID_CUENTA = :NEW.ID_CUENTA
        FOR UPDATE;

        V_DISPONIBLE := V_SALDO_ACTUAL - V_SALDO_RESERVADO;

        IF V_DISPONIBLE < :NEW.MONTO THEN

            SP_REGISTRAR_BITACORA(
                'CHEQUES',
                TO_CHAR(:NEW.ID_CHEQUE),
                'INTENTO FALLIDO',
                'Saldo disponible: Q' || TO_CHAR(V_DISPONIBLE),
                'Monto solicitado: Q' || TO_CHAR(:NEW.MONTO),
                'FALLIDO',
                'No hay saldo disponible para reservar el cheque.'
            );

            RAISE_APPLICATION_ERROR(
                -20007,
                'No hay saldo disponible para generar el cheque.'
            );
        END IF;

        UPDATE CUENTAS_BANCARIAS
        SET SALDO_RESERVADO = SALDO_RESERVADO + :NEW.MONTO
        WHERE ID_CUENTA = :NEW.ID_CUENTA;

        SP_REGISTRAR_BITACORA(
            'CUENTAS_BANCARIAS',
            TO_CHAR(:NEW.ID_CUENTA),
            'RESERVA SALDO',
            'Saldo reservado anterior: Q' || TO_CHAR(V_SALDO_RESERVADO),
            'Monto reservado: Q' || TO_CHAR(:NEW.MONTO),
            'EXITO',
            'Se reservó saldo por generación de cheque.'
        );
    END IF;

    /* Si el cheque generado o liberado es anulado, se libera la reserva. */
    IF :NEW.ID_ESTADO = 5 AND :OLD.ID_ESTADO IN (2, 3) THEN

        UPDATE CUENTAS_BANCARIAS
        SET SALDO_RESERVADO = SALDO_RESERVADO - :OLD.MONTO
        WHERE ID_CUENTA = :NEW.ID_CUENTA;

        SP_REGISTRAR_BITACORA(
            'CUENTAS_BANCARIAS',
            TO_CHAR(:NEW.ID_CUENTA),
            'LIBERA RESERVA',
            'Cheque anulado: ' || TO_CHAR(:NEW.ID_CHEQUE),
            'Monto liberado: Q' || TO_CHAR(:OLD.MONTO),
            'EXITO',
            'Se liberó saldo reservado por anulación de cheque.'
        );
    END IF;

    /* Si el cheque pasa a ENTREGADO, se registra movimiento y se descuenta saldo real. */
    IF :NEW.ID_ESTADO = 4 AND :OLD.ID_ESTADO <> 4 THEN

        IF :OLD.ID_ESTADO IN (2, 3) THEN
            UPDATE CUENTAS_BANCARIAS
            SET SALDO_RESERVADO = SALDO_RESERVADO - :NEW.MONTO
            WHERE ID_CUENTA = :NEW.ID_CUENTA;
        END IF;

        INSERT INTO MOVIMIENTOS_CUENTA (
            ID_MOVIMIENTO,
            ID_CUENTA,
            ID_CHEQUE,
            TIPO_MOVIMIENTO,
            NATURALEZA,
            MONTO,
            FECHA_MOVIMIENTO,
            USUARIO_REGISTRA,
            DESCRIPCION
        )
        VALUES (
            SEQ_MOVIMIENTOS_CUENTA.NEXTVAL,
            :NEW.ID_CUENTA,
            :NEW.ID_CHEQUE,
            'CHEQUE',
            'D',
            :NEW.MONTO,
            SYSDATE,
            NVL(:NEW.USUARIO_ENTREGA, USER),
            'Movimiento generado automáticamente por entrega de cheque.'
        );

        SP_REGISTRAR_BITACORA(
            'CHEQUES',
            TO_CHAR(:NEW.ID_CHEQUE),
            'CHEQUE ENTREGADO',
            'Estado anterior: ' || TO_CHAR(:OLD.ID_ESTADO),
            'Estado nuevo: ' || TO_CHAR(:NEW.ID_ESTADO),
            'EXITO',
            'El cheque fue entregado y se generó el movimiento de cuenta.'
        );
    END IF;

    /* Si cambia el monto mientras sigue generado o liberado, se ajusta la reserva. */
    IF :OLD.ID_ESTADO IN (2, 3)
       AND :NEW.ID_ESTADO IN (2, 3)
       AND NVL(:OLD.MONTO, 0) <> NVL(:NEW.MONTO, 0) THEN

        UPDATE CUENTAS_BANCARIAS
        SET SALDO_RESERVADO = SALDO_RESERVADO - :OLD.MONTO + :NEW.MONTO
        WHERE ID_CUENTA = :NEW.ID_CUENTA;

        SP_REGISTRAR_BITACORA(
            'CUENTAS_BANCARIAS',
            TO_CHAR(:NEW.ID_CUENTA),
            'AJUSTE RESERVA',
            'Monto anterior: Q' || TO_CHAR(:OLD.MONTO),
            'Monto nuevo: Q' || TO_CHAR(:NEW.MONTO),
            'EXITO',
            'Se ajustó el saldo reservado por cambio de monto del cheque.'
        );
    END IF;
END;
/


/* ============================================================
   10. TRIGGER DE BITÁCORA PARA ELIMINAR MOVIMIENTOS
   ------------------------------------------------------------
   Registra la eliminación de movimientos de cuenta.
   ============================================================ */

CREATE OR REPLACE TRIGGER TRG_BITACORA_DELETE_MOVIMIENTO
BEFORE DELETE ON MOVIMIENTOS_CUENTA
FOR EACH ROW
BEGIN
    SP_REGISTRAR_BITACORA(
        'MOVIMIENTOS_CUENTA',
        TO_CHAR(:OLD.ID_MOVIMIENTO),
        'DELETE',
        'Cuenta: ' || TO_CHAR(:OLD.ID_CUENTA) ||
        ', Monto: Q' || TO_CHAR(:OLD.MONTO) ||
        ', Tipo: ' || :OLD.TIPO_MOVIMIENTO,
        NULL,
        'EXITO',
        'Se eliminó un movimiento de cuenta.'
    );
END;
/


/* ============================================================
   11. CONSULTA DE PRUEBA PARA VER BITÁCORA
   ------------------------------------------------------------
   Esta consulta permite comprobar que los triggers están
   registrando eventos correctamente.
   ============================================================ */

SELECT
    ID_BITACORA,
    USUARIO_BD,
    FECHA_EVENTO,
    TABLA_AFECTADA,
    ID_REGISTRO,
    ACCION,
    RESULTADO,
    DESCRIPCION
FROM BITACORA_AUDITORIA
ORDER BY FECHA_EVENTO DESC;
