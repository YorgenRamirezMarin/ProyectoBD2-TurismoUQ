-- DEFINICIONES DE NEGOCIO usadas en el script:
--   * Noche ocupada  = noche de una reserva CONFIRMADA o COMPLETADA
--                      (pendientes y canceladas no ocupan la habitacion).
--   * Ingreso por hospedaje = valor de las noches de reservas COMPLETADAS.
--   * La noche del check-out no se cobra ni se cuenta como ocupada.
--   * Estadias que cruzan temporadas: cada noche se cobra con la tarifa de SU
--     temporada. Las noches de una linea dentro de una temporada se calculan asi:
--         LEAST(check_out, fecha_fin + 1) - GREATEST(check_in, fecha_inicio)
--     (cantidad de dias en comun entre la estadia y la temporada).
-- =====================================================================

-- =====================================================================
-- CONSULTA 1 · Ocupacion por municipio y mes  (PIVOT)
-- Pregunta: ¿que porcentaje de las noches-habitacion disponibles se
-- ocupo en cada municipio, mes a mes, durante 2025?
-- Ocupacion % = noches ocupadas / (habitaciones del municipio x dias del mes).
-- Una estadia que cruza de un mes a otro reparte sus noches entre ambos
-- (se cruza cada linea con una lista de los 12 meses de 2025).
-- El PIVOT convierte los 12 meses en columnas.
-- =====================================================================
SELECT municipio,
       NVL(ene, 0) AS ene, NVL(feb, 0) AS feb, NVL(mar, 0) AS mar, NVL(abr, 0) AS abr,
       NVL(may, 0) AS may, NVL(jun, 0) AS jun, NVL(jul, 0) AS jul, NVL(ago, 0) AS ago,
       NVL(sep, 0) AS sep, NVL(oct, 0) AS oct, NVL(nov, 0) AS nov, NVL(dic, 0) AS dic
FROM (
  SELECT m.nombre AS municipio,
         EXTRACT(MONTH FROM o.mes) AS mes,
         ROUND(100 * o.noches_ocupadas / (cap.habitaciones * EXTRACT(DAY FROM LAST_DAY(o.mes))), 1) AS ocupacion_pct
  FROM (SELECT a.id_municipio,
               ms.mes,
               SUM(LEAST(rh.check_out, ADD_MONTHS(ms.mes, 1)) - GREATEST(rh.check_in, ms.mes)) AS noches_ocupadas
        FROM   reserva_habitacion rh
        JOIN   reserva r     ON r.id_reserva = rh.id_reserva
        JOIN   alojamiento a ON a.id_alojamiento = rh.id_alojamiento
        JOIN   (SELECT ADD_MONTHS(DATE '2025-01-01', LEVEL - 1) AS mes
                FROM dual CONNECT BY LEVEL <= 12) ms
               ON rh.check_in < ADD_MONTHS(ms.mes, 1) AND rh.check_out > ms.mes
        WHERE  r.estado IN ('CONFIRMADA', 'COMPLETADA')
        GROUP  BY a.id_municipio, ms.mes) o
  JOIN (SELECT a.id_municipio, COUNT(*) AS habitaciones
        FROM   habitacion h
        JOIN   alojamiento a ON a.id_alojamiento = h.id_alojamiento
        GROUP  BY a.id_municipio) cap ON cap.id_municipio = o.id_municipio
  JOIN municipio m ON m.id_municipio = o.id_municipio
)
PIVOT (MAX(ocupacion_pct) FOR mes IN (1 AS ene, 2 AS feb, 3 AS mar, 4 AS abr, 5 AS may, 6 AS jun,
                                      7 AS jul, 8 AS ago, 9 AS sep, 10 AS oct, 11 AS nov, 12 AS dic))
ORDER BY municipio;

-- =====================================================================
-- CONSULTA 2 · Ingresos por municipio, tipo de alojamiento y temporada
--              (CUBE + GROUPING)
-- Pregunta: ¿cuanto ingresa cada combinacion municipio / tipo / nivel de
-- temporada, y cuales son los subtotales y el total general?
-- Cada linea de reserva se cruza con las temporadas que toca y se cobran
-- sus noches con la tarifa de esa temporada (tabla TARIFA).
-- CUBE genera todas las combinaciones de agrupacion; GROUPING(x) vale 1
-- cuando la columna x fue "colapsada" en ese subtotal, lo que permite
-- distinguir un subtotal de un valor NULL real y rotularlo.
-- =====================================================================
SELECT CASE WHEN GROUPING(m.nombre)  = 1 THEN '** TODOS **' ELSE m.nombre  END AS municipio,
       CASE WHEN GROUPING(tp.nombre) = 1 THEN '** TODOS **' ELSE tp.nombre END AS tipo,
       CASE WHEN GROUPING(t.nivel)   = 1 THEN '** TODAS **' ELSE t.nivel   END AS temporada,
       SUM(LEAST(rh.check_out, t.fecha_fin + 1) - GREATEST(rh.check_in, t.fecha_inicio)) AS noches_vendidas,
       SUM((LEAST(rh.check_out, t.fecha_fin + 1) - GREATEST(rh.check_in, t.fecha_inicio)) * tf.valor_noche) AS ingresos_hospedaje,
       GROUPING(m.nombre)  AS g_municipio,
       GROUPING(tp.nombre) AS g_tipo,
       GROUPING(t.nivel)   AS g_temporada
FROM   reserva_habitacion rh
JOIN   reserva r            ON r.id_reserva = rh.id_reserva
JOIN   alojamiento a        ON a.id_alojamiento = rh.id_alojamiento
JOIN   municipio m          ON m.id_municipio = a.id_municipio
JOIN   tipo_alojamiento tp  ON tp.id_tipo = a.id_tipo
JOIN   temporada t          ON rh.check_in <= t.fecha_fin AND rh.check_out > t.fecha_inicio
JOIN   tarifa tf            ON tf.id_habitacion = rh.id_habitacion AND tf.id_temporada = t.id_temporada
WHERE  r.estado = 'COMPLETADA'
GROUP  BY CUBE (m.nombre, tp.nombre, t.nivel)
ORDER  BY GROUPING(m.nombre), m.nombre,
          GROUPING(tp.nombre), tp.nombre,
          GROUPING(t.nivel), DECODE(t.nivel, 'ALTA', 1, 'MEDIA', 2, 'BAJA', 3);

-- =====================================================================
-- CONSULTA 3 · Los 3 alojamientos de mayor ingreso dentro de cada
--              municipio  (RANK ... PARTITION BY)
-- Pregunta: ¿cuales son los 3 alojamientos mas rentables de cada municipio?
-- Ingreso = hospedaje (valor_estadia) + servicios de las reservas COMPLETADAS.
-- RANK() reinicia la posicion en cada municipio (PARTITION BY) y respeta
-- empates. Los municipios con menos de 3 alojamientos muestran los que tienen.
-- Los ingresos se suman por separado (hospedaje y servicios) y luego se
-- unen, para no duplicar montos al combinar tablas de detalle.
-- =====================================================================
WITH hosp AS (
  SELECT rh.id_alojamiento, SUM(rh.valor_estadia) AS ingreso_hospedaje
  FROM   reserva_habitacion rh
  JOIN   reserva r ON r.id_reserva = rh.id_reserva
  WHERE  r.estado = 'COMPLETADA'
  GROUP  BY rh.id_alojamiento
), serv AS (
  SELECT rs.id_alojamiento, SUM(rs.cantidad * rs.precio_unitario) AS ingreso_servicios
  FROM   reserva_servicio rs
  JOIN   reserva r ON r.id_reserva = rs.id_reserva
  WHERE  r.estado = 'COMPLETADA'
  GROUP  BY rs.id_alojamiento
), total AS (
  SELECT a.id_alojamiento, a.id_municipio, a.id_tipo, a.nombre_comercial,
         NVL(h.ingreso_hospedaje, 0)                               AS ingreso_hospedaje,
         NVL(s.ingreso_servicios, 0)                               AS ingreso_servicios,
         NVL(h.ingreso_hospedaje, 0) + NVL(s.ingreso_servicios, 0) AS ingreso_total
  FROM   alojamiento a
  LEFT   JOIN hosp h ON h.id_alojamiento = a.id_alojamiento
  LEFT   JOIN serv s ON s.id_alojamiento = a.id_alojamiento
), ranking AS (
  SELECT t.*,
         RANK() OVER (PARTITION BY t.id_municipio ORDER BY t.ingreso_total DESC) AS posicion
  FROM   total t
)
SELECT m.nombre AS municipio,
       r.posicion,
       r.nombre_comercial AS alojamiento,
       tp.nombre AS tipo,
       r.ingreso_hospedaje,
       r.ingreso_servicios,
       r.ingreso_total
FROM   ranking r
JOIN   tipo_alojamiento tp ON tp.id_tipo = r.id_tipo
JOIN   municipio m         ON m.id_municipio = r.id_municipio
WHERE  r.posicion <= 3
ORDER  BY m.nombre, r.posicion, r.nombre_comercial;

-- =====================================================================
-- CONSULTA 4 · Variacion de ingresos mes contra mes  (LAG)
-- Pregunta: ¿cuanto crecen o caen los ingresos de la plataforma de un mes
-- al siguiente?
-- Ingreso del mes = pagos EXITOSOS menos REEMBOLSOS, segun la fecha del pago
-- (ingreso de caja).
-- LAG(ingresos) OVER (ORDER BY mes) trae el ingreso del mes anterior a la
-- fila actual; con el se calcula la variacion absoluta y porcentual.
-- El primer mes no tiene mes anterior (queda NULL).
-- =====================================================================
WITH mensual AS (
  SELECT TRUNC(fecha_pago, 'MM') AS mes,
         SUM(CASE estado WHEN 'EXITOSO' THEN monto WHEN 'REEMBOLSADO' THEN -monto END) AS ingresos
  FROM   pago
  WHERE  estado IN ('EXITOSO', 'REEMBOLSADO')
  GROUP  BY TRUNC(fecha_pago, 'MM')
)
SELECT TO_CHAR(mes, 'YYYY-MM')                               AS periodo,
       ingresos,
       LAG(ingresos) OVER (ORDER BY mes)                     AS ingresos_mes_anterior,
       ingresos - LAG(ingresos) OVER (ORDER BY mes)          AS variacion_abs,
       ROUND(100 * (ingresos - LAG(ingresos) OVER (ORDER BY mes))
                 / NULLIF(LAG(ingresos) OVER (ORDER BY mes), 0), 1) AS variacion_pct
FROM   mensual
ORDER  BY mes;

-- =====================================================================
-- CONSULTA 5 · Consulta PARAMETRIZADA con variables de enlace (rango de fechas)
-- Pregunta: dado un rango de fechas (:f_desde, :f_hasta), ¿cuantas reservas
-- con check-in en ese rango se completaron y cuanto ingreso de hospedaje
-- generaron, por municipio?
-- Uso:  SQL*Plus / SQL Developer (F5): se declaran y asignan las variables
--       aqui abajo.  Con F9 SQL Developer pide los valores en un dialogo
--       (en ese caso escribir fechas como 2025-12-15, sin comillas).
-- =====================================================================
VARIABLE f_desde VARCHAR2(10)
VARIABLE f_hasta VARCHAR2(10)
EXEC :f_desde := '2025-12-15'
EXEC :f_hasta := '2026-01-10'

SELECT m.nombre                              AS municipio,
       COUNT(DISTINCT rh.id_reserva)         AS reservas,
       COUNT(*)                              AS habitaciones_reservadas,
       SUM(rh.valor_estadia)                 AS ingresos_hospedaje,
       ROUND(AVG(rh.valor_estadia))          AS valor_promedio_por_habitacion
FROM   reserva_habitacion rh
JOIN   reserva r     ON r.id_reserva = rh.id_reserva
JOIN   alojamiento a ON a.id_alojamiento = rh.id_alojamiento
JOIN   municipio m   ON m.id_municipio = a.id_municipio
WHERE  r.estado = 'COMPLETADA'
  AND  rh.check_in BETWEEN TO_DATE(:f_desde, 'YYYY-MM-DD') AND TO_DATE(:f_hasta, 'YYYY-MM-DD')
GROUP  BY m.nombre
ORDER  BY ingresos_hospedaje DESC;

-- Segunda ejecucion con otro rango (mitad de ano 2025) para comprobar que cambia solo el parametro:
EXEC :f_desde := '2025-06-15'
EXEC :f_hasta := '2025-07-15'

SELECT m.nombre                              AS municipio,
       COUNT(DISTINCT rh.id_reserva)         AS reservas,
       COUNT(*)                              AS habitaciones_reservadas,
       SUM(rh.valor_estadia)                 AS ingresos_hospedaje,
       ROUND(AVG(rh.valor_estadia))          AS valor_promedio_por_habitacion
FROM   reserva_habitacion rh
JOIN   reserva r     ON r.id_reserva = rh.id_reserva
JOIN   alojamiento a ON a.id_alojamiento = rh.id_alojamiento
JOIN   municipio m   ON m.id_municipio = a.id_municipio
WHERE  r.estado = 'COMPLETADA'
  AND  rh.check_in BETWEEN TO_DATE(:f_desde, 'YYYY-MM-DD') AND TO_DATE(:f_hasta, 'YYYY-MM-DD')
GROUP  BY m.nombre
ORDER  BY ingresos_hospedaje DESC;

-- =====================================================================
-- CONSULTA 6 · UNPIVOT
-- Pregunta: ¿cual es la tarifa promedio por noche de cada tipo de
-- alojamiento en temporada alta, media y baja durante 2025, en formato
-- "largo" (una fila por tipo y temporada) listo para graficar?
-- La subconsulta produce una tabla ANCHA (una columna por nivel de
-- temporada) con agregacion condicional; UNPIVOT la vuelve a filas.
-- =====================================================================
SELECT tipo, temporada, tarifa_promedio
FROM (
  SELECT ta.nombre AS tipo,
         ROUND(AVG(CASE WHEN t.nivel = 'ALTA'  THEN tf.valor_noche END)) AS alta,
         ROUND(AVG(CASE WHEN t.nivel = 'MEDIA' THEN tf.valor_noche END)) AS media,
         ROUND(AVG(CASE WHEN t.nivel = 'BAJA'  THEN tf.valor_noche END)) AS baja
  FROM   tarifa tf
  JOIN   temporada t         ON t.id_temporada   = tf.id_temporada
  JOIN   habitacion h        ON h.id_habitacion  = tf.id_habitacion
  JOIN   alojamiento a       ON a.id_alojamiento = h.id_alojamiento
  JOIN   tipo_alojamiento ta ON ta.id_tipo       = a.id_tipo
  WHERE  t.anio = 2025
  GROUP  BY ta.nombre
)
UNPIVOT (tarifa_promedio FOR temporada IN (alta AS 'ALTA', media AS 'MEDIA', baja AS 'BAJA'))
ORDER  BY tipo, DECODE(temporada, 'ALTA', 1, 'MEDIA', 2, 3);

-- =====================================================================
-- CONSULTA 7 · Consulta libre de negocio
-- Pregunta propuesta: ¿que alojamientos "se venden" con mas estrellas de
-- las que sus huespedes reconocen?
-- Las estrellas las autoasigna el alojamiento (sin verificacion); la
-- calificacion real sale de las resenas de estadias completadas. Se
-- listan los 15 alojamientos con mayor brecha (estrellas - promedio),
-- con al menos 10 resenas para que el promedio sea confiable. Sirve a
-- la gerencia para auditar alojamientos y corregir su publicacion.
-- =====================================================================
SELECT a.nombre_comercial                        AS alojamiento,
       m.nombre                                  AS municipio,
       ta.nombre                                 AS tipo,
       a.estrellas                               AS estrellas_declaradas,
       COUNT(rs.id_resena)                       AS num_resenas,
       ROUND(AVG(rs.calificacion), 2)            AS calificacion_promedio,
       ROUND(a.estrellas - AVG(rs.calificacion), 2) AS brecha
FROM   alojamiento a
JOIN   municipio m         ON m.id_municipio = a.id_municipio
JOIN   tipo_alojamiento ta ON ta.id_tipo     = a.id_tipo
JOIN   reserva r           ON r.id_alojamiento = a.id_alojamiento
JOIN   resena rs           ON rs.id_reserva  = r.id_reserva
GROUP  BY a.id_alojamiento, a.nombre_comercial, m.nombre, ta.nombre, a.estrellas
HAVING COUNT(rs.id_resena) >= 10
ORDER  BY brecha DESC, num_resenas DESC
FETCH FIRST 15 ROWS ONLY;