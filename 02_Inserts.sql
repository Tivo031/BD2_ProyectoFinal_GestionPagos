/* ============================================================
   INSERTS
   Se usan para alimentar la base de datos de información.
   ============================================================ */
/* Estados del cheque */

INSERT INTO ESTADOS_CHEQUE (
    ID_ESTADO,
    NOMBRE_ESTADO,
    DESCRIPCION
) VALUES (
    1,
    'DISPONIBLE',
    'Cheque disponible en la chequera, todavia no generado.'
);

INSERT INTO ESTADOS_CHEQUE (
    ID_ESTADO,
    NOMBRE_ESTADO,
    DESCRIPCION
) VALUES (
    2,
    'GENERADO',
    'Cheque generado por el area de pagos.'
);

INSERT INTO ESTADOS_CHEQUE (
    ID_ESTADO,
    NOMBRE_ESTADO,
    DESCRIPCION
) VALUES (
    3,
    'LIBERADO',
    'Cheque liberado por auditoria y/o gerencia segun el monto.'
);

INSERT INTO ESTADOS_CHEQUE (
    ID_ESTADO,
    NOMBRE_ESTADO,
    DESCRIPCION
) VALUES (
    4,
    'ENTREGADO',
    'Cheque entregado al beneficiario.'
);

INSERT INTO ESTADOS_CHEQUE (
    ID_ESTADO,
    NOMBRE_ESTADO,
    DESCRIPCION
) VALUES (
    5,
    'ANULADO',
    'Cheque anulado por solicitud autorizada.'
);

/* Usuarios base del sistema.
*/

INSERT INTO USUARIOS_SISTEMA (
    ID_USUARIO,
    USUARIO_BD,
    NOMBRE_COMPLETO,
    AREA,
    MONTO_MINIMO,
    MONTO_MAXIMO,
    ESTADO
) VALUES (
    SEQ_USUARIOS_SISTEMA.NEXTVAL,
    'USR_JUANITO',
    'Juanito Prueba',
    'PAGOS',
    1000,
    10000,
    'A'
);

INSERT INTO USUARIOS_SISTEMA (
    ID_USUARIO,
    USUARIO_BD,
    NOMBRE_COMPLETO,
    AREA,
    MONTO_MINIMO,
    MONTO_MAXIMO,
    ESTADO
) VALUES (
    SEQ_USUARIOS_SISTEMA.NEXTVAL,
    'USR_PAGOS2',
    'Usuario Pagos Dos',
    'PAGOS',
    500,
    5000,
    'A'
);

INSERT INTO USUARIOS_SISTEMA (
    ID_USUARIO,
    USUARIO_BD,
    NOMBRE_COMPLETO,
    AREA,
    MONTO_MINIMO,
    MONTO_MAXIMO,
    ESTADO
) VALUES (
    SEQ_USUARIOS_SISTEMA.NEXTVAL,
    'USR_JEFE_PAGOS',
    'Jefe de Pagos',
    'JEFE_PAGOS',
    0,
    1000000,
    'A'
);

INSERT INTO USUARIOS_SISTEMA (
    ID_USUARIO,
    USUARIO_BD,
    NOMBRE_COMPLETO,
    AREA,
    MONTO_MINIMO,
    MONTO_MAXIMO,
    ESTADO
) VALUES (
    SEQ_USUARIOS_SISTEMA.NEXTVAL,
    'USR_AUDITOR',
    'Usuario Auditoria',
    'AUDITORIA',
    0,
    0,
    'A'
);

INSERT INTO USUARIOS_SISTEMA (
    ID_USUARIO,
    USUARIO_BD,
    NOMBRE_COMPLETO,
    AREA,
    MONTO_MINIMO,
    MONTO_MAXIMO,
    ESTADO
) VALUES (
    SEQ_USUARIOS_SISTEMA.NEXTVAL,
    'USR_GERENTE',
    'Usuario Gerencia',
    'GERENCIA',
    0,
    0,
    'A'
);

INSERT INTO USUARIOS_SISTEMA (
    ID_USUARIO,
    USUARIO_BD,
    NOMBRE_COMPLETO,
    AREA,
    MONTO_MINIMO,
    MONTO_MAXIMO,
    ESTADO
) VALUES (
    SEQ_USUARIOS_SISTEMA.NEXTVAL,
    'USR_CAJERO',
    'Usuario Cajero',
    'CAJERO',
    0,
    0,
    'A'
);

/* Beneficiarios */

INSERT INTO BENEFICIARIOS (
    ID_BENEFICIARIO,
    NIT,
    NOMBRE,
    DIRECCION,
    TELEFONO,
    ESTADO
) VALUES (
    SEQ_BENEFICIARIOS.NEXTVAL,
    '1234567-8',
    'Proveedor La Esperanza, S.A.',
    'Guatemala, Guatemala',
    '2222-1111',
    'A'
);

INSERT INTO BENEFICIARIOS (
    ID_BENEFICIARIO,
    NIT,
    NOMBRE,
    DIRECCION,
    TELEFONO,
    ESTADO
) VALUES (
    SEQ_BENEFICIARIOS.NEXTVAL,
    '9876543-2',
    'Servicios del Norte',
    'Cobán, Alta Verapaz',
    '5555-3333',
    'A'
);

/* Cuenta bancaria principal */

INSERT INTO CUENTAS_BANCARIAS (
    ID_CUENTA,
    BANCO,
    NUMERO_CUENTA,
    NOMBRE_CUENTA,
    TIPO_CUENTA,
    MONEDA,
    SALDO_ACTUAL,
    SALDO_RESERVADO,
    ESTADO
) VALUES (
    SEQ_CUENTAS_BANCARIAS.NEXTVAL,
    'Banco Industrial',
    '001-000123-0',
    'NUEVA VERAPAZ - Cuenta Principal',
    'MONETARIA',
    'GTQ',
    100000,
    0,
    'A'
);

/* Chequera */

INSERT INTO CHEQUERAS (
    ID_CHEQUERA,
    ID_CUENTA,
    NUMERO_CHEQUERA,
    NUMERO_INICIAL,
    NUMERO_FINAL,
    CORRELATIVO_ACTUAL,
    ESTADO
) VALUES (
    SEQ_CHEQUERAS.NEXTVAL,
    1,
    'CHQ-2026-001',
    1001,
    1100,
    1001,
    'A'
);

/* Cheques disponibles */

INSERT INTO CHEQUES (
    ID_CHEQUE,
    ID_CHEQUERA,
    ID_CUENTA,
    NUMERO_CHEQUE,
    ID_ESTADO,
    REQUIERE_AUDITORIA,
    REQUIERE_GERENCIA
) VALUES (
    SEQ_CHEQUES.NEXTVAL,
    1,
    1,
    1001,
    1,
    'N',
    'N'
);

INSERT INTO CHEQUES (
    ID_CHEQUE,
    ID_CHEQUERA,
    ID_CUENTA,
    NUMERO_CHEQUE,
    ID_ESTADO,
    REQUIERE_AUDITORIA,
    REQUIERE_GERENCIA
) VALUES (
    SEQ_CHEQUES.NEXTVAL,
    1,
    1,
    1002,
    1,
    'N',
    'N'
);

INSERT INTO CHEQUES (
    ID_CHEQUE,
    ID_CHEQUERA,
    ID_CUENTA,
    NUMERO_CHEQUE,
    ID_ESTADO,
    REQUIERE_AUDITORIA,
    REQUIERE_GERENCIA
) VALUES (
    SEQ_CHEQUES.NEXTVAL,
    1,
    1,
    1003,
    1,
    'N',
    'N'
);

COMMIT;