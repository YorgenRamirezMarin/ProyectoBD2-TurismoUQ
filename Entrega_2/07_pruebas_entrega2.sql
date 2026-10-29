-- ==============================================================================
-- ENTREGA 2 - SCRIPT 4: PRUEBAS
-- Proyecto Integrador Bases de Datos II - TurismoUQ
-- ------------------------------------------------------------------------------
-- Que hacemos en este script:
--   Probamos cada Script de la Entrega 2 y mostramos los resultados
--
-- Las fechas de las pruebas son de diciembre de 2026 (futuras), porque el procedimiento
-- no deja reservar fechas que ya pasaron.
-- ==============================================================================
SET SERVEROUTPUT ON;


-- ==============================================================================
-- PRUEBA 1: fn_valor_estadia cruzando dos temporadas
-- Estadia del 13 al 17 de dic de 2025 en la habitacion 1: las noches del 13 y el 14 son
-- de temporada MEDIA y las del 15 y el 16 son de temporada ALTA (la alta empieza el 15).
-- ==============================================================================
SELECT PKG_TURISMOUQ.fn_valor_estadia(1, DATE '2025-12-13', DATE '2025-12-17') AS valor_funcion FROM DUAL;

-- Calculo a mano para comparar: por cada temporada que toca la estadia, contamos cuantas noches
-- caen dentro y las multiplicamos por la tarifa de esa temporada.
SELECT t.nombre, t.nivel,
       LEAST(DATE '2025-12-17', t.fecha_fin + 1) - GREATEST(DATE '2025-12-13', t.fecha_inicio) AS noches,
       ta.valor_noche,
       (LEAST(DATE '2025-12-17', t.fecha_fin + 1) - GREATEST(DATE '2025-12-13', t.fecha_inicio)) * ta.valor_noche AS subtotal
FROM TEMPORADA t JOIN TARIFA ta ON ta.id_temporada = t.id_temporada
WHERE ta.id_habitacion = 1
  AND t.fecha_inicio < DATE '2025-12-17' AND t.fecha_fin >= DATE '2025-12-13';
-- RESULTADO ESPERADO: la suma de la columna SUBTOTAL es igual a VALOR_FUNCION.


-- ==============================================================================
-- PRUEBA 2: sp_crear_reserva funcionando bien
-- Primero busca una habitacion con capacidad para 2 que este libre del 20 al 23 de dic de 2026,
-- y despues crea la reserva. La habitacion queda guardada en las variables v_hab y v_aloj para
-- usarla en las pruebas siguientes.
-- ==============================================================================
VARIABLE v_hab NUMBER
VARIABLE v_aloj NUMBER
VARIABLE v_res NUMBER
BEGIN
  SELECT id_habitacion, id_alojamiento INTO :v_hab, :v_aloj
  FROM (SELECT h.id_habitacion, h.id_alojamiento
        FROM HABITACION h
        WHERE h.capacidad >= 2
          AND NOT EXISTS (SELECT 1 FROM RESERVA_HABITACION rh JOIN RESERVA r ON r.id_reserva = rh.id_reserva
                          WHERE rh.id_habitacion = h.id_habitacion AND r.estado <> 'CANCELADA'
                            AND DATE '2026-12-20' < rh.check_out AND DATE '2026-12-23' > rh.check_in)
        ORDER BY h.id_habitacion)
  WHERE ROWNUM = 1;
  PKG_TURISMOUQ.sp_crear_reserva(1, :v_aloj, :v_hab, DATE '2026-12-20', DATE '2026-12-23', 2, :v_res);
  DBMS_OUTPUT.PUT_LINE('Reserva creada: ' || :v_res || ' en la habitacion ' || :v_hab);
END;
/
-- Miramos como quedo guardada la reserva (estado PENDIENTE y con su valor calculado):
SELECT r.id_reserva, r.estado, rh.id_habitacion, rh.check_in, rh.check_out, rh.valor_estadia
FROM RESERVA r JOIN RESERVA_HABITACION rh ON rh.id_reserva = r.id_reserva
WHERE r.id_reserva = :v_res;
-- RESULTADO ESPERADO: una fila con estado PENDIENTE y valor_estadia mayor que 0.


-- ==============================================================================
-- PRUEBA 3: checkout anterior al checkin
-- RESULTADO ESPERADO: sale el mensaje "Error esperado -20002".
-- ==============================================================================
DECLARE v_id NUMBER; BEGIN
  PKG_TURISMOUQ.sp_crear_reserva(1, :v_aloj, :v_hab, DATE '2026-12-12', DATE '2026-12-10', 2, v_id);
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Error esperado -20002: ' || SQLERRM); END;
/


-- ==============================================================================
-- PRUEBA 4: capacidad excedida
-- Pedimos 5 huespedes mas de los que caben en la habitacion.
-- RESULTADO ESPERADO: sale el mensaje "Error esperado -20003".
-- ==============================================================================
DECLARE v_id NUMBER; v_cap NUMBER; BEGIN
  SELECT capacidad INTO v_cap FROM HABITACION WHERE id_habitacion = :v_hab;
  PKG_TURISMOUQ.sp_crear_reserva(1, :v_aloj, :v_hab, DATE '2026-12-26', DATE '2026-12-28', v_cap + 5, v_id);
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Error esperado -20003: ' || SQLERRM); END;
/


-- ==============================================================================
-- PRUEBA 5: habitacion no disponible
-- Intentamos reservar del 21 al 24 de dic la misma habitacion de la prueba 2 (que ya esta
-- tomada del 20 al 23): las fechas se cruzan.
-- RESULTADO ESPERADO: sale el mensaje "Error esperado -20001".
-- ==============================================================================
DECLARE v_id NUMBER; BEGIN
  PKG_TURISMOUQ.sp_crear_reserva(1, :v_aloj, :v_hab, DATE '2026-12-21', DATE '2026-12-24', 2, v_id);
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Error esperado -20001: ' || SQLERRM); END;
/


-- ==============================================================================
-- PRUEBA 5b: check-in en el pasado
-- RESULTADO ESPERADO: sale el mensaje "Error esperado -20007".
-- ==============================================================================
DECLARE v_id NUMBER; BEGIN
  PKG_TURISMOUQ.sp_crear_reserva(1, :v_aloj, :v_hab, DATE '2025-06-10', DATE '2025-06-12', 2, v_id);
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Error esperado -20007: ' || SQLERRM); END;
/


-- ==============================================================================
-- PRUEBA 5c: el TRIGGER de solape (caso real)
-- Aqui NO usamos el procedimiento: insertamos directo en RESERVA_HABITACION, para probar que
-- el trigger solo ya detiene el solape. Creamos una reserva y le metemos la misma habitacion
-- de la prueba 2 en fechas que se cruzan (22 al 25 de dic).
-- RESULTADO ESPERADO: sale "Error esperado -20001 (trigger)". Si sale "ERROR: el trigger no
-- detecto el solape", el trigger no esta funcionando.
-- ==============================================================================
DECLARE v_id NUMBER; BEGIN
  INSERT INTO RESERVA (id_cliente, id_alojamiento, fecha_creacion, check_in, check_out, estado)
  VALUES (2, :v_aloj, TRUNC(SYSDATE), DATE '2026-12-22', DATE '2026-12-25', 'PENDIENTE')
  RETURNING id_reserva INTO v_id;
  INSERT INTO RESERVA_HABITACION (id_reserva, id_alojamiento, id_habitacion, check_in, check_out, num_huespedes, valor_estadia)
  VALUES (v_id, :v_aloj, :v_hab, DATE '2026-12-22', DATE '2026-12-25', 1, 0);
  DBMS_OUTPUT.PUT_LINE('ERROR: el trigger no detecto el solape');
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Error esperado -20001 (trigger): ' || SQLERRM); END;
/
-- Deshacemos la reserva de prueba que se alcanzo a crear (la de la prueba 2 ya estaba guardada con COMMIT)
ROLLBACK;


-- ==============================================================================
-- PRUEBA 6: trigger de sentencia (auditoria de TARIFA)
-- Con UN solo UPDATE subimos 1000 pesos a 3 tarifas de la habitacion 1, y miramos la auditoria.
-- RESULTADO ESPERADO: 3 filas con nuestro usuario, la fecha, el valor anterior y el nuevo (+1000).
-- ==============================================================================
UPDATE TARIFA SET valor_noche = valor_noche + 1000 WHERE id_habitacion = 1 AND ROWNUM <= 3;
SELECT usuario, fecha_cambio, operacion, id_habitacion, id_temporada, valor_anterior, valor_nuevo
FROM AUDITORIA_TARIFA ORDER BY id_auditoria DESC FETCH FIRST 3 ROWS ONLY;
-- Deshacemos el cambio para no dejar las tarifas modificadas (tambien se deshace la auditoria)
ROLLBACK;


-- ==============================================================================
-- PRUEBA 7: liquidacion mensual (cursor con parametros)
-- Liquidamos diciembre de 2025 y miramos los 5 alojamientos que mas ganaron.
-- ==============================================================================
EXEC PKG_TURISMOUQ.sp_liquidacion_mensual(2025, 12);
SELECT * FROM LIQUIDACION_MENSUAL WHERE anio = 2025 AND mes = 12 ORDER BY total_liquidacion DESC FETCH FIRST 5 ROWS ONLY;

-- Comprobacion: la suma de hospedaje de la liquidacion debe ser igual a la que sale
-- consultando las tablas directamente.
-- RESULTADO ESPERADO: los dos numeros son iguales.
SELECT (SELECT SUM(ingresos_hospedaje) FROM LIQUIDACION_MENSUAL WHERE anio = 2025 AND mes = 12) AS hospedaje_liquidacion,
       (SELECT SUM(rh.valor_estadia) FROM RESERVA r JOIN RESERVA_HABITACION rh ON rh.id_reserva = r.id_reserva
        WHERE r.estado IN ('CONFIRMADA','COMPLETADA') AND r.check_in >= DATE '2025-12-01' AND r.check_in < DATE '2026-01-01') AS hospedaje_directo
FROM DUAL;


-- ==============================================================================
-- PRUEBA 8: vista materializada
-- Miramos las filas de diciembre de 2025 y despues la refrescamos a mano.
-- Nota: la reserva de la prueba 2 (dic 2026, PENDIENTE) no aparece porque la vista solo cuenta
-- reservas CONFIRMADAS o COMPLETADAS.
-- ==============================================================================
SELECT * FROM MV_OCUPACION_MENSUAL WHERE anio = 2025 AND mes = 12 ORDER BY noches_ocupadas DESC FETCH FIRST 5 ROWS ONLY;
EXEC DBMS_MVIEW.REFRESH('MV_OCUPACION_MENSUAL','C');