-- ==============================================================================
-- ENTREGA 3 - SCRIPT 3: INDICES Y PLANES DE EJECUCION
-- Proyecto Integrador Bases de Datos II - TurismoUQ
-- ------------------------------------------------------------------------------
-- Que hace este script:
--   Toma 3 consultas que usamos en el proyecto y que se ponen lentas cuando la tabla crece,
--   les mira el plan de ejecucion ANTES, crea el indice, y les vuelve a mirar el plan DESPUES.
--   Al final muestra un caso donde un indice NO ayuda y explicamos por que.
--
--   Consulta 1 -> pagos de una reserva            -> indice simple          (PAGO.id_reserva)
--   Consulta 2 -> revision de solape de reservas  -> indice COMPUESTO       (RESERVA_HABITACION)
--   Consulta 3 -> reservas de un mes              -> indice BASADO EN FUNCION (EXTRACT sobre check_in)
--   Caso 4     -> filtrar por estado              -> el indice NO ayuda     (RESERVA.estado)
--
-- Cada consulta lleva un comentario (q1_antes, q1_despues...) para que Oracle la trate como una
-- sentencia nueva y no reuse el plan viejo.
-- ==============================================================================
SET SERVEROUTPUT OFF
SET LINESIZE 220
SET PAGESIZE 200
SET TIMING ON


-- ==============================================================================
-- PASO 0: DEJAR TODO LIMPIO Y CON ESTADISTICAS
-- Borramos los indices que se hicieron como practica para realizar la entrega y recalcula las estadisticas, que son los
-- numeros que el optimizador usa para decidir el plan (cuantas filas tiene cada tabla, etc).
-- ==============================================================================
BEGIN
    FOR x IN (SELECT COLUMN_VALUE AS nombre
              FROM TABLE(SYS.ODCIVARCHAR2LIST('IDX_PAGO_RESERVA', 'IDX_RESHAB_HAB_FECHAS',
                                              'IDX_RESERVA_ANIO_MES', 'IDX_RESERVA_ESTADO'))) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP INDEX ' || x.nombre;
        EXCEPTION
            WHEN OTHERS THEN NULL;   -- si no existe, no pasa nada
        END;
    END LOOP;
    DBMS_STATS.GATHER_SCHEMA_STATS(ownname => USER, cascade => TRUE);
END;
/

-- Que indices tienen hoy las tablas que vamos a consultar. Los que salen son los que crean solos
-- las PK y los UNIQUE. Ninguno empieza por PAGO.id_reserva, ni por RESERVA_HABITACION.id_habitacion,
-- ni sirve para filtrar RESERVA por mes.
SELECT table_name, index_name, uniqueness
FROM user_indexes
WHERE table_name IN ('PAGO', 'RESERVA', 'RESERVA_HABITACION')
ORDER BY table_name, index_name;

-- Cuantas filas tienen (para tener la escala en cuenta):
SELECT 'PAGO' AS tabla, COUNT(*) AS filas FROM PAGO
UNION ALL SELECT 'RESERVA', COUNT(*) FROM RESERVA
UNION ALL SELECT 'RESERVA_HABITACION', COUNT(*) FROM RESERVA_HABITACION;


-- ==============================================================================
-- ======================= PARTE A: ANTES (SIN INDICES) =========================
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- CONSULTA 1: los pagos de una reserva
-- Es la que se usa para armar el estado de cuenta de una reserva. PAGO.id_reserva es llave
-- foranea pero Oracle NO crea indice solo para las llaves foraneas, entonces buscar los pagos
-- de UNA reserva obliga a leer toda la tabla PAGO.
-- ------------------------------------------------------------------------------
EXPLAIN PLAN SET STATEMENT_ID = 'q1_antes' FOR
SELECT p.id_pago, p.fecha_pago, p.monto, p.metodo, p.estado
FROM PAGO p
WHERE p.id_reserva = 15000;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'q1_antes', 'TYPICAL'));
-- LO QUE SE ESPERA VER: TABLE ACCESS FULL sobre PAGO.

SELECT /*+ GATHER_PLAN_STATISTICS */ /* q1_antes */ p.id_pago, p.fecha_pago, p.monto, p.metodo, p.estado
FROM PAGO p
WHERE p.id_reserva = 15000;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));


-- ------------------------------------------------------------------------------
-- CONSULTA 2: revision de solape de una habitacion
-- Es la misma consulta que hacen sp_crear_reserva, sp_reservar_y_pagar y el trigger de solape
-- cada vez que alguien reserva: cuenta las reservas (no canceladas) de UNA habitacion que se
-- cruzan con unas fechas. La unica forma de encontrar una habitacion en RESERVA_HABITACION es
-- leer toda la tabla, porque los indices que existen empiezan por id_reserva.
-- ------------------------------------------------------------------------------
EXPLAIN PLAN SET STATEMENT_ID = 'q2_antes' FOR
SELECT COUNT(*) AS solapes
FROM RESERVA_HABITACION rh
JOIN RESERVA r ON r.id_reserva = rh.id_reserva
WHERE rh.id_habitacion = 100
  AND r.estado <> 'CANCELADA'
  AND DATE '2026-12-20' < rh.check_out
  AND DATE '2026-12-23' > rh.check_in;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'q2_antes', 'TYPICAL'));
-- LO QUE SE ESPERA VER: TABLE ACCESS FULL sobre RESERVA_HABITACION.

SELECT /*+ GATHER_PLAN_STATISTICS */ /* q2_antes */ COUNT(*) AS solapes
FROM RESERVA_HABITACION rh
JOIN RESERVA r ON r.id_reserva = rh.id_reserva
WHERE rh.id_habitacion = 100
  AND r.estado <> 'CANCELADA'
  AND DATE '2026-12-20' < rh.check_out
  AND DATE '2026-12-23' > rh.check_in;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));


-- ------------------------------------------------------------------------------
-- CONSULTA 3: reservas de un mes
-- Es el mismo filtro que usa sp_liquidacion_mensual: EXTRACT(YEAR ...) y EXTRACT(MONTH ...)
-- sobre check_in. Cuando se le aplica una funcion a una columna, un indice normal sobre esa
-- columna NO sirve (Oracle tendria que calcular la funcion fila por fila), asi que lee toda la
-- tabla RESERVA.
-- ------------------------------------------------------------------------------
EXPLAIN PLAN SET STATEMENT_ID = 'q3_antes' FOR
SELECT COUNT(*) AS reservas_dic_2025
FROM RESERVA r
WHERE EXTRACT(YEAR FROM r.check_in) = 2025
  AND EXTRACT(MONTH FROM r.check_in) = 12;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'q3_antes', 'TYPICAL'));
-- LO QUE SE ESPERA VER: TABLE ACCESS FULL sobre RESERVA.

SELECT /*+ GATHER_PLAN_STATISTICS */ /* q3_antes */ COUNT(*) AS reservas_dic_2025
FROM RESERVA r
WHERE EXTRACT(YEAR FROM r.check_in) = 2025
  AND EXTRACT(MONTH FROM r.check_in) = 12;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));


-- ==============================================================================
-- ======================= PARTE B: CREAR LOS INDICES ===========================
-- ==============================================================================

-- Indice 1 (SIMPLE): una sola columna. Sirve para buscar los pagos de una reserva.
CREATE INDEX idx_pago_reserva ON PAGO (id_reserva);

-- Indice 2 (COMPUESTO): varias columnas. Va primero la columna de igualdad (id_habitacion) y
-- despues las de rango (check_in, check_out), que son las que se comparan con "<" y ">".
-- Se agrega id_reserva al final para que el indice tenga TODO lo que la consulta necesita
-- (id_habitacion, fechas y la columna del JOIN) y Oracle no tenga que ir a la tabla.
CREATE INDEX idx_reshab_hab_fechas ON RESERVA_HABITACION (id_habitacion, check_in, check_out, id_reserva);

-- Indice 3 (BASADO EN FUNCION): guarda el resultado de EXTRACT ya calculado para cada fila.
-- La expresion tiene que ser IGUAL a la de la consulta para que Oracle lo use.
CREATE INDEX idx_reserva_anio_mes ON RESERVA (EXTRACT(YEAR FROM check_in), EXTRACT(MONTH FROM check_in));

-- Recalculamos estadisticas de las tablas con indice nuevo
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'PAGO', cascade => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'RESERVA_HABITACION', cascade => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'RESERVA', cascade => TRUE);
END;
/


-- ==============================================================================
-- ====================== PARTE C: DESPUES (CON INDICES) ========================
-- Son las MISMAS 3 consultas de la parte A, sin tocar nada, para comparar.
-- ==============================================================================

-- CONSULTA 1 (despues)
EXPLAIN PLAN SET STATEMENT_ID = 'q1_despues' FOR
SELECT p.id_pago, p.fecha_pago, p.monto, p.metodo, p.estado
FROM PAGO p
WHERE p.id_reserva = 15000;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'q1_despues', 'TYPICAL'));
-- LO QUE SE ESPERA VER: INDEX RANGE SCAN IDX_PAGO_RESERVA + TABLE ACCESS BY INDEX ROWID.

SELECT /*+ GATHER_PLAN_STATISTICS */ /* q1_despues */ p.id_pago, p.fecha_pago, p.monto, p.metodo, p.estado
FROM PAGO p
WHERE p.id_reserva = 15000;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));


-- CONSULTA 2 (despues)
EXPLAIN PLAN SET STATEMENT_ID = 'q2_despues' FOR
SELECT COUNT(*) AS solapes
FROM RESERVA_HABITACION rh
JOIN RESERVA r ON r.id_reserva = rh.id_reserva
WHERE rh.id_habitacion = 100
  AND r.estado <> 'CANCELADA'
  AND DATE '2026-12-20' < rh.check_out
  AND DATE '2026-12-23' > rh.check_in;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'q2_despues', 'TYPICAL'));
-- LO QUE SE ESPERA VER: INDEX RANGE SCAN IDX_RESHAB_HAB_FECHAS en lugar del TABLE ACCESS FULL.

SELECT /*+ GATHER_PLAN_STATISTICS */ /* q2_despues */ COUNT(*) AS solapes
FROM RESERVA_HABITACION rh
JOIN RESERVA r ON r.id_reserva = rh.id_reserva
WHERE rh.id_habitacion = 100
  AND r.estado <> 'CANCELADA'
  AND DATE '2026-12-20' < rh.check_out
  AND DATE '2026-12-23' > rh.check_in;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));


-- CONSULTA 3 (despues)
EXPLAIN PLAN SET STATEMENT_ID = 'q3_despues' FOR
SELECT COUNT(*) AS reservas_dic_2025
FROM RESERVA r
WHERE EXTRACT(YEAR FROM r.check_in) = 2025
  AND EXTRACT(MONTH FROM r.check_in) = 12;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'q3_despues', 'TYPICAL'));
-- LO QUE SE ESPERA VER: INDEX RANGE SCAN IDX_RESERVA_ANIO_MES (sin tocar la tabla).

SELECT /*+ GATHER_PLAN_STATISTICS */ /* q3_despues */ COUNT(*) AS reservas_dic_2025
FROM RESERVA r
WHERE EXTRACT(YEAR FROM r.check_in) = 2025
  AND EXTRACT(MONTH FROM r.check_in) = 12;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));


-- ------------------------------------------------------------------------------
-- Cuanto ocupan los indices nuevos (lo que cuestan)
-- Un indice no es gratis: ocupa espacio y hace mas lentos los INSERT, UPDATE y DELETE de esa
-- tabla porque hay que actualizarlo tambien.
-- ------------------------------------------------------------------------------
SELECT i.index_name, i.table_name, i.leaf_blocks, i.distinct_keys, s.blocks AS bloques_del_segmento
FROM user_indexes i
JOIN user_segments s ON s.segment_name = i.index_name
WHERE i.index_name IN ('IDX_PAGO_RESERVA', 'IDX_RESHAB_HAB_FECHAS', 'IDX_RESERVA_ANIO_MES')
ORDER BY i.index_name;


-- ==============================================================================
-- ================ PARTE D: UN CASO DONDE EL INDICE NO AYUDA ===================
-- Consulta 4: promedio de noches de las reservas COMPLETADAS.
-- Primero miramos cuantas reservas hay de cada estado.
-- ==============================================================================
SELECT estado, COUNT(*) AS reservas,
       ROUND(100 * RATIO_TO_REPORT(COUNT(*)) OVER (), 1) AS porcentaje
FROM RESERVA
GROUP BY estado
ORDER BY reservas DESC;
-- Aqui se ve que COMPLETADA es una parte grande de la tabla.

-- Creamos un indice sobre estado.
CREATE INDEX idx_reserva_estado ON RESERVA (estado);

-- Le decimos al optimizador cuantas filas tiene cada estado para que decida
-- con la informacion completa.
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'RESERVA', cascade => TRUE,
                                  method_opt => 'FOR COLUMNS ESTADO SIZE 254');
END;
/

-- 4.1 La consulta tal cual, dejando que el optimizador elija.
EXPLAIN PLAN SET STATEMENT_ID = 'q4_normal' FOR
SELECT COUNT(*) AS reservas, ROUND(AVG(r.check_out - r.check_in), 2) AS noches_promedio
FROM RESERVA r
WHERE r.estado = 'COMPLETADA';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'q4_normal', 'TYPICAL'));
-- LO QUE SE ESPERA VER: TABLE ACCESS FULL. El optimizador IGNORA el indice que acabamos de crear.

SELECT /*+ GATHER_PLAN_STATISTICS */ /* q4_normal */ COUNT(*) AS reservas, ROUND(AVG(r.check_out - r.check_in), 2) AS noches_promedio
FROM RESERVA r
WHERE r.estado = 'COMPLETADA';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));

-- 4.2 Obligamos a usar el indice con un hint, para ver que pasa si le hacemos caso al indice.
SELECT /*+ GATHER_PLAN_STATISTICS INDEX(r idx_reserva_estado) */ /* q4_forzado */
       COUNT(*) AS reservas, ROUND(AVG(r.check_out - r.check_in), 2) AS noches_promedio
FROM RESERVA r
WHERE r.estado = 'COMPLETADA';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));
-- LO QUE SE ESPERA VER: INDEX RANGE SCAN + TABLE ACCESS BY INDEX ROWID, con MUCHOS mas Buffers
-- (y normalmente mas tiempo) que el TABLE ACCESS FULL de 4.1.

-- Como no sirve y solo estorba, lo borramos y dejamos las estadisticas normales.
DROP INDEX idx_reserva_estado;
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'RESERVA', cascade => TRUE);
END;
/

SET TIMING OFF