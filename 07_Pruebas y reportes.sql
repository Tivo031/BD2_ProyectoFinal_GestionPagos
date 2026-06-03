
-- SCRIPT: _REPORTES.sql
-- DESCRIPCIÓN: Reportes del sistema de cheques
-- ============================================================

-- 1. CHEQUES POR RANGO DE FECHA Y CUENTA
SELECT
c.ID_CHEQUE,
c.NUMERO_CHEQUE,
c.MONTO,
c.FECHA_EMISION,
cb.NUMERO_CUENTA,
ec.NOMBRE_ESTADO
FROM CHEQUES c
JOIN CHEQUERAS ch ON c.ID_CHEQUERA = ch.ID_CHEQUERA
JOIN CUENTAS_BANCARIAS cb ON ch.ID_CUENTA = cb.ID_CUENTA
JOIN ESTADOS_CHEQUE ec ON c.ID_ESTADO = ec.ID_ESTADO
WHERE c.FECHA_EMISION BETWEEN AND
AND cb.ID_CUENTA =
ORDER BY c.FECHA_EMISION;

-- 2. CHEQUES LIBERADOS POR GRUPO
SELECT
c.ID_CHEQUE,
c.NUMERO_CHEQUE,
c.MONTO,
c.FECHA_EMISION,
c.USUARIO_LIBERA,
u.GRUPO,
ec.NOMBRE_ESTADO
FROM CHEQUES c
JOIN USUARIOS_SISTEMA u ON c.USUARIO_LIBERA = u.USUARIO
JOIN ESTADOS_CHEQUE ec ON c.ID_ESTADO = ec.ID_ESTADO
WHERE u.GRUPO =
AND ec.NOMBRE_ESTADO = 'LIBERADO'
ORDER BY c.FECHA_EMISION;

-- 3. BITACORA POR USUARIO
SELECT
b.ID_BITACORA,
b.USUARIO,
b.ACCION,
b.FECHA,
b.DESCRIPCION
FROM BITACORA_AUDITORIA b
WHERE b.USUARIO =
AND b.FECHA BETWEEN AND
ORDER BY b.FECHA;

-- 4. MOVIMIENTOS DE CUENTA
SELECT
m.ID_MOVIMIENTO,
cb.NUMERO_CUENTA,
m.TIPO_MOVIMIENTO,
m.MONTO,
m.FECHA,
m.DESCRIPCION
FROM MOVIMIENTOS_CUENTA m
JOIN CUENTAS_BANCARIAS cb ON m.ID_CUENTA = cb.ID_CUENTA
WHERE cb.ID_CUENTA =
AND m.FECHA BETWEEN AND
ORDER BY m.FECHA;

-- 5. MOVIMIENTOS DE CHEQUES
SELECT
c.ID_CHEQUE,
c.NUMERO_CHEQUE,
c.MONTO,
c.FECHA_EMISION,
ec.NOMBRE_ESTADO,
cb.NUMERO_CUENTA
FROM CHEQUES c
JOIN CHEQUERAS ch ON c.ID_CHEQUERA = ch.ID_CHEQUERA
JOIN CUENTAS_BANCARIAS cb ON ch.ID_CUENTA = cb.ID_CUENTA
JOIN ESTADOS_CHEQUE ec ON c.ID_ESTADO = ec.ID_ESTADO
WHERE c.NUMERO_CHEQUE BETWEEN AND
ORDER BY c.NUMERO_CHEQUE;

-- ============================================================


=====
-- SCRIPT: _PRUEBAS.sql
-- DESCRIPCIÓN: Casos de prueba del sistema
-- ============================================================

SET SERVEROUTPUT ON;

-- ============================================================
-- CASO 1: GENERAR CHEQUE
-- ============================================================

DECLARE
v_id_cheque NUMBER;
BEGIN
PR_GENERAR_CHEQUE(
p_id_chequera => 1,
p_id_beneficiario => 1,
p_monto => 1000,
p_concepto => 'PRUEBA GENERACION',
p_usuario_genera => 'USER_PAGOS',
p_id_cheque => v_id_cheque
);
DBMS_OUTPUT.PUT_LINE('Cheque generado ID: ' || v_id_cheque);
END;
/

-- ============================================================
-- CASO 2: LIBERAR CHEQUE
-- ============================================================

BEGIN
PR_LIBERAR_CHEQUE(
p_id_cheque => 1,
p_usuario => 'USER_AUDITOR'
);
END;
/

-- ============================================================
-- CASO 3: ENTREGAR CHEQUE
-- ============================================================

BEGIN
PR_ENTREGAR_CHEQUE(
p_id_cheque => 1,
p_usuario => 'USER_CAJERO'
);
END;
/

-- ============================================================
-- CASO 4: ANULAR CHEQUE
-- ============================================================

BEGIN
PR_ANULAR_CHEQUE(
p_id_cheque => 2,
p_usuario => 'USER_ADMIN'
);
END;
/

-- ============================================================
-- CASO 5: VALIDAR CONSULTA
-- ============================================================

SELECT * FROM CHEQUES;
SELECT * FROM MOVIMIENTOS_CUENTA;
SELECT * FROM BITACORA_AUDITORIA;

