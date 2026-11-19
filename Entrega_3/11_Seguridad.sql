-- ==============================================================================
-- ENTREGA 3 - SCRIPT 4: SEGURIDAD (ROLES, USUARIOS, VISTAS, GRANT Y PERFIL)
-- Proyecto Integrador Bases de Datos II - TurismoUQ
-- ------------------------------------------------------------------------------
-- Que hace este script:
--   1. Crea un PERFIL con limites de sesion.
--   2. Crea las VISTAS que se le dan a cada tipo de usuario (para ocultar columnas y filas).
--   3. Crea los 4 ROLES y les da sus privilegios (GRANT), cada uno distinto.
--   4. Crea un usuario de ejemplo por rol, con el perfil, para poder probar.
--   5. Consultas al diccionario de datos para tener la evidencia de los privilegios.
--
--
-- Resumen de quien puede hacer que:
--   ROL_RECEPCION         -> SOLO vistas (nunca tablas): ver reservas vigentes, habitaciones y
--                            clientes (sin correo). Registra reservas llamando al procedimiento
--                            sp_reservar_y_pagar, que corre con los permisos del dueno del esquema.
--   ROL_ADMIN_ALOJAMIENTO -> vistas filtradas a SU alojamiento (se detecta con su usuario). Puede
--                            cambiar tarifas y precios de servicios de su alojamiento, nada mas.
--   ROL_GERENTE           -> lee todas las tablas del negocio, la vista materializada y las
--                            liquidaciones, y puede ejecutar el paquete (liquidacion mensual).
--                            No puede modificar ni borrar datos directamente en las tablas.
--   ROL_AUDITOR           -> solo lectura de la auditoria de tarifas, las liquidaciones y vistas de
--                            reservas y pagos SIN datos personales de clientes.
-- ==============================================================================
SET SERVEROUTPUT ON;


-- ==============================================================================
-- PASO 0: LIMPIEZA (para poder repetir el script)
-- Borramos los usuarios, roles y perfil que se crearon cuanto esatabamos ensayando el script.
-- ==============================================================================
BEGIN
    FOR x IN (SELECT COLUMN_VALUE AS nombre
              FROM TABLE(SYS.ODCIVARCHAR2LIST('USR_RECEPCION', 'ENC_HOTEL1', 'USR_GERENTE', 'USR_AUDITOR'))) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP USER ' || x.nombre || ' CASCADE';
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
    END LOOP;
    FOR x IN (SELECT COLUMN_VALUE AS nombre
              FROM TABLE(SYS.ODCIVARCHAR2LIST('ROL_RECEPCION', 'ROL_ADMIN_ALOJAMIENTO', 'ROL_GERENTE', 'ROL_AUDITOR'))) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP ROLE ' || x.nombre;
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
    END LOOP;
    BEGIN
        EXECUTE IMMEDIATE 'DROP PROFILE perfil_turismouq CASCADE';
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;
END;
/


-- ==============================================================================
-- PASO 1: EL PERFIL CON LIMITES DE SESION
-- Un perfil es un conjunto de limites que se le asigna a los usuarios. Estos son los de
-- TurismoUQ para el personal:
--   SESSIONS_PER_USER 2        -> maximo 2 conexiones al mismo tiempo con el mismo usuario
--   CONNECT_TIME 480           -> una sesion dura maximo 480 minutos (8 horas, un turno)
--   IDLE_TIME 30               -> si la sesion esta quieta 30 minutos, se cierra sola
--   CPU_PER_CALL 6000          -> una sola consulta no puede gastar mas de 60 segundos de CPU
--                                 (la unidad son centesimas de segundo)
--   FAILED_LOGIN_ATTEMPTS 3    -> con 3 claves malas seguidas la cuenta se bloquea
--   PASSWORD_LOCK_TIME 1/24    -> y queda bloqueada 1 hora (1/24 de dia)
--   PASSWORD_LIFE_TIME 90      -> la clave se vence a los 90 dias
--   PASSWORD_GRACE_TIME 7      -> y hay 7 dias de gracia para cambiarla
-- ==============================================================================
CREATE PROFILE perfil_turismouq LIMIT
    SESSIONS_PER_USER      2
    CONNECT_TIME           480
    IDLE_TIME              30
    CPU_PER_CALL           6000
    FAILED_LOGIN_ATTEMPTS  3
    PASSWORD_LOCK_TIME     1/24
    PASSWORD_LIFE_TIME     90
    PASSWORD_GRACE_TIME    7;

-- Los limites de recursos (sesiones, tiempo conectado, tiempo quieto, CPU) solo se aplican si el
-- parametro RESOURCE_LIMIT esta en TRUE. En Oracle 21c viene en TRUE por defecto, pero lo
-- revisamos. (Los limites de claves, como FAILED_LOGIN_ATTEMPTS, se aplican siempre.)
SELECT name, value FROM v$parameter WHERE name = 'resource_limit';
-- RESULTADO ESPERADO: TRUE. Si saliera FALSE, ejecutar:  ALTER SYSTEM SET resource_limit = TRUE;


-- ==============================================================================
-- PASO 2: LAS VISTAS
-- Una vista es una consulta guardada con nombre. Sirve para seguridad porque se le puede dar
-- permiso a la vista SIN darlo sobre las tablas de abajo: el usuario solo ve las columnas y
-- las filas que la vista deja pasar.
-- WITH READ ONLY = nadie puede modificar datos a traves de esa vista.
-- ==============================================================================

-- ---------------------- Vistas de RECEPCION ----------------------

-- Reservas vigentes (PENDIENTE o CONFIRMADA) con lo que necesita el mostrador.
-- No se muestran correo ni documento del cliente.
CREATE OR REPLACE VIEW VW_RECEPCION_RESERVAS AS
SELECT r.id_reserva,
       r.estado,
       r.check_in,
       r.check_out,
       a.nombre_comercial AS alojamiento,
       h.numero           AS habitacion,
       h.tipo             AS tipo_habitacion,
       rh.num_huespedes,
       c.nombre || ' ' || c.apellido AS cliente,
       c.telefono         AS telefono_cliente,
       rh.valor_estadia,
       (SELECT NVL(SUM(p.monto), 0) FROM PAGO p
        WHERE p.id_reserva = r.id_reserva AND p.estado = 'EXITOSO') AS total_pagado
FROM RESERVA r
JOIN RESERVA_HABITACION rh ON rh.id_reserva = r.id_reserva
JOIN HABITACION h          ON h.id_habitacion = rh.id_habitacion
JOIN ALOJAMIENTO a         ON a.id_alojamiento = r.id_alojamiento
JOIN CLIENTE c             ON c.id_cliente = r.id_cliente
WHERE r.estado IN ('PENDIENTE', 'CONFIRMADA')
WITH READ ONLY;

-- Catalogo de habitaciones de los alojamientos activos, con una marca de si hoy estan ocupadas.
CREATE OR REPLACE VIEW VW_RECEPCION_HABITACIONES AS
SELECT h.id_habitacion,
       a.id_alojamiento,
       a.nombre_comercial AS alojamiento,
       m.nombre           AS municipio,
       h.numero,
       h.tipo,
       h.capacidad,
       CASE WHEN EXISTS (SELECT 1
                         FROM RESERVA_HABITACION rh
                         JOIN RESERVA r ON r.id_reserva = rh.id_reserva
                         WHERE rh.id_habitacion = h.id_habitacion
                           AND r.estado IN ('PENDIENTE', 'CONFIRMADA')
                           AND TRUNC(SYSDATE) >= rh.check_in
                           AND TRUNC(SYSDATE) <  rh.check_out)
            THEN 'S' ELSE 'N' END AS ocupada_hoy
FROM HABITACION h
JOIN ALOJAMIENTO a ON a.id_alojamiento = h.id_alojamiento
JOIN MUNICIPIO m   ON m.id_municipio = a.id_municipio
WHERE a.activo = 'S'
WITH READ ONLY;

-- Clientes: lo necesario para encontrarlos en el mostrador (sin correo ni ciudad).
CREATE OR REPLACE VIEW VW_RECEPCION_CLIENTES AS
SELECT c.id_cliente,
       c.tipo_documento,
       c.numero_documento,
       c.nombre,
       c.apellido,
       c.telefono
FROM CLIENTE c
WITH READ ONLY;


-- ---------------- Vistas de ADMINISTRADOR DE ALOJAMIENTO ----------------
-- Cada encargado administra UN alojamiento (tabla USUARIO_SISTEMA). Para que cada uno vea solo
-- el suyo, la vista base mira con que usuario de Oracle se conecto y lo busca en
-- USUARIO_SISTEMA. Se quitan los puntos del username porque un usuario de Oracle no los
-- lleva:  'enc.hotel1' (tabla)  <->  ENC_HOTEL1 (usuario de Oracle).
-- Si el usuario no esta en la tabla, la vista queda vacia y no ve nada.

CREATE OR REPLACE VIEW VW_ADMIN_MI_ALOJAMIENTO AS
SELECT us.id_alojamiento
FROM USUARIO_SISTEMA us
WHERE us.rol = 'ENCARGADO_ALOJAMIENTO'
  AND us.activo = 'S'
  AND REPLACE(UPPER(us.username), '.', '_') = SYS_CONTEXT('USERENV', 'SESSION_USER')
WITH READ ONLY;

-- Reservas de su alojamiento (con el nombre del cliente, sin correo ni documento).
CREATE OR REPLACE VIEW VW_ADMIN_RESERVAS AS
SELECT r.id_reserva,
       r.estado,
       r.check_in,
       r.check_out,
       h.numero AS habitacion,
       rh.num_huespedes,
       rh.valor_estadia,
       c.nombre || ' ' || c.apellido AS cliente
FROM RESERVA r
JOIN RESERVA_HABITACION rh ON rh.id_reserva = r.id_reserva
JOIN HABITACION h          ON h.id_habitacion = rh.id_habitacion
JOIN CLIENTE c             ON c.id_cliente = r.id_cliente
WHERE r.id_alojamiento IN (SELECT id_alojamiento FROM VW_ADMIN_MI_ALOJAMIENTO)
WITH READ ONLY;

-- Habitaciones de su alojamiento.
CREATE OR REPLACE VIEW VW_ADMIN_HABITACIONES AS
SELECT h.id_habitacion, h.numero, h.capacidad, h.tipo, h.descripcion
FROM HABITACION h
WHERE h.id_alojamiento IN (SELECT id_alojamiento FROM VW_ADMIN_MI_ALOJAMIENTO)
WITH READ ONLY;

-- Tarifas de las habitaciones de su alojamiento. Esta vista SI se puede modificar (solo la
-- columna valor_noche, por el GRANT de mas abajo). WITH CHECK OPTION impide que meta o
-- cambie filas que queden fuera de su alojamiento.
CREATE OR REPLACE VIEW VW_ADMIN_TARIFAS AS
SELECT ta.id_habitacion, ta.id_temporada, ta.valor_noche
FROM TARIFA ta
WHERE ta.id_habitacion IN (SELECT h.id_habitacion
                           FROM HABITACION h
                           WHERE h.id_alojamiento IN (SELECT id_alojamiento FROM VW_ADMIN_MI_ALOJAMIENTO))
WITH CHECK OPTION;

-- Servicios de su alojamiento. Tambien modificable (solo el precio).
CREATE OR REPLACE VIEW VW_ADMIN_SERVICIOS AS
SELECT s.id_servicio, s.id_alojamiento, s.nombre, s.descripcion, s.precio
FROM SERVICIO s
WHERE s.id_alojamiento IN (SELECT id_alojamiento FROM VW_ADMIN_MI_ALOJAMIENTO)
WITH CHECK OPTION;


-- ---------------------- Vistas del AUDITOR ----------------------
-- Ve reservas y pagos para poder revisarlos, pero sin nombre, correo ni documento del
-- cliente (solo el id).

CREATE OR REPLACE VIEW VW_AUDITOR_RESERVAS AS
SELECT r.id_reserva,
       r.id_cliente,
       a.nombre_comercial AS alojamiento,
       r.fecha_creacion,
       r.check_in,
       r.check_out,
       r.estado,
       r.fecha_cancelacion
FROM RESERVA r
JOIN ALOJAMIENTO a ON a.id_alojamiento = r.id_alojamiento
WITH READ ONLY;

CREATE OR REPLACE VIEW VW_AUDITOR_PAGOS AS
SELECT p.id_pago,
       p.id_reserva,
       a.nombre_comercial AS alojamiento,
       p.fecha_pago,
       p.monto,
       p.metodo,
       p.estado
FROM PAGO p
JOIN RESERVA r     ON r.id_reserva = p.id_reserva
JOIN ALOJAMIENTO a ON a.id_alojamiento = r.id_alojamiento
WITH READ ONLY;


-- ==============================================================================
-- PASO 3: LOS 4 ROLES
-- Un rol es un paquete de privilegios con nombre. Se le dan los privilegios al rol una vez y
-- despues el rol se le da a los usuarios. Todos llevan CREATE SESSION para poder conectarse.
-- ==============================================================================
CREATE ROLE rol_recepcion;
CREATE ROLE rol_admin_alojamiento;
CREATE ROLE rol_gerente;
CREATE ROLE rol_auditor;

GRANT CREATE SESSION TO rol_recepcion;
GRANT CREATE SESSION TO rol_admin_alojamiento;
GRANT CREATE SESSION TO rol_gerente;
GRANT CREATE SESSION TO rol_auditor;


-- ==============================================================================
-- PASO 4: LOS PRIVILEGIOS DE CADA ROL (GRANT)
-- ==============================================================================

-- ---------------------- RECEPCION: solo vistas y un procedimiento ----------------------
-- Ningun GRANT sobre tablas. Para registrar una reserva ejecuta sp_reservar_y_pagar: los
-- procedimientos corren con los permisos de su dueno (turismouq), entonces recepcion puede
-- crear la reserva y el pago sin tener acceso directo a RESERVA ni a PAGO.
GRANT SELECT ON VW_RECEPCION_RESERVAS     TO rol_recepcion;
GRANT SELECT ON VW_RECEPCION_HABITACIONES TO rol_recepcion;
GRANT SELECT ON VW_RECEPCION_CLIENTES     TO rol_recepcion;
GRANT EXECUTE ON sp_reservar_y_pagar      TO rol_recepcion;

-- ---------------------- ADMINISTRADOR DE ALOJAMIENTO ----------------------
GRANT SELECT ON VW_ADMIN_RESERVAS     TO rol_admin_alojamiento;
GRANT SELECT ON VW_ADMIN_HABITACIONES TO rol_admin_alojamiento;
GRANT SELECT ON VW_ADMIN_TARIFAS      TO rol_admin_alojamiento;
GRANT SELECT ON VW_ADMIN_SERVICIOS    TO rol_admin_alojamiento;
-- puede cambiar el valor de las tarifas y el precio de los servicios, y solo esas dos columnas
GRANT UPDATE (valor_noche) ON VW_ADMIN_TARIFAS   TO rol_admin_alojamiento;
GRANT UPDATE (precio)      ON VW_ADMIN_SERVICIOS TO rol_admin_alojamiento;

-- ---------------------- GERENTE: lee todo, no modifica ----------------------
GRANT SELECT ON MUNICIPIO          TO rol_gerente;
GRANT SELECT ON TIPO_ALOJAMIENTO   TO rol_gerente;
GRANT SELECT ON ALOJAMIENTO        TO rol_gerente;
GRANT SELECT ON HABITACION         TO rol_gerente;
GRANT SELECT ON TEMPORADA          TO rol_gerente;
GRANT SELECT ON TARIFA             TO rol_gerente;
GRANT SELECT ON CLIENTE            TO rol_gerente;
GRANT SELECT ON RESERVA            TO rol_gerente;
GRANT SELECT ON RESERVA_HABITACION TO rol_gerente;
GRANT SELECT ON PAGO               TO rol_gerente;
GRANT SELECT ON SERVICIO           TO rol_gerente;
GRANT SELECT ON RESERVA_SERVICIO   TO rol_gerente;
GRANT SELECT ON RESENA             TO rol_gerente;
GRANT SELECT ON LIQUIDACION_MENSUAL   TO rol_gerente;
GRANT SELECT ON MV_OCUPACION_MENSUAL  TO rol_gerente;
-- puede correr la liquidacion mensual (y las demas funciones) del paquete
GRANT EXECUTE ON PKG_TURISMOUQ     TO rol_gerente;

-- ---------------------- AUDITOR: solo lectura de lo que debe revisar ----------------------
GRANT SELECT ON AUDITORIA_TARIFA     TO rol_auditor;
GRANT SELECT ON LIQUIDACION_MENSUAL  TO rol_auditor;
GRANT SELECT ON VW_AUDITOR_RESERVAS  TO rol_auditor;
GRANT SELECT ON VW_AUDITOR_PAGOS     TO rol_auditor;


-- ==============================================================================
-- PASO 5: UN USUARIO DE EJEMPLO POR ROL (con el perfil)
--   USR_RECEPCION -> rol_recepcion
--   ENC_HOTEL1    -> rol_admin_alojamiento. Su nombre coincide con el username 'enc.hotel1' de
--                    USUARIO_SISTEMA, que es el encargado del alojamiento 1.
--   USR_GERENTE   -> rol_gerente
--   USR_AUDITOR   -> rol_auditor
-- ==============================================================================
CREATE USER usr_recepcion IDENTIFIED BY "Recepcion_2026" PROFILE perfil_turismouq;
CREATE USER enc_hotel1    IDENTIFIED BY "Hotel1_2026"    PROFILE perfil_turismouq;
CREATE USER usr_gerente   IDENTIFIED BY "Gerente_2026"   PROFILE perfil_turismouq;
CREATE USER usr_auditor   IDENTIFIED BY "Auditor_2026"   PROFILE perfil_turismouq;

GRANT rol_recepcion         TO usr_recepcion;
GRANT rol_admin_alojamiento TO enc_hotel1;
GRANT rol_gerente           TO usr_gerente;
GRANT rol_auditor           TO usr_auditor;


-- ==============================================================================
-- PASO 6: EVIDENCIA
-- ==============================================================================

-- 6.1 Que rol tiene cada usuario y con que perfil:
SELECT u.username, r.granted_role AS rol, u.profile AS perfil
FROM dba_users u
LEFT JOIN dba_role_privs r ON r.grantee = u.username
WHERE u.username IN ('USR_RECEPCION', 'ENC_HOTEL1', 'USR_GERENTE', 'USR_AUDITOR')
ORDER BY u.username;

-- 6.2 Los limites del perfil:
SELECT resource_name, limit
FROM dba_profiles
WHERE profile = 'PERFIL_TURISMOUQ'
  AND resource_name IN ('SESSIONS_PER_USER', 'CONNECT_TIME', 'IDLE_TIME', 'CPU_PER_CALL',
                        'FAILED_LOGIN_ATTEMPTS', 'PASSWORD_LOCK_TIME', 'PASSWORD_LIFE_TIME',
                        'PASSWORD_GRACE_TIME')
ORDER BY resource_name;

-- 6.3 Privilegios sobre objetos de cada rol (diferenciados):
SELECT grantee AS rol, table_name AS objeto, privilege AS privilegio, owner AS dueno
FROM dba_tab_privs
WHERE grantee IN ('ROL_RECEPCION', 'ROL_ADMIN_ALOJAMIENTO', 'ROL_GERENTE', 'ROL_AUDITOR')
ORDER BY grantee, table_name, privilege;

-- 6.4 Prueba de que RECEPCION no tiene permisos sobre ninguna TABLA (solo vistas y procedimiento):
SELECT o.object_type, COUNT(*) AS privilegios
FROM dba_tab_privs tp
JOIN dba_objects o ON o.owner = tp.owner AND o.object_name = tp.table_name
WHERE tp.grantee = 'ROL_RECEPCION'
GROUP BY o.object_type
ORDER BY o.object_type;
-- RESULTADO ESPERADO: solo salen VIEW (3) y PROCEDURE (1). Ninguna fila con TABLE.

-- 6.5 Que ningun rol (aparte del gerente) toca las tablas de clientes:
SELECT grantee AS rol, table_name, privilege
FROM dba_tab_privs
WHERE table_name = 'CLIENTE' AND grantee LIKE 'ROL_%';
-- RESULTADO ESPERADO: solo ROL_GERENTE con SELECT.
