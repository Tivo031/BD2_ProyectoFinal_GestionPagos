/* ============================================================
   Script: 04_PROCEDIMIENTOS_FUNCIONES.sql
   Autor: Daniel Rosal
   Tema: Procedimientos, funciones y transacciones

   Incluye:
   - Funciones para validar saldo, rango permitido y estados.
   - Procedimientos principales:
       * PR_GENERAR_CHEQUE
       * PR_LIBERAR_CHEQUE
       * PR_ANULAR_CHEQUE
       * PR_MODIFICAR_CHEQUE
       * PR_ENTREGAR_CHEQUE (extra recomendado para cerrar el ciclo)
   - Manejo de COMMIT y ROLLBACK.
   ============================================================ */

SET SERVEROUTPUT ON;

/* ============================================================
   SECUENCIAS NECESARIAS
   Se crean solo si no existen.
   ============================================================ */

DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM USER_SEQUENCES
    WHERE SEQUENCE_NAME = 'SEQ_LIBERACIONES_CHEQUE';

    IF v_count = 0 THEN
        EXECUTE IMMEDIATE 'CREATE SEQUENCE SEQ_LIBERACIONES_CHEQUE START WITH 1 INCREMENT BY 1 NOCACHE';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM USER_SEQUENCES
    WHERE SEQUENCE_NAME = 'SEQ_MOVIMIENTOS_CUENTA';

    IF v_count = 0 THEN
        EXECUTE IMMEDIATE 'CREATE SEQUENCE SEQ_MOVIMIENTOS_CUENTA START WITH 1 INCREMENT BY 1 NOCACHE';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM USER_SEQUENCES
    WHERE SEQUENCE_NAME = 'SEQ_BITACORA_AUDITORIA';

    IF v_count = 0 THEN
        EXECUTE IMMEDIATE 'CREATE SEQUENCE SEQ_BITACORA_AUDITORIA START WITH 1 INCREMENT BY 1 NOCACHE';
    END IF;
END;
/

/* ============================================================
   PROCEDIMIENTO DE APOYO: REGISTRAR BITACORA
   Usa transaccion autonoma para conservar errores aunque
   el procedimiento principal haga ROLLBACK.
   ============================================================ */

CREATE OR REPLACE PROCEDURE PR_REGISTRAR_BITACORA (
    p_usuario_bd      IN VARCHAR2,
    p_tabla_afectada  IN VARCHAR2,
    p_id_registro     IN VARCHAR2,
    p_accion          IN VARCHAR2,
    p_valor_anterior  IN CLOB,
    p_valor_nuevo     IN CLOB,
    p_resultado       IN VARCHAR2,
    p_descripcion     IN VARCHAR2
) IS
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
    ) VALUES (
        SEQ_BITACORA_AUDITORIA.NEXTVAL,
        UPPER(p_usuario_bd),
        SYSDATE,
        p_tabla_afectada,
        p_id_registro,
        p_accion,
        p_valor_anterior,
        p_valor_nuevo,
        p_resultado,
        SUBSTR(p_descripcion, 1, 500)
    );

    COMMIT;
END;
/

/* ============================================================
   FUNCION: VALIDAR SALDO DISPONIBLE
   Retorna:
   1 = saldo suficiente
   0 = saldo insuficiente o cuenta invalida
   ============================================================ */

CREATE OR REPLACE FUNCTION FN_VALIDAR_SALDO (
    p_id_cuenta IN NUMBER,
    p_monto     IN NUMBER
) RETURN NUMBER IS
    v_disponible NUMBER(14,2);
BEGIN
    SELECT SALDO_ACTUAL - SALDO_RESERVADO
    INTO v_disponible
    FROM CUENTAS_BANCARIAS
    WHERE ID_CUENTA = p_id_cuenta
      AND ESTADO = 'A';

    IF v_disponible >= p_monto THEN
        RETURN 1;
    ELSE
        RETURN 0;
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
END;
/

/* ============================================================
   FUNCION: VALIDAR RANGO PERMITIDO DEL USUARIO
   Retorna:
   1 = usuario activo y monto dentro del rango
   0 = usuario invalido o fuera de rango
   ============================================================ */

CREATE OR REPLACE FUNCTION FN_VALIDAR_RANGO_USUARIO (
    p_usuario_bd IN VARCHAR2,
    p_monto      IN NUMBER
) RETURN NUMBER IS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM USUARIOS_SISTEMA
    WHERE USUARIO_BD = UPPER(p_usuario_bd)
      AND ESTADO = 'A'
      AND p_monto BETWEEN MONTO_MINIMO AND MONTO_MAXIMO;

    IF v_count > 0 THEN
        RETURN 1;
    ELSE
        RETURN 0;
    END IF;
END;
/

/* ============================================================
   FUNCION: VALIDAR ESTADO DE CHEQUE
   Retorna:
   1 = el cheque existe y esta en el estado indicado
   0 = no cumple
   ============================================================ */

CREATE OR REPLACE FUNCTION FN_VALIDAR_ESTADO_CHEQUE (
    p_id_cheque IN NUMBER,
    p_id_estado IN NUMBER
) RETURN NUMBER IS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM CHEQUES
    WHERE ID_CHEQUE = p_id_cheque
      AND ID_ESTADO = p_id_estado;

    IF v_count > 0 THEN
        RETURN 1;
    ELSE
        RETURN 0;
    END IF;
END;
/

/* ============================================================
   FUNCION: OBTENER ID DE ESTADO POR NOMBRE
   ============================================================ */

CREATE OR REPLACE FUNCTION FN_ID_ESTADO_CHEQUE (
    p_nombre_estado IN VARCHAR2
) RETURN NUMBER IS
    v_id_estado NUMBER(1);
BEGIN
    SELECT ID_ESTADO
    INTO v_id_estado
    FROM ESTADOS_CHEQUE
    WHERE NOMBRE_ESTADO = UPPER(p_nombre_estado);

    RETURN v_id_estado;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
END;
/

/* ============================================================
   PROCEDIMIENTO: GENERAR CHEQUE
   Toma el primer cheque DISPONIBLE de la chequera indicada,
   valida beneficiario, saldo, usuario y rango permitido.
   Reserva el saldo de la cuenta.
   ============================================================ */

CREATE OR REPLACE PROCEDURE PR_GENERAR_CHEQUE (
    p_id_chequera      IN NUMBER,
    p_id_beneficiario  IN NUMBER,
    p_monto            IN NUMBER,
    p_concepto         IN VARCHAR2,
    p_usuario_genera   IN VARCHAR2,
    p_id_cheque        OUT NUMBER
) IS
    v_id_cheque       CHEQUES.ID_CHEQUE%TYPE;
    v_id_cuenta       CHEQUES.ID_CUENTA%TYPE;
    v_numero_cheque   CHEQUES.NUMERO_CHEQUE%TYPE;
    v_req_auditoria   CHAR(1);
    v_req_gerencia    CHAR(1);
    v_beneficiario    NUMBER;
BEGIN
    IF p_monto <= 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'El monto del cheque debe ser mayor a cero.');
    END IF;

    SELECT COUNT(*)
    INTO v_beneficiario
    FROM BENEFICIARIOS
    WHERE ID_BENEFICIARIO = p_id_beneficiario
      AND ESTADO = 'A';

    IF v_beneficiario = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'El beneficiario no existe o esta inactivo.');
    END IF;

    SELECT ID_CHEQUE, ID_CUENTA, NUMERO_CHEQUE
    INTO v_id_cheque, v_id_cuenta, v_numero_cheque
    FROM CHEQUES
    WHERE ID_CHEQUERA = p_id_chequera
      AND ID_ESTADO = FN_ID_ESTADO_CHEQUE('DISPONIBLE')
      AND NUMERO_CHEQUE = (
          SELECT MIN(NUMERO_CHEQUE)
          FROM CHEQUES
          WHERE ID_CHEQUERA = p_id_chequera
            AND ID_ESTADO = FN_ID_ESTADO_CHEQUE('DISPONIBLE')
      )
    FOR UPDATE;

    IF FN_VALIDAR_RANGO_USUARIO(p_usuario_genera, p_monto) = 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'El usuario no esta activo o el monto esta fuera de su rango permitido.');
    END IF;

    IF FN_VALIDAR_SALDO(v_id_cuenta, p_monto) = 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'Saldo insuficiente en la cuenta bancaria.');
    END IF;

    /* Reglas de autorizacion propuestas:
       - Mayor o igual a 5,000 requiere Auditoria.
       - Mayor o igual a 10,000 requiere Gerencia.
    */
    IF p_monto >= 5000 THEN
        v_req_auditoria := 'S';
    ELSE
        v_req_auditoria := 'N';
    END IF;

    IF p_monto >= 10000 THEN
        v_req_gerencia := 'S';
    ELSE
        v_req_gerencia := 'N';
    END IF;

    UPDATE CHEQUES
    SET ID_BENEFICIARIO    = p_id_beneficiario,
        MONTO              = p_monto,
        CONCEPTO           = p_concepto,
        ID_ESTADO          = CASE
                                WHEN v_req_auditoria = 'N' AND v_req_gerencia = 'N'
                                THEN FN_ID_ESTADO_CHEQUE('LIBERADO')
                                ELSE FN_ID_ESTADO_CHEQUE('GENERADO')
                             END,
        REQUIERE_AUDITORIA = v_req_auditoria,
        REQUIERE_GERENCIA  = v_req_gerencia,
        USUARIO_GENERA     = UPPER(p_usuario_genera),
        FECHA_GENERACION   = SYSDATE,
        OBSERVACION        = 'Cheque generado correctamente.'
    WHERE ID_CHEQUE = v_id_cheque;

    UPDATE CUENTAS_BANCARIAS
    SET SALDO_RESERVADO = SALDO_RESERVADO + p_monto
    WHERE ID_CUENTA = v_id_cuenta;

    UPDATE CHEQUERAS
    SET CORRELATIVO_ACTUAL = v_numero_cheque + 1,
        ESTADO = CASE
                    WHEN v_numero_cheque + 1 > NUMERO_FINAL THEN 'C'
                    ELSE ESTADO
                 END
    WHERE ID_CHEQUERA = p_id_chequera
      AND CORRELATIVO_ACTUAL <= v_numero_cheque;

    p_id_cheque := v_id_cheque;

    PR_REGISTRAR_BITACORA(
        p_usuario_genera,
        'CHEQUES',
        TO_CHAR(v_id_cheque),
        'GENERAR_CHEQUE',
        NULL,
        'Monto=' || p_monto || ', Beneficiario=' || p_id_beneficiario,
        'EXITO',
        'Cheque generado numero ' || v_numero_cheque
    );

    COMMIT;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        PR_REGISTRAR_BITACORA(
            p_usuario_genera,
            'CHEQUES',
            NULL,
            'GENERAR_CHEQUE',
            NULL,
            NULL,
            'FALLIDO',
            'No hay cheques disponibles para la chequera indicada.'
        );
        RAISE_APPLICATION_ERROR(-20005, 'No hay cheques disponibles para la chequera indicada.');

    WHEN OTHERS THEN
        ROLLBACK;
        PR_REGISTRAR_BITACORA(
            p_usuario_genera,
            'CHEQUES',
            NULL,
            'GENERAR_CHEQUE',
            NULL,
            NULL,
            'FALLIDO',
            SQLERRM
        );
        RAISE;
END;
/

/* ============================================================
   PROCEDIMIENTO: LIBERAR CHEQUE
   Registra liberacion por AUDITORIA o GERENCIA.
   Cuando ya cumple todas las liberaciones requeridas,
   cambia el cheque a LIBERADO.
   ============================================================ */

CREATE OR REPLACE PROCEDURE PR_LIBERAR_CHEQUE (
    p_id_cheque         IN NUMBER,
    p_grupo_liberacion  IN VARCHAR2,
    p_usuario_libera    IN VARCHAR2,
    p_firma             IN VARCHAR2,
    p_observacion       IN VARCHAR2 DEFAULT NULL
) IS
    v_grupo             VARCHAR2(20);
    v_area_usuario      USUARIOS_SISTEMA.AREA%TYPE;
    v_req_auditoria     CHAR(1);
    v_req_gerencia      CHAR(1);
    v_usuario_auditoria VARCHAR2(30);
    v_usuario_gerencia  VARCHAR2(30);
BEGIN
    v_grupo := UPPER(p_grupo_liberacion);

    IF v_grupo NOT IN ('AUDITORIA', 'GERENCIA') THEN
        RAISE_APPLICATION_ERROR(-20010, 'El grupo de liberacion debe ser AUDITORIA o GERENCIA.');
    END IF;

    SELECT AREA
    INTO v_area_usuario
    FROM USUARIOS_SISTEMA
    WHERE USUARIO_BD = UPPER(p_usuario_libera)
      AND ESTADO = 'A';

    IF v_area_usuario <> v_grupo THEN
        RAISE_APPLICATION_ERROR(-20011, 'El usuario no pertenece al grupo de liberacion indicado.');
    END IF;

    SELECT REQUIERE_AUDITORIA, REQUIERE_GERENCIA, USUARIO_AUDITORIA, USUARIO_GERENCIA
    INTO v_req_auditoria, v_req_gerencia, v_usuario_auditoria, v_usuario_gerencia
    FROM CHEQUES
    WHERE ID_CHEQUE = p_id_cheque
      AND ID_ESTADO = FN_ID_ESTADO_CHEQUE('GENERADO')
    FOR UPDATE;

    IF v_grupo = 'AUDITORIA' AND v_req_auditoria = 'N' THEN
        RAISE_APPLICATION_ERROR(-20012, 'Este cheque no requiere liberacion de Auditoria.');
    END IF;

    IF v_grupo = 'GERENCIA' AND v_req_gerencia = 'N' THEN
        RAISE_APPLICATION_ERROR(-20013, 'Este cheque no requiere liberacion de Gerencia.');
    END IF;

    INSERT INTO LIBERACIONES_CHEQUE (
        ID_LIBERACION,
        ID_CHEQUE,
        GRUPO_LIBERACION,
        USUARIO_LIBERA,
        FECHA_LIBERACION,
        RESULTADO,
        OBSERVACION
    ) VALUES (
        SEQ_LIBERACIONES_CHEQUE.NEXTVAL,
        p_id_cheque,
        v_grupo,
        UPPER(p_usuario_libera),
        SYSDATE,
        'APROBADO',
        p_observacion
    );

    IF v_grupo = 'AUDITORIA' THEN
        UPDATE CHEQUES
        SET USUARIO_AUDITORIA = UPPER(p_usuario_libera),
            FECHA_AUDITORIA   = SYSDATE,
            FIRMA_AUDITORIA   = p_firma
        WHERE ID_CHEQUE = p_id_cheque;
    ELSE
        UPDATE CHEQUES
        SET USUARIO_GERENCIA = UPPER(p_usuario_libera),
            FECHA_GERENCIA   = SYSDATE,
            FIRMA_GERENCIA   = p_firma
        WHERE ID_CHEQUE = p_id_cheque;
    END IF;

    SELECT REQUIERE_AUDITORIA, REQUIERE_GERENCIA, USUARIO_AUDITORIA, USUARIO_GERENCIA
    INTO v_req_auditoria, v_req_gerencia, v_usuario_auditoria, v_usuario_gerencia
    FROM CHEQUES
    WHERE ID_CHEQUE = p_id_cheque;

    IF (v_req_auditoria = 'N' OR v_usuario_auditoria IS NOT NULL)
       AND
       (v_req_gerencia = 'N' OR v_usuario_gerencia IS NOT NULL) THEN

        UPDATE CHEQUES
        SET ID_ESTADO = FN_ID_ESTADO_CHEQUE('LIBERADO'),
            OBSERVACION = 'Cheque liberado correctamente.'
        WHERE ID_CHEQUE = p_id_cheque;
    END IF;

    PR_REGISTRAR_BITACORA(
        p_usuario_libera,
        'CHEQUES',
        TO_CHAR(p_id_cheque),
        'LIBERAR_CHEQUE',
        NULL,
        'Grupo=' || v_grupo,
        'EXITO',
        'Liberacion registrada correctamente.'
    );

    COMMIT;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        PR_REGISTRAR_BITACORA(
            p_usuario_libera,
            'CHEQUES',
            TO_CHAR(p_id_cheque),
            'LIBERAR_CHEQUE',
            NULL,
            NULL,
            'FALLIDO',
            'Cheque inexistente, usuario invalido o cheque no esta en estado GENERADO.'
        );
        RAISE_APPLICATION_ERROR(-20014, 'Cheque inexistente, usuario invalido o cheque no esta en estado GENERADO.');

    WHEN OTHERS THEN
        ROLLBACK;
        PR_REGISTRAR_BITACORA(
            p_usuario_libera,
            'CHEQUES',
            TO_CHAR(p_id_cheque),
            'LIBERAR_CHEQUE',
            NULL,
            NULL,
            'FALLIDO',
            SQLERRM
        );
        RAISE;
END;
/

/* ============================================================
   PROCEDIMIENTO: ANULAR CHEQUE
   Permite anular cheques GENERADOS o LIBERADOS.
   Libera el saldo reservado.
   No permite anular cheques ENTREGADOS.
   ============================================================ */

CREATE OR REPLACE PROCEDURE PR_ANULAR_CHEQUE (
    p_id_cheque       IN NUMBER,
    p_usuario_anula   IN VARCHAR2,
    p_motivo          IN VARCHAR2
) IS
    v_id_estado  CHEQUES.ID_ESTADO%TYPE;
    v_id_cuenta  CHEQUES.ID_CUENTA%TYPE;
    v_monto      CHEQUES.MONTO%TYPE;
BEGIN
    SELECT ID_ESTADO, ID_CUENTA, MONTO
    INTO v_id_estado, v_id_cuenta, v_monto
    FROM CHEQUES
    WHERE ID_CHEQUE = p_id_cheque
    FOR UPDATE;

    IF v_id_estado = FN_ID_ESTADO_CHEQUE('DISPONIBLE') THEN
        RAISE_APPLICATION_ERROR(-20020, 'No se puede anular un cheque disponible no generado.');
    END IF;

    IF v_id_estado = FN_ID_ESTADO_CHEQUE('ENTREGADO') THEN
        RAISE_APPLICATION_ERROR(-20021, 'No se puede anular un cheque entregado.');
    END IF;

    IF v_id_estado = FN_ID_ESTADO_CHEQUE('ANULADO') THEN
        RAISE_APPLICATION_ERROR(-20022, 'El cheque ya se encuentra anulado.');
    END IF;

    UPDATE CHEQUES
    SET ID_ESTADO = FN_ID_ESTADO_CHEQUE('ANULADO'),
        OBSERVACION = p_motivo
    WHERE ID_CHEQUE = p_id_cheque;

    UPDATE CUENTAS_BANCARIAS
    SET SALDO_RESERVADO = SALDO_RESERVADO - v_monto
    WHERE ID_CUENTA = v_id_cuenta;

    PR_REGISTRAR_BITACORA(
        p_usuario_anula,
        'CHEQUES',
        TO_CHAR(p_id_cheque),
        'ANULAR_CHEQUE',
        'Estado anterior=' || v_id_estado || ', Monto=' || v_monto,
        'Estado nuevo=ANULADO',
        'EXITO',
        p_motivo
    );

    COMMIT;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        PR_REGISTRAR_BITACORA(
            p_usuario_anula,
            'CHEQUES',
            TO_CHAR(p_id_cheque),
            'ANULAR_CHEQUE',
            NULL,
            NULL,
            'FALLIDO',
            'Cheque no encontrado.'
        );
        RAISE_APPLICATION_ERROR(-20023, 'Cheque no encontrado.');

    WHEN OTHERS THEN
        ROLLBACK;
        PR_REGISTRAR_BITACORA(
            p_usuario_anula,
            'CHEQUES',
            TO_CHAR(p_id_cheque),
            'ANULAR_CHEQUE',
            NULL,
            NULL,
            'FALLIDO',
            SQLERRM
        );
        RAISE;
END;
/

/* ============================================================
   PROCEDIMIENTO: MODIFICAR CHEQUE
   Permite modificar cheques en estado GENERADO.
   Ajusta el saldo reservado si cambia el monto.
   ============================================================ */

CREATE OR REPLACE PROCEDURE PR_MODIFICAR_CHEQUE (
    p_id_cheque        IN NUMBER,
    p_id_beneficiario  IN NUMBER,
    p_monto            IN NUMBER,
    p_concepto         IN VARCHAR2,
    p_usuario_modifica IN VARCHAR2,
    p_observacion      IN VARCHAR2 DEFAULT NULL
) IS
    v_id_cuenta       CHEQUES.ID_CUENTA%TYPE;
    v_monto_anterior  CHEQUES.MONTO%TYPE;
    v_diferencia      NUMBER(14,2);
    v_beneficiario    NUMBER;
    v_req_auditoria   CHAR(1);
    v_req_gerencia    CHAR(1);
BEGIN
    IF p_monto <= 0 THEN
        RAISE_APPLICATION_ERROR(-20030, 'El monto del cheque debe ser mayor a cero.');
    END IF;

    SELECT COUNT(*)
    INTO v_beneficiario
    FROM BENEFICIARIOS
    WHERE ID_BENEFICIARIO = p_id_beneficiario
      AND ESTADO = 'A';

    IF v_beneficiario = 0 THEN
        RAISE_APPLICATION_ERROR(-20031, 'El beneficiario no existe o esta inactivo.');
    END IF;

    SELECT ID_CUENTA, MONTO
    INTO v_id_cuenta, v_monto_anterior
    FROM CHEQUES
    WHERE ID_CHEQUE = p_id_cheque
      AND ID_ESTADO = FN_ID_ESTADO_CHEQUE('GENERADO')
    FOR UPDATE;

    IF FN_VALIDAR_RANGO_USUARIO(p_usuario_modifica, p_monto) = 0 THEN
        RAISE_APPLICATION_ERROR(-20032, 'El usuario no esta activo o el nuevo monto esta fuera de su rango permitido.');
    END IF;

    v_diferencia := p_monto - v_monto_anterior;

    IF v_diferencia > 0 AND FN_VALIDAR_SALDO(v_id_cuenta, v_diferencia) = 0 THEN
        RAISE_APPLICATION_ERROR(-20033, 'Saldo insuficiente para aumentar el monto del cheque.');
    END IF;

    IF p_monto >= 5000 THEN
        v_req_auditoria := 'S';
    ELSE
        v_req_auditoria := 'N';
    END IF;

    IF p_monto >= 10000 THEN
        v_req_gerencia := 'S';
    ELSE
        v_req_gerencia := 'N';
    END IF;

    DELETE FROM LIBERACIONES_CHEQUE
    WHERE ID_CHEQUE = p_id_cheque;

    UPDATE CHEQUES
    SET ID_BENEFICIARIO    = p_id_beneficiario,
        MONTO              = p_monto,
        CONCEPTO           = p_concepto,
        ID_ESTADO          = CASE
                                WHEN v_req_auditoria = 'N' AND v_req_gerencia = 'N'
                                THEN FN_ID_ESTADO_CHEQUE('LIBERADO')
                                ELSE FN_ID_ESTADO_CHEQUE('GENERADO')
                             END,
        REQUIERE_AUDITORIA = v_req_auditoria,
        REQUIERE_GERENCIA  = v_req_gerencia,
        USUARIO_AUDITORIA  = NULL,
        FECHA_AUDITORIA    = NULL,
        FIRMA_AUDITORIA    = NULL,
        USUARIO_GERENCIA   = NULL,
        FECHA_GERENCIA     = NULL,
        FIRMA_GERENCIA     = NULL,
        OBSERVACION        = p_observacion
    WHERE ID_CHEQUE = p_id_cheque;

    UPDATE CUENTAS_BANCARIAS
    SET SALDO_RESERVADO = SALDO_RESERVADO + v_diferencia
    WHERE ID_CUENTA = v_id_cuenta;

    PR_REGISTRAR_BITACORA(
        p_usuario_modifica,
        'CHEQUES',
        TO_CHAR(p_id_cheque),
        'MODIFICAR_CHEQUE',
        'Monto anterior=' || v_monto_anterior,
        'Monto nuevo=' || p_monto,
        'EXITO',
        'Cheque modificado correctamente.'
    );

    COMMIT;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        PR_REGISTRAR_BITACORA(
            p_usuario_modifica,
            'CHEQUES',
            TO_CHAR(p_id_cheque),
            'MODIFICAR_CHEQUE',
            NULL,
            NULL,
            'FALLIDO',
            'Cheque no encontrado o no esta en estado GENERADO.'
        );
        RAISE_APPLICATION_ERROR(-20034, 'Cheque no encontrado o no esta en estado GENERADO.');

    WHEN OTHERS THEN
        ROLLBACK;
        PR_REGISTRAR_BITACORA(
            p_usuario_modifica,
            'CHEQUES',
            TO_CHAR(p_id_cheque),
            'MODIFICAR_CHEQUE',
            NULL,
            NULL,
            'FALLIDO',
            SQLERRM
        );
        RAISE;
END;
/

/* ============================================================
   PROCEDIMIENTO EXTRA: ENTREGAR CHEQUE
   Cierra el ciclo del cheque:
   - Cambia de LIBERADO a ENTREGADO.
   - Baja saldo actual.
   - Baja saldo reservado.
   - Registra movimiento de cuenta.
   ============================================================ */

CREATE OR REPLACE PROCEDURE PR_ENTREGAR_CHEQUE (
    p_id_cheque        IN NUMBER,
    p_usuario_entrega  IN VARCHAR2,
    p_observacion      IN VARCHAR2 DEFAULT NULL
) IS
    v_id_cuenta       CHEQUES.ID_CUENTA%TYPE;
    v_monto           CHEQUES.MONTO%TYPE;
    v_saldo_anterior  CUENTAS_BANCARIAS.SALDO_ACTUAL%TYPE;
    v_saldo_nuevo     CUENTAS_BANCARIAS.SALDO_ACTUAL%TYPE;
BEGIN
    SELECT ID_CUENTA, MONTO
    INTO v_id_cuenta, v_monto
    FROM CHEQUES
    WHERE ID_CHEQUE = p_id_cheque
      AND ID_ESTADO = FN_ID_ESTADO_CHEQUE('LIBERADO')
    FOR UPDATE;

    SELECT SALDO_ACTUAL
    INTO v_saldo_anterior
    FROM CUENTAS_BANCARIAS
    WHERE ID_CUENTA = v_id_cuenta
    FOR UPDATE;

    v_saldo_nuevo := v_saldo_anterior - v_monto;

    IF v_saldo_nuevo < 0 THEN
        RAISE_APPLICATION_ERROR(-20040, 'Saldo insuficiente para entregar el cheque.');
    END IF;

    UPDATE CHEQUES
    SET ID_ESTADO = FN_ID_ESTADO_CHEQUE('ENTREGADO'),
        USUARIO_ENTREGA = UPPER(p_usuario_entrega),
        FECHA_ENTREGA = SYSDATE,
        OBSERVACION = p_observacion
    WHERE ID_CHEQUE = p_id_cheque;

    UPDATE CUENTAS_BANCARIAS
    SET SALDO_ACTUAL = SALDO_ACTUAL - v_monto,
        SALDO_RESERVADO = SALDO_RESERVADO - v_monto
    WHERE ID_CUENTA = v_id_cuenta;

    INSERT INTO MOVIMIENTOS_CUENTA (
        ID_MOVIMIENTO,
        ID_CUENTA,
        ID_CHEQUE,
        TIPO_MOVIMIENTO,
        NATURALEZA,
        MONTO,
        SALDO_ANTERIOR,
        SALDO_NUEVO,
        FECHA_MOVIMIENTO,
        USUARIO_REGISTRA,
        DESCRIPCION
    ) VALUES (
        SEQ_MOVIMIENTOS_CUENTA.NEXTVAL,
        v_id_cuenta,
        p_id_cheque,
        'CHEQUE',
        'D',
        v_monto,
        v_saldo_anterior,
        v_saldo_nuevo,
        SYSDATE,
        UPPER(p_usuario_entrega),
        'Entrega de cheque. ' || p_observacion
    );

    PR_REGISTRAR_BITACORA(
        p_usuario_entrega,
        'CHEQUES',
        TO_CHAR(p_id_cheque),
        'ENTREGAR_CHEQUE',
        'Saldo anterior=' || v_saldo_anterior,
        'Saldo nuevo=' || v_saldo_nuevo,
        'EXITO',
        'Cheque entregado correctamente.'
    );

    COMMIT;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        PR_REGISTRAR_BITACORA(
            p_usuario_entrega,
            'CHEQUES',
            TO_CHAR(p_id_cheque),
            'ENTREGAR_CHEQUE',
            NULL,
            NULL,
            'FALLIDO',
            'Cheque no encontrado o no esta en estado LIBERADO.'
        );
        RAISE_APPLICATION_ERROR(-20041, 'Cheque no encontrado o no esta en estado LIBERADO.');

    WHEN OTHERS THEN
        ROLLBACK;
        PR_REGISTRAR_BITACORA(
            p_usuario_entrega,
            'CHEQUES',
            TO_CHAR(p_id_cheque),
            'ENTREGAR_CHEQUE',
            NULL,
            NULL,
            'FALLIDO',
            SQLERRM
        );
        RAISE;
END;
/

/* ============================================================
   PRUEBAS SUGERIDAS
   Ejecutar una por una en SQL Developer.
   ============================================================ */

-- Generar cheque:
-- DECLARE
--     v_id_cheque NUMBER;
-- BEGIN
--     PR_GENERAR_CHEQUE(
--         p_id_chequera     => 1,
--         p_id_beneficiario => 1,
--         p_monto           => 3000,
--         p_concepto        => 'Pago de servicios',
--         p_usuario_genera  => 'USR_JUANITO',
--         p_id_cheque       => v_id_cheque
--     );
--     DBMS_OUTPUT.PUT_LINE('Cheque generado ID: ' || v_id_cheque);
-- END;
-- /

-- Liberar cheque por auditoria:
-- BEGIN
--     PR_LIBERAR_CHEQUE(1, 'AUDITORIA', 'USR_AUDITOR', 'FIRMA-AUDITOR', 'Aprobado por auditoria');
-- END;
-- /

-- Liberar cheque por gerencia:
-- BEGIN
--     PR_LIBERAR_CHEQUE(1, 'GERENCIA', 'USR_GERENTE', 'FIRMA-GERENTE', 'Aprobado por gerencia');
-- END;
-- /

-- Anular cheque:
-- BEGIN
--     PR_ANULAR_CHEQUE(1, 'USR_JEFE_PAGOS', 'Anulado por error de datos');
-- END;
-- /

-- Modificar cheque:
-- BEGIN
--     PR_MODIFICAR_CHEQUE(
--         p_id_cheque        => 1,
--         p_id_beneficiario  => 2,
--         p_monto            => 4500,
--         p_concepto         => 'Cambio de beneficiario y monto',
--         p_usuario_modifica => 'USR_JUANITO',
--         p_observacion      => 'Correccion solicitada'
--     );
-- END;
-- /

-- Entregar cheque:
-- BEGIN
--     PR_ENTREGAR_CHEQUE(1, 'USR_CAJERO', 'Entregado al beneficiario');
-- END;
-- /
