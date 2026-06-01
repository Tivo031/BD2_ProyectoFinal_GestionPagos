/* ============================================================
   INDICES PARA OPTIMIZAR REPORTES
   ============================================================ */


/* Reporte de cheques por fecha y cuenta */
CREATE INDEX IDX_CHEQUES_CUENTA_FECHA
ON CHEQUES (ID_CUENTA, FECHA_GENERACION);


/* Reporte de cheques por estado */
CREATE INDEX IDX_CHEQUES_ESTADO
ON CHEQUES (ID_ESTADO);


/* Busqueda de cheques por numero */
CREATE INDEX IDX_CHEQUES_NUMERO
ON CHEQUES (NUMERO_CHEQUE);


/* Reporte de liberaciones por grupo y fecha */
CREATE INDEX IDX_LIBERACIONES_GRUPO_FECHA
ON LIBERACIONES_CHEQUE (GRUPO_LIBERACION, FECHA_LIBERACION);


/* Reporte de bitacora por usuario y fecha */
CREATE INDEX IDX_BITACORA_USUARIO_FECHA
ON BITACORA_AUDITORIA (USUARIO_BD, FECHA_EVENTO);


/* Reporte de bitacora por accion */
CREATE INDEX IDX_BITACORA_ACCION
ON BITACORA_AUDITORIA (ACCION);


/* Reporte de movimientos de cuenta */
CREATE INDEX IDX_MOVIMIENTOS_CUENTA_FECHA
ON MOVIMIENTOS_CUENTA (ID_CUENTA, FECHA_MOVIMIENTO);


/* Reporte de movimientos por cheque */
CREATE INDEX IDX_MOVIMIENTOS_CHEQUE
ON MOVIMIENTOS_CUENTA (ID_CHEQUE);


/* Busqueda de chequeras por cuenta */
CREATE INDEX IDX_CHEQUERAS_CUENTA
ON CHEQUERAS (ID_CUENTA);