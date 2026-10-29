-- ==============================================================================
-- ENTREGA 2 - SCRIPT 3: TABLESPACE Y VISTA MATERIALIZADA
-- Proyecto Integrador Bases de Datos II - TurismoUQ
-- ------------------------------------------------------------------------------
-- Que hacemos en este script:
--   1. Creamos un tablespace propio (TS_HISTORICO_TURISMO) para el historico de reservas.
--   2. Creamos la tabla RESERVA_HISTORICO dentro de ese tablespace y le copia las reservas viejas.
--   3. Creamos la vista materializada MV_OCUPACION_MENSUAL (ocupacion por municipio y mes).
--
--  este script lo ejecutamos con dos usuarios:
--   PARTE A que se conecta conectado como SYSTEM ya que crear un tablespace es un permiso de administrador.
--   PARTE B conectado como el usuario del proyecto (turismouq)
-- ==============================================================================


-- ==============================================================================
-- JUSTIFICACION DEL TABLESPACE
-- Las reservas viejas casi no se modifican, se consultan poco y crecen mucho cada año.
-- Por eso las guardamos en su propio tablespace (TS_HISTORICO_TURISMO) y no en USERS:
--   1) se puede poner en discos mas baratos o mas lentos, porque casi no se usa
--   2) se le puede hacer backup aparte y con menos frecuencia
--   3) no llena ni fragmenta USERS, que es donde esta lo que se usa todos los dias
--   4) cuando un año ya cerro, se puede pasar a solo lectura (ALTER TABLESPACE ... READ ONLY)
-- ==============================================================================


-- ==============================================================================
-- PARTE A: aqui lo ejecutamos con el mismo usuario ya que turismouq tiene permisos de administrador,
--          si no tuviera estos permisos lo tendriamos que haber corrido en usuario SYSTEM 
-- ==============================================================================

-- Creamos el tablespace. DATAFILE es el archivo fisico donde se guardan los datos:
--   SIZE 50M       -> arranca con 50 MB
--   AUTOEXTEND ON  -> si se llena, crece solo de 10 MB en 10 MB
--   MAXSIZE 500M   -> pero nunca pasa de 500 MB

CREATE TABLESPACE TS_HISTORICO_TURISMO
DATAFILE '/opt/oracle/oradata/FREE/FREEPDB1/TS_HISTORICO_TURISMO.DBF'
SIZE 50M AUTOEXTEND ON NEXT 10M MAXSIZE 500M;

-- Permiso para guardar tablas en este tablespace. Nuestro usuario ya tiene UNLIMITED TABLESPACE
-- (por los roles RESOURCE y DBA), pero con un usuario con permisos basicos esta linea es necesaria.
ALTER USER turismouq QUOTA UNLIMITED ON TS_HISTORICO_TURISMO;


-- ==============================================================================
-- PARTE B:
-- ==============================================================================

-- Tabla del historico. La clausula "TABLESPACE" es la que la manda a guardarse en el
-- tablespace nuevo y no en USERS. No tiene llaves foraneas a proposito: es una copia
-- congelada de la reserva, para que se pueda archivar sin depender de las otras tablas.
CREATE TABLE RESERVA_HISTORICO (
    id_reserva NUMBER(8),
    id_cliente NUMBER(6),
    id_alojamiento NUMBER(5),
    check_in DATE,
    check_out DATE,
    estado VARCHAR2(10),
    valor_total NUMBER(12),                -- lo que valio la reserva (suma de sus habitaciones)
    fecha_archivado DATE DEFAULT SYSDATE   -- cuando se copio al historico
) TABLESPACE TS_HISTORICO_TURISMO;

COMMENT ON TABLE RESERVA_HISTORICO IS 'Reservas de anios anteriores, copiadas aqui para no cargar el tablespace principal';

-- Ejemplo de archivado: copiamos las reservas COMPLETADAS o CANCELADAS que terminaron antes
-- de 2025. Solo las copia, no borra las originales.
INSERT INTO RESERVA_HISTORICO (id_reserva, id_cliente, id_alojamiento, check_in, check_out, estado, valor_total)
SELECT r.id_reserva, r.id_cliente, r.id_alojamiento, r.check_in, r.check_out, r.estado,
       (SELECT NVL(SUM(rh.valor_estadia), 0) FROM RESERVA_HABITACION rh WHERE rh.id_reserva = r.id_reserva)
FROM RESERVA r
WHERE r.check_out < DATE '2025-01-01'
  AND r.estado IN ('COMPLETADA', 'CANCELADA');
COMMIT;

-- Para comprobar que la tabla quedo en el tablespace correcto (debe decir TS_HISTORICO_TURISMO):
-- SELECT table_name, tablespace_name FROM user_tables WHERE table_name = 'RESERVA_HISTORICO';


-- ==============================================================================
-- VISTA MATERIALIZADA: ocupacion mensual por municipio
-- Una vista normal vuelve a ejecutar la consulta cada vez que la usan. Una vista materializada
-- guarda el resultado ya calculado, asi que consultarla es muy rapido.
-- La agrupamos por municipio y por el mes del check-in de cada habitacion reservada, y solo
-- cuenta reservas CONFIRMADAS o COMPLETADAS (las pendientes y canceladas no ocupan).
--
-- JUSTIFICACION DE LA POLITICA DE REFRESCO: REFRESH COMPLETE ON DEMAND
--   - La ocupacion solo cambia cuando se crea, confirma o cancela una reserva, y quien la mira
--     (la gerencia) no necesita el dato al segundo, con que este al dia le sirve.
--   - COMPLETE ON DEMAND significa que se recalcula completa solo cuando se pide (por ejemplo
--     una vez cada noche), y no pesa en cada reserva que se hace.
--   - Un refresco FAST ON COMMIT haria mas lento cada COMMIT (hay decenas de miles de reservas),
--     obligaria a crear logs en varias tablas, y la consulta tiene COUNT(DISTINCT) y varios JOIN,
--     que limitan el refresco rapido.
--   Es un buen equilibrio entre datos frescos y rendimiento.
-- No la pusimos en el tablespace historico porque es un resumen de lo que esta pasando ahora.
-- ==============================================================================
CREATE MATERIALIZED VIEW MV_OCUPACION_MENSUAL
BUILD IMMEDIATE           -- se llena apenas se crea
REFRESH COMPLETE ON DEMAND
AS
SELECT
    a.id_municipio,
    m.nombre AS municipio,
    EXTRACT(YEAR FROM rh.check_in) AS anio,
    EXTRACT(MONTH FROM rh.check_in) AS mes,
    COUNT(rh.id_reserva_hab) AS num_reservas,                  -- habitaciones reservadas ese mes
    SUM(rh.check_out - rh.check_in) AS noches_ocupadas,        -- noches totales
    SUM(rh.valor_estadia) AS ingresos_hospedaje,               -- plata del hospedaje
    COUNT(DISTINCT rh.id_habitacion) AS habitaciones_ocupadas  -- cuantas habitaciones distintas se usaron
FROM RESERVA_HABITACION rh
JOIN RESERVA r ON r.id_reserva = rh.id_reserva
JOIN ALOJAMIENTO a ON a.id_alojamiento = r.id_alojamiento
JOIN MUNICIPIO m ON m.id_municipio = a.id_municipio
WHERE r.estado IN ('CONFIRMADA','COMPLETADA')
GROUP BY a.id_municipio, m.nombre, EXTRACT(YEAR FROM rh.check_in), EXTRACT(MONTH FROM rh.check_in);

-- Para refrescarla a mano (la 'C' es de Complete). Solo hace falta si los datos cambiaron
-- despues de crearla y queremos verlos reflejados:
-- EXEC DBMS_MVIEW.REFRESH('MV_OCUPACION_MENSUAL','C');

-- OPCIONAL: hacer que se refresque sola todos los dias a las 2 a.m. con un job.
-- Para activarlo, primero SYSTEM le da el permiso:  GRANT CREATE JOB TO turismouq;
-- y despues se quitan los "--" de este bloque y se ejecuta (junto con la "/" del final).
-- BEGIN
--   DBMS_SCHEDULER.CREATE_JOB(
--     job_name        => 'JOB_REFRESCAR_MV_OCUPACION',
--     job_type        => 'PLSQL_BLOCK',
--     job_action      => 'BEGIN DBMS_MVIEW.REFRESH(''MV_OCUPACION_MENSUAL'',''C''); END;',
--     repeat_interval => 'FREQ=DAILY;BYHOUR=2;BYMINUTE=0;BYSECOND=0',
--     enabled         => TRUE);
-- END;
-- /