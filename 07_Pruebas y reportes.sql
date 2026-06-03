
-- SCRIPT: _REPORTES.sql
-- DESCRIPCIÓN: Reportes del sistema de cheques
-- ============================================================
/* ============================================================
   SCRIPT: 07_REPORTES.sql
   SISTEMA DE GESTION DE PAGOS "NUEVA VERAPAZ"

   DESCRIPCION:
   Consultas de reportes solicitadas por el proyecto.

   ============================================================ */


/* ============================================================
   REPORTE 1
   NOMBRE:
   Cheques emitidos por rango de fecha y cuenta bancaria

   OBJETIVO:
   Mostrar todos los cheques generados dentro de un rango
   de fechas para una cuenta bancaria específica.

   INFORMACION MOSTRADA:
   - ID del cheque
   - Número de cheque
   - Beneficiario
   - Monto
   - Fecha de generación
   - Número de cuenta
   - Estado del cheque
   ============================================================ */

SELECT
    c.ID_CHEQUE,
    c.NUMERO_CHEQUE,
    b.NOMBRE AS BENEFICIARIO,
    c.MONTO,
    c.FECHA_GENERACION,
    cb.NUMERO_CUENTA,
    ec.NOMBRE_ESTADO
FROM CHEQUES c
INNER JOIN BENEFICIARIOS b
    ON c.ID_BENEFICIARIO = b.ID_BENEFICIARIO
INNER JOIN CHEQUERAS ch
    ON c.ID_CHEQUERA = ch.ID_CHEQUERA
INNER JOIN CUENTAS_BANCARIAS cb
    ON ch.ID_CUENTA = cb.ID_CUENTA
INNER JOIN ESTADOS_CHEQUE ec
    ON c.ID_ESTADO = ec.ID_ESTADO
WHERE c.FECHA_GENERACION BETWEEN
      TO_DATE('01/05/2026','DD/MM/YYYY')
  AND TO_DATE('31/05/2026','DD/MM/YYYY')
AND cb.ID_CUENTA = 1
ORDER BY c.FECHA_GENERACION;


/* ============================================================
   REPORTE 2
   NOMBRE:
   Cheques liberados por Auditoría

   OBJETIVO:
   Mostrar todos los cheques que fueron aprobados
   por el área de Auditoría.

   INFORMACION MOSTRADA:
   - Número de cheque
   - Monto
   - Usuario que liberó
   - Fecha de liberación
   - Resultado
   ============================================================ */

SELECT
    c.ID_CHEQUE,
    c.NUMERO_CHEQUE,
    c.MONTO,
    l.GRUPO_LIBERACION,
    l.USUARIO_LIBERA,
    l.FECHA_LIBERACION,
    l.RESULTADO
FROM LIBERACIONES_CHEQUE l
INNER JOIN CHEQUES c
    ON l.ID_CHEQUE = c.ID_CHEQUE
WHERE l.GRUPO_LIBERACION = 'AUDITORIA'
ORDER BY l.FECHA_LIBERACION;


/* ============================================================
   REPORTE 3
   NOMBRE:
   Cheques liberados por Gerencia

   OBJETIVO:
   Mostrar todos los cheques que fueron aprobados
   por Gerencia.

   INFORMACION MOSTRADA:
   - Número de cheque
   - Monto
   - Usuario que liberó
   - Fecha de liberación
   - Resultado
   ============================================================ */

SELECT
    c.ID_CHEQUE,
    c.NUMERO_CHEQUE,
    c.MONTO,
    l.GRUPO_LIBERACION,
    l.USUARIO_LIBERA,
    l.FECHA_LIBERACION,
    l.RESULTADO
FROM LIBERACIONES_CHEQUE l
INNER JOIN CHEQUES c
    ON l.ID_CHEQUE = c.ID_CHEQUE
WHERE l.GRUPO_LIBERACION = 'GERENCIA'
ORDER BY l.FECHA_LIBERACION;


/* ============================================================
   REPORTE 4
   NOMBRE:
   Bitácora por usuario y rango de fechas

   OBJETIVO:
   Consultar todas las acciones realizadas por
   un usuario específico dentro de un período.

   INFORMACION MOSTRADA:
   - Usuario
   - Fecha del evento
   - Acción realizada
   - Resultado
   - Descripción
   ============================================================ */

SELECT
    ID_BITACORA,
    USUARIO_BD,
    FECHA_EVENTO,
    ACCION,
    RESULTADO,
    DESCRIPCION
FROM BITACORA_AUDITORIA
WHERE USUARIO_BD = 'USR_AUDITOR'
AND FECHA_EVENTO BETWEEN
    TO_DATE('01/05/2026','DD/MM/YYYY')
AND TO_DATE('31/05/2026','DD/MM/YYYY')
ORDER BY FECHA_EVENTO;


/* ============================================================
   REPORTE 5
   NOMBRE:
   Intentos fallidos registrados en bitácora

   OBJETIVO:
   Mostrar acciones que no pudieron completarse
   por validaciones o restricciones del sistema.

   INFORMACION MOSTRADA:
   - Usuario
   - Fecha
   - Acción
   - Descripción del error
   ============================================================ */

SELECT
    ID_BITACORA,
    USUARIO_BD,
    FECHA_EVENTO,
    ACCION,
    DESCRIPCION
FROM BITACORA_AUDITORIA
WHERE RESULTADO = 'FALLIDO'
ORDER BY FECHA_EVENTO DESC;


/* ============================================================
   REPORTE 6
   NOMBRE:
   Cheques generados

   OBJETIVO:
   Mostrar todos los cheques que actualmente
   se encuentran en estado GENERADO.

   INFORMACION MOSTRADA:
   - Número de cheque
   - Monto
   - Usuario generador
   - Fecha de generación
   ============================================================ */

SELECT
    ID_CHEQUE,
    NUMERO_CHEQUE,
    MONTO,
    USUARIO_GENERA,
    FECHA_GENERACION
FROM CHEQUES
WHERE ID_ESTADO =
(
    SELECT ID_ESTADO
    FROM ESTADOS_CHEQUE
    WHERE NOMBRE_ESTADO = 'GENERADO'
);


/* ============================================================
   REPORTE 7
   NOMBRE:
   Cheques aprobados o liberados

   OBJETIVO:
   Mostrar los cheques que ya pasaron por los
   procesos de autorización correspondientes.

   INFORMACION MOSTRADA:
   - Número de cheque
   - Monto
   - Estado actual
   ============================================================ */

SELECT
    c.ID_CHEQUE,
    c.NUMERO_CHEQUE,
    c.MONTO,
    ec.NOMBRE_ESTADO
FROM CHEQUES c
INNER JOIN ESTADOS_CHEQUE ec
    ON c.ID_ESTADO = ec.ID_ESTADO
WHERE ec.NOMBRE_ESTADO LIKE 'LIBERADO%';


/* ============================================================
   REPORTE 8
   NOMBRE:
   Movimientos de cuentas bancarias

   OBJETIVO:
   Mostrar todos los movimientos registrados
   en las cuentas bancarias.

   INFORMACION MOSTRADA:
   - Cuenta bancaria
   - Tipo de movimiento
   - Monto
   - Fecha
   - Descripción
   ============================================================ */

SELECT
    m.ID_MOVIMIENTO,
    cb.NUMERO_CUENTA,
    m.TIPO_MOVIMIENTO,
    m.MONTO,
    m.FECHA_MOVIMIENTO,
    m.DESCRIPCION
FROM MOVIMIENTOS_CUENTA m
INNER JOIN CUENTAS_BANCARIAS cb
    ON m.ID_CUENTA = cb.ID_CUENTA
ORDER BY m.FECHA_MOVIMIENTO;


/* ============================================================
   REPORTE 9
   NOMBRE:
   Movimientos de una cuenta específica

   OBJETIVO:
   Mostrar todos los movimientos realizados
   sobre una cuenta bancaria determinada.

   INFORMACION MOSTRADA:
   - Cuenta
   - Movimiento
   - Monto
   - Fecha
   ============================================================ */

SELECT
    m.ID_MOVIMIENTO,
    cb.NUMERO_CUENTA,
    m.TIPO_MOVIMIENTO,
    m.MONTO,
    m.FECHA_MOVIMIENTO
FROM MOVIMIENTOS_CUENTA m
INNER JOIN CUENTAS_BANCARIAS cb
    ON m.ID_CUENTA = cb.ID_CUENTA
WHERE cb.ID_CUENTA = 1
ORDER BY m.FECHA_MOVIMIENTO;


/* ============================================================
   REPORTE 10
   NOMBRE:
   Movimiento de un cheque específico

   OBJETIVO:
   Consultar todos los movimientos asociados
   a un cheque determinado.

   INFORMACION MOSTRADA:
   - Número de cheque
   - Movimiento
   - Monto
   - Fecha
   - Descripción
   ============================================================ */

SELECT
    c.NUMERO_CHEQUE,
    m.ID_MOVIMIENTO,
    m.MONTO,
    m.FECHA_MOVIMIENTO,
    m.DESCRIPCION
FROM MOVIMIENTOS_CUENTA m
INNER JOIN CHEQUES c
    ON m.ID_CHEQUE = c.ID_CHEQUE
WHERE c.NUMERO_CHEQUE = 1004;


/* ============================================================
   REPORTE 11
   NOMBRE:
   Cheques por rango de numeración

   OBJETIVO:
   Consultar todos los cheques comprendidos
   dentro de un rango de números.

   INFORMACION MOSTRADA:
   - Número de cheque
   - Monto
   - Fecha
   - Estado
   ============================================================ */

SELECT
    NUMERO_CHEQUE,
    MONTO,
    FECHA_GENERACION,
    ID_ESTADO
FROM CHEQUES
WHERE NUMERO_CHEQUE BETWEEN 1001 AND 1010
ORDER BY NUMERO_CHEQUE;


/* ============================================================
   REPORTE 12
   NOMBRE:
   Movimientos de cheques por cuenta bancaria

   OBJETIVO:
   Mostrar todos los cheques asociados a cada
   cuenta bancaria y su estado actual.

   INFORMACION MOSTRADA:
   - Cuenta bancaria
   - Número de cheque
   - Monto
   - Estado
   ============================================================ */

SELECT
    cb.NUMERO_CUENTA,
    c.NUMERO_CHEQUE,
    c.MONTO,
    ec.NOMBRE_ESTADO
FROM CHEQUES c
INNER JOIN CHEQUERAS ch
    ON c.ID_CHEQUERA = ch.ID_CHEQUERA
INNER JOIN CUENTAS_BANCARIAS cb
    ON ch.ID_CUENTA = cb.ID_CUENTA
INNER JOIN ESTADOS_CHEQUE ec
    ON c.ID_ESTADO = ec.ID_ESTADO
ORDER BY cb.NUMERO_CUENTA,
         c.NUMERO_CHEQUE;



-- SCRIPT: _PRUEBAS.sql
-- DESCRIPCIÓN: Casos de prueba del sistema
-- ============================================================

SET SERVEROUTPUT ON;

/* ============================================================
   SCRIPT: 08_PRUEBAS.sql
   SISTEMA DE GESTION DE PAGOS "NUEVA VERAPAZ"

   DESCRIPCION:
   Casos de prueba para validar el correcto
   funcionamiento de los procedimientos almacenados.

   ============================================================ */

SET SERVEROUTPUT ON;

/* ============================================================
   CASO 1
   NOMBRE:
   Generación de cheque

   OBJETIVO:
   Validar que un usuario autorizado pueda generar
   un cheque dentro de su rango permitido.

   RESULTADO ESPERADO:
   - Se genera un nuevo cheque.
   - Se muestra el ID generado.
   ============================================================ */

DECLARE
    V_ID_CHEQUE NUMBER;
BEGIN

    PR_GENERAR_CHEQUE(
        P_ID_CHEQUERA      => 1,
        P_ID_BENEFICIARIO  => 1,
        P_MONTO            => 2500,
        P_CONCEPTO         => 'PRUEBA GENERACION DE CHEQUE',
        P_USUARIO_GENERA   => 'USR_JUANITO',
        P_ID_CHEQUE        => V_ID_CHEQUE
    );

    DBMS_OUTPUT.PUT_LINE(
        'Cheque generado correctamente. ID = '
        || V_ID_CHEQUE
    );

END;
/

/* ============================================================
   CASO 2
   NOMBRE:
   Generación de cheque que requiere auditoría

   OBJETIVO:
   Validar la generación de un cheque mayor o igual
   a Q5,000 para activar la autorización de auditoría.

   RESULTADO ESPERADO:
   - REQUIERE_AUDITORIA = S
   ============================================================ */

DECLARE
    V_ID_CHEQUE NUMBER;
BEGIN

    PR_GENERAR_CHEQUE(
        P_ID_CHEQUERA      => 1,
        P_ID_BENEFICIARIO  => 2,
        P_MONTO            => 6000,
        P_CONCEPTO         => 'PRUEBA AUDITORIA',
        P_USUARIO_GENERA   => 'USR_CARLOS_PAGOS',
        P_ID_CHEQUE        => V_ID_CHEQUE
    );

    DBMS_OUTPUT.PUT_LINE(
        'Cheque para auditoria generado. ID = '
        || V_ID_CHEQUE
    );

END;
/

/* ============================================================
   CASO 3
   NOMBRE:
   Generación de cheque que requiere gerencia

   OBJETIVO:
   Validar la generación de un cheque mayor o igual
   a Q25,000.

   RESULTADO ESPERADO:
   - REQUIERE_AUDITORIA = S
   - REQUIERE_GERENCIA = S
   ============================================================ */

DECLARE
    V_ID_CHEQUE NUMBER;
BEGIN

    PR_GENERAR_CHEQUE(
        P_ID_CHEQUERA      => 1,
        P_ID_BENEFICIARIO  => 3,
        P_MONTO            => 30000,
        P_CONCEPTO         => 'PRUEBA GERENCIA',
        P_USUARIO_GENERA   => 'USR_PAGOS_SENIOR',
        P_ID_CHEQUE        => V_ID_CHEQUE
    );

    DBMS_OUTPUT.PUT_LINE(
        'Cheque para gerencia generado. ID = '
        || V_ID_CHEQUE
    );

END;
/

/* ============================================================
   CASO 4
   NOMBRE:
   Liberación por auditoría

   OBJETIVO:
   Aprobar un cheque que requiere auditoría.

   RESULTADO ESPERADO:
   - Se registra liberación en auditoría.
   ============================================================ */

BEGIN

    PR_LIBERAR_CHEQUE(
        P_ID_CHEQUE => 1002,
        P_USUARIO   => 'USR_AUDITOR'
    );

    DBMS_OUTPUT.PUT_LINE(
        'Cheque liberado por auditoria.'
    );

END;
/

/* ============================================================
   CASO 5
   NOMBRE:
   Liberación por gerencia

   OBJETIVO:
   Aprobar un cheque que requiere autorización
   de gerencia.

   RESULTADO ESPERADO:
   - Cheque aprobado por gerencia.
   ============================================================ */

BEGIN

    PR_LIBERAR_CHEQUE(
        P_ID_CHEQUE => 1003,
        P_USUARIO   => 'USR_GERENTE'
    );

    DBMS_OUTPUT.PUT_LINE(
        'Cheque liberado por gerencia.'
    );

END;
/

/* ============================================================
   CASO 6
   NOMBRE:
   Entrega de cheque

   OBJETIVO:
   Registrar la entrega del cheque al beneficiario.

   RESULTADO ESPERADO:
   - Estado ENTREGADO.
   ============================================================ */

BEGIN

    PR_ENTREGAR_CHEQUE(
        P_ID_CHEQUE => 1004,
        P_USUARIO   => 'USR_CAJERO'
    );

    DBMS_OUTPUT.PUT_LINE(
        'Cheque entregado correctamente.'
    );

END;
/

/* ============================================================
   CASO 7
   NOMBRE:
   Modificación de cheque

   OBJETIVO:
   Modificar la información de un cheque
   antes de su liberación.

   RESULTADO ESPERADO:
   - Datos actualizados.
   ============================================================ */

BEGIN

    PR_MODIFICAR_CHEQUE(
        P_ID_CHEQUE => 1007,
        P_MONTO     => 3500,
        P_CONCEPTO  => 'CONCEPTO MODIFICADO'
    );

    DBMS_OUTPUT.PUT_LINE(
        'Cheque modificado correctamente.'
    );

END;
/

/* ============================================================
   CASO 8
   NOMBRE:
   Anulación de cheque

   OBJETIVO:
   Anular un cheque generado.

   RESULTADO ESPERADO:
   - Estado ANULADO.
   ============================================================ */

BEGIN

    PR_ANULAR_CHEQUE(
        P_ID_CHEQUE => 1006,
        P_USUARIO   => 'USR_JEFE_PAGOS'
    );

    DBMS_OUTPUT.PUT_LINE(
        'Cheque anulado correctamente.'
    );

END;
/

/* ============================================================
   CASO 9
   NOMBRE:
   Verificación de cheques

   OBJETIVO:
   Comprobar los cambios realizados por las
   pruebas anteriores.
   ============================================================ */

SELECT
    ID_CHEQUE,
    NUMERO_CHEQUE,
    MONTO,
    ID_ESTADO,
    FECHA_GENERACION
FROM CHEQUES
ORDER BY ID_CHEQUE;

/* ============================================================
   CASO 10
   NOMBRE:
   Verificación de movimientos bancarios

   OBJETIVO:
   Confirmar que los movimientos fueron registrados.
   ============================================================ */

SELECT *
FROM MOVIMIENTOS_CUENTA
ORDER BY ID_MOVIMIENTO;

/* ============================================================
   CASO 11
   NOMBRE:
   Verificación de liberaciones

   OBJETIVO:
   Confirmar las aprobaciones registradas.
   ============================================================ */

SELECT *
FROM LIBERACIONES_CHEQUE
ORDER BY ID_LIBERACION;

/* ============================================================
   CASO 12
   NOMBRE:
   Verificación de bitácora

   OBJETIVO:
   Comprobar que todas las operaciones quedaron
   registradas en auditoría.
   ============================================================ */

SELECT *
FROM BITACORA_AUDITORIA
ORDER BY ID_BITACORA;

/* ============================================================
   FIN DE PRUEBAS
   ============================================================ */