-- ==============================================================================
-- ENTREGA 3 - SCRIPT 1: TRANSACCIONES (RESERVA + PAGO ATOMICO CON SAVEPOINT)
-- Proyecto Integrador Bases de Datos II - TurismoUQ
-- ------------------------------------------------------------------------------
-- Que hace este script:
--   1. Crea el procedimiento SP_RESERVAR_Y_PAGAR, que registra la reserva y su pago
--      en UNA sola transaccion: o se guarda todo, o no se guarda nada.
--   2. hacemos 5 pruebas distintas para tener la evidencia del rollback parcial
--      y del rollback total.
--
--
-- Por que no llamamos a PKG_TURISMOUQ.sp_crear_reserva:
--   Ese procedimiento hace COMMIT al final. Si lo llamabamos desde otro procedimiento, la
--   reserva quedaba guardada antes de que se hiciera el pago y ya no habria forma de deshacerla.
--   Por eso aqui repetimos las validaciones y dejamos UN SOLO commit, al final de todo.
--  
-- Los 3 puntos de regreso (SAVEPOINT) que usa el procedimiento:
--   sp_inicio        -> antes de tocar nada. Si falla la reserva o el pago, volvemos aqui
--                       y no queda NADA (rollback total).
--   sp_reserva_lista -> justo despues de insertar la reserva. Si falla solo el servicio
--                       extra, volvemos aqui y se pierde SOLO el servicio (rollback parcial):
--                       la reserva se conserva y el pago se hace igual.
--
-- Errores propios (RAISE_APPLICATION_ERROR). Los -20001 al -20007 son los mismos de la
-- Entrega 2 y se agregan dos nuevos:
--   -20001  habitacion no disponible (se cruza con otra reserva)
--   -20002  fechas malas (checkout <= checkin, o mas de 30 noches)
--   -20003  capacidad excedida
--   -20005  la habitacion o el alojamiento no existen
--   -20007  el check-in esta en el pasado
--   -20011  monto de pago invalido (vacio, cero, negativo o mayor que el total)
--   -20012  los servicios extra cuestan mas que el hospedaje (se deshace SOLO el servicio)
-- ==============================================================================
SET SERVEROUTPUT ON;


-- ==============================================================================
-- 1. EL PROCEDIMIENTO
-- ==============================================================================
CREATE OR REPLACE PROCEDURE sp_reservar_y_pagar (
    p_id_cliente         IN  NUMBER,
    p_id_alojamiento     IN  NUMBER,
    p_id_habitacion      IN  NUMBER,
    p_check_in           IN  DATE,
    p_check_out          IN  DATE,
    p_num_huespedes      IN  NUMBER,
    p_metodo_pago        IN  VARCHAR2,   -- TARJETA_CREDITO, TARJETA_DEBITO, PSE, TRANSFERENCIA o EFECTIVO
    p_monto_pago         IN  NUMBER,     -- lo que paga ahora (anticipo o el total)
    p_id_servicio        IN  NUMBER,     -- servicio extra opcional (si no hay, mandar NULL)
    p_cantidad_servicio  IN  NUMBER,     -- cuantas unidades del servicio
    p_id_reserva         OUT NUMBER,     -- id de la reserva creada
    p_id_pago            OUT NUMBER      -- id del pago creado
) IS
    v_capacidad   NUMBER(2);     -- cuantas personas caben en la habitacion
    v_solapes     NUMBER;        -- reservas que se cruzan con las fechas pedidas
    v_valor       NUMBER(12);    -- valor del hospedaje (noche por noche)
    v_precio_serv NUMBER(10);    -- precio unitario del servicio extra
    v_total_serv  NUMBER(14) := 0;   -- lo que suman los servicios extra
    v_total       NUMBER(14);    -- hospedaje + servicios
BEGIN
    -- Punto de regreso 1: antes de tocar cualquier tabla
    SAVEPOINT sp_inicio;

    -- ---- Paso 1: validamos las fechas ----
    IF p_check_out <= p_check_in THEN
        RAISE_APPLICATION_ERROR(-20002, 'Error fechas: CHECK_OUT debe ser mayor a CHECK_IN');
    END IF;
    IF (p_check_out - p_check_in) > 30 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Error fechas: Maximo 30 noches por habitacion');
    END IF;
    IF p_check_in < TRUNC(SYSDATE) THEN
        RAISE_APPLICATION_ERROR(-20007, 'Error fechas: CHECK_IN no puede estar en el pasado');
    END IF;

    -- ---- Paso 2: capacidad (y bloqueo de la habitacion) ----
    -- FOR UPDATE deja la fila de la habitacion bloqueada hasta el COMMIT o el ROLLBACK.
    -- Asi, si otra sesion intenta reservar la MISMA habitacion al tiempo, tiene que esperar
    -- (esto es lo que probamos en 09_concurrencia.sql).
    SELECT capacidad INTO v_capacidad
    FROM HABITACION
    WHERE id_habitacion = p_id_habitacion AND id_alojamiento = p_id_alojamiento
    FOR UPDATE;

    IF p_num_huespedes > v_capacidad THEN
        RAISE_APPLICATION_ERROR(-20003, 'Capacidad excedida. Capacidad habitacion: ' || v_capacidad
            || ', Solicitados: ' || p_num_huespedes);
    END IF;

    -- ---- Paso 3: disponibilidad ----
    -- Dos rangos se cruzan cuando: nuevo_in < viejo_out Y nuevo_out > viejo_in.
    -- Las reservas CANCELADAS no cuentan porque la habitacion quedo libre.
    SELECT COUNT(*) INTO v_solapes
    FROM RESERVA_HABITACION rh
    JOIN RESERVA r ON r.id_reserva = rh.id_reserva
    WHERE rh.id_habitacion = p_id_habitacion
      AND r.estado <> 'CANCELADA'
      AND p_check_in < rh.check_out
      AND p_check_out > rh.check_in;

    IF v_solapes > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Habitacion no disponible en ese rango de fechas.');
    END IF;

    -- ---- Paso 4: cuanto vale el hospedaje ----
    v_valor := PKG_TURISMOUQ.fn_valor_estadia(p_id_habitacion, p_check_in, p_check_out);

    -- ---- Paso 5: guardar la reserva (cabecera y detalle) SIN hacer commit ----
    INSERT INTO RESERVA (id_cliente, id_alojamiento, fecha_creacion, check_in, check_out, estado)
    VALUES (p_id_cliente, p_id_alojamiento, TRUNC(SYSDATE), p_check_in, p_check_out, 'PENDIENTE')
    RETURNING id_reserva INTO p_id_reserva;

    INSERT INTO RESERVA_HABITACION (id_reserva, id_alojamiento, id_habitacion, check_in, check_out,
                                    num_huespedes, valor_estadia)
    VALUES (p_id_reserva, p_id_alojamiento, p_id_habitacion, p_check_in, p_check_out,
            p_num_huespedes, v_valor);

    -- Punto de regreso 2: la reserva ya esta puesta. Lo que venga despues (el servicio extra)
    -- se puede deshacer sin perder la reserva.
    SAVEPOINT sp_reserva_lista;

    -- ---- Paso 6: servicio extra (opcional) ----
    IF p_id_servicio IS NOT NULL THEN
        BEGIN
            -- el servicio tiene que ser del mismo alojamiento de la reserva
            SELECT precio INTO v_precio_serv
            FROM SERVICIO
            WHERE id_servicio = p_id_servicio AND id_alojamiento = p_id_alojamiento;

            INSERT INTO RESERVA_SERVICIO (id_reserva, id_alojamiento, id_servicio, fecha_servicio,
                                          cantidad, precio_unitario)
            VALUES (p_id_reserva, p_id_alojamiento, p_id_servicio, p_check_in,
                    p_cantidad_servicio, v_precio_serv);

            -- regla de este procedimiento: los servicios extra no pueden costar mas que el
            -- hospedaje (evita errores de digitacion como pedir 999 desayunos). Se revisa
            -- DESPUES de insertar, con lo que ya esta en la transaccion.
            SELECT NVL(SUM(cantidad * precio_unitario), 0) INTO v_total_serv
            FROM RESERVA_SERVICIO
            WHERE id_reserva = p_id_reserva;

            IF v_total_serv > v_valor THEN
                RAISE_APPLICATION_ERROR(-20012, 'Los servicios (' || v_total_serv
                    || ') superan el valor del hospedaje (' || v_valor || ')');
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                -- ROLLBACK PARCIAL: deshacemos solo el servicio, hasta sp_reserva_lista.
                -- La reserva y su habitacion siguen en la transaccion y el pago continua.
                ROLLBACK TO sp_reserva_lista;
                v_total_serv := 0;
                DBMS_OUTPUT.PUT_LINE('AVISO: el servicio no se agrego (' || SQLERRM
                    || '). Se sigue con la reserva sin servicio.');
        END;
    END IF;

    -- ---- Paso 7: el pago ----
    v_total := v_valor + v_total_serv;

    IF p_monto_pago IS NULL OR p_monto_pago <= 0 OR p_monto_pago > v_total THEN
        RAISE_APPLICATION_ERROR(-20011, 'Monto de pago invalido: ' || NVL(TO_CHAR(p_monto_pago), 'vacio')
            || ' (el total de la reserva es ' || v_total || ')');
    END IF;

    -- Si el metodo no es uno de los 5 permitidos, el CHECK de la tabla PAGO lo rechaza
    -- (ORA-02290) y el handler de abajo deshace TODO hasta sp_inicio.
    INSERT INTO PAGO (id_reserva, fecha_pago, monto, metodo, estado)
    VALUES (p_id_reserva, SYSDATE, p_monto_pago, p_metodo_pago, 'EXITOSO')
    RETURNING id_pago INTO p_id_pago;

    -- con un pago exitoso la reserva pasa de PENDIENTE a CONFIRMADA
    UPDATE RESERVA SET estado = 'CONFIRMADA' WHERE id_reserva = p_id_reserva;

    -- Todo salio bien: UN solo commit para reserva + servicio + pago
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('OK: reserva ' || p_id_reserva || ' confirmada. Hospedaje ' || v_valor
        || ', servicios ' || v_total_serv || ', pago ' || p_monto_pago);
EXCEPTION
    -- el SELECT de capacidad no encontro la habitacion con ese alojamiento
    WHEN NO_DATA_FOUND THEN
        ROLLBACK TO sp_inicio;
        RAISE_APPLICATION_ERROR(-20005, 'Habitacion o alojamiento no existe');
    -- ROLLBACK TOTAL: cualquier otro error (validaciones, pago, CHECK, trigger de solape...)
    -- deshace hasta sp_inicio, o sea, no queda ni reserva ni pago.
    WHEN OTHERS THEN
        ROLLBACK TO sp_inicio;
        RAISE;
END sp_reservar_y_pagar;
/


-- ==============================================================================
-- 2. PREPARACION DE LAS PRUEBAS
-- Busca 5 habitaciones distintas que esten libres del 29 al 31 de dic de 2026, con capacidad
-- para 2 y con servicios en su alojamiento. Cada prueba usa una habitacion diferente.
-- (Son fechas futuras porque el procedimiento no deja reservar fechas que ya pasaron.)
-- ==============================================================================
VARIABLE v_h1 NUMBER
VARIABLE v_a1 NUMBER
VARIABLE v_h2 NUMBER
VARIABLE v_a2 NUMBER
VARIABLE v_h3 NUMBER
VARIABLE v_a3 NUMBER
VARIABLE v_h4 NUMBER
VARIABLE v_a4 NUMBER
VARIABLE v_h5 NUMBER
VARIABLE v_a5 NUMBER
VARIABLE v_r1 NUMBER
VARIABLE v_r2 NUMBER
VARIABLE v_antes NUMBER

DECLARE
    TYPE t_num IS TABLE OF NUMBER;
    v_hab t_num;
    v_alo t_num;
BEGIN
    SELECT id_habitacion, id_alojamiento BULK COLLECT INTO v_hab, v_alo
    FROM (SELECT h.id_habitacion, h.id_alojamiento
          FROM HABITACION h
          WHERE h.capacidad >= 2
            AND EXISTS (SELECT 1 FROM SERVICIO s WHERE s.id_alojamiento = h.id_alojamiento)
            AND NOT EXISTS (SELECT 1 FROM RESERVA_HABITACION rh JOIN RESERVA r ON r.id_reserva = rh.id_reserva
                            WHERE rh.id_habitacion = h.id_habitacion AND r.estado <> 'CANCELADA'
                              AND DATE '2026-12-29' < rh.check_out AND DATE '2026-12-31' > rh.check_in)
          ORDER BY h.id_habitacion)
    WHERE ROWNUM <= 5;

    :v_h1 := v_hab(1); :v_a1 := v_alo(1);
    :v_h2 := v_hab(2); :v_a2 := v_alo(2);
    :v_h3 := v_hab(3); :v_a3 := v_alo(3);
    :v_h4 := v_hab(4); :v_a4 := v_alo(4);
    :v_h5 := v_hab(5); :v_a5 := v_alo(5);
    DBMS_OUTPUT.PUT_LINE('Habitaciones de prueba: ' || :v_h1 || ', ' || :v_h2 || ', ' || :v_h3
        || ', ' || :v_h4 || ', ' || :v_h5);
END;
/


-- ==============================================================================
-- PRUEBA A:
-- Reservamos del 29 al 31 de dic con tarjeta de credito, un servicio (el mas barato del
-- alojamiento) y pagando el 50 % del hospedaje como anticipo.
-- ==============================================================================
DECLARE
    v_serv  NUMBER;
    v_valor NUMBER;
    v_pago  NUMBER;
BEGIN
    SELECT id_servicio INTO v_serv FROM SERVICIO WHERE id_alojamiento = :v_a1
    ORDER BY precio FETCH FIRST 1 ROW ONLY;
    v_valor := PKG_TURISMOUQ.fn_valor_estadia(:v_h1, DATE '2026-12-29', DATE '2026-12-31');
    sp_reservar_y_pagar(1, :v_a1, :v_h1, DATE '2026-12-29', DATE '2026-12-31', 2,
                        'TARJETA_CREDITO', ROUND(v_valor / 2), v_serv, 1, :v_r1, v_pago);
END;
/

SELECT r.id_reserva, r.estado, rh.valor_estadia,
       (SELECT COUNT(*) FROM PAGO p WHERE p.id_reserva = r.id_reserva) AS pagos,
       (SELECT NVL(SUM(p.monto), 0) FROM PAGO p WHERE p.id_reserva = r.id_reserva) AS total_pagado,
       (SELECT COUNT(*) FROM RESERVA_SERVICIO rs WHERE rs.id_reserva = r.id_reserva) AS servicios
FROM RESERVA r JOIN RESERVA_HABITACION rh ON rh.id_reserva = r.id_reserva
WHERE r.id_reserva = :v_r1;
-- RESULTADO ESPERADO: estado CONFIRMADA, pagos = 1, servicios = 1.


-- ==============================================================================
-- PRUEBA B: ROLLBACK PARCIAL (falla el servicio, pero la reserva y el pago se salvan)
-- Pedimos 999 unidades del servicio: el servicio se inserta, pero la regla dice que no puede
-- costar mas que el hospedaje. El procedimiento hace ROLLBACK TO sp_reserva_lista, o sea,
-- deshace SOLO el servicio, y sigue con el pago.
-- RESULTADO ESPERADO: sale el AVISO del servicio y despues el mensaje OK.
-- ==============================================================================
DECLARE
    v_serv  NUMBER;
    v_valor NUMBER;
    v_pago  NUMBER;
BEGIN
    SELECT id_servicio INTO v_serv FROM SERVICIO WHERE id_alojamiento = :v_a2
    ORDER BY precio FETCH FIRST 1 ROW ONLY;
    v_valor := PKG_TURISMOUQ.fn_valor_estadia(:v_h2, DATE '2026-12-29', DATE '2026-12-31');
    sp_reservar_y_pagar(2, :v_a2, :v_h2, DATE '2026-12-29', DATE '2026-12-31', 2,
                        'PSE', ROUND(v_valor / 2), v_serv, 999, :v_r2, v_pago);
END;
/
SELECT r.id_reserva, r.estado, rh.valor_estadia,
       (SELECT COUNT(*) FROM PAGO p WHERE p.id_reserva = r.id_reserva) AS pagos,
       (SELECT NVL(SUM(p.monto), 0) FROM PAGO p WHERE p.id_reserva = r.id_reserva) AS total_pagado,
       (SELECT COUNT(*) FROM RESERVA_SERVICIO rs WHERE rs.id_reserva = r.id_reserva) AS servicios
FROM RESERVA r JOIN RESERVA_HABITACION rh ON rh.id_reserva = r.id_reserva
WHERE r.id_reserva = :v_r2;
-- RESULTADO ESPERADO: estado CONFIRMADA, pagos = 1 y servicios = 0
-- (la reserva y el pago se conservaron, el servicio se deshizo).


-- ==============================================================================
-- PRUEBA C: ROLLBACK TOTAL por metodo de pago invalido
-- La reserva se alcanza a insertar, pero el pago con 'BITCOIN' rompe el CHECK de PAGO.
-- El procedimiento hace ROLLBACK TO sp_inicio y no queda NADA.
-- RESULTADO ESPERADO: sale el error ORA-02290, la cantidad de reservas no cambia y la
-- habitacion queda libre.
-- ==============================================================================
BEGIN
    SELECT COUNT(*) INTO :v_antes FROM RESERVA;
END;
/
DECLARE
    v_res  NUMBER;
    v_pago NUMBER;
BEGIN
    sp_reservar_y_pagar(3, :v_a3, :v_h3, DATE '2026-12-29', DATE '2026-12-31', 2,
                        'BITCOIN', 1000, NULL, NULL, v_res, v_pago);
EXCEPTION
    WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Error esperado (metodo invalido): ' || SQLERRM);
END;
/
SELECT :v_antes AS reservas_antes,
       (SELECT COUNT(*) FROM RESERVA) AS reservas_despues,
       (SELECT COUNT(*) FROM RESERVA_HABITACION
        WHERE id_habitacion = :v_h3 AND check_in = DATE '2026-12-29') AS lineas_en_la_habitacion
FROM DUAL;
-- RESULTADO ESPERADO: reservas_antes = reservas_despues y lineas_en_la_habitacion = 0.


-- ==============================================================================
-- PRUEBA D: ROLLBACK TOTAL por monto mayor al total
-- Intentamos pagar 10 veces el valor del hospedaje.
-- RESULTADO ESPERADO: sale el error -20011 y no queda reserva ni pago.
-- ==============================================================================
BEGIN
    SELECT COUNT(*) INTO :v_antes FROM RESERVA;
END;
/
DECLARE
    v_res   NUMBER;
    v_pago  NUMBER;
    v_valor NUMBER;
BEGIN
    v_valor := PKG_TURISMOUQ.fn_valor_estadia(:v_h4, DATE '2026-12-29', DATE '2026-12-31');
    sp_reservar_y_pagar(4, :v_a4, :v_h4, DATE '2026-12-29', DATE '2026-12-31', 2,
                        'EFECTIVO', v_valor * 10, NULL, NULL, v_res, v_pago);
EXCEPTION
    WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Error esperado -20011: ' || SQLERRM);
END;
/
SELECT :v_antes AS reservas_antes,
       (SELECT COUNT(*) FROM RESERVA) AS reservas_despues,
       (SELECT COUNT(*) FROM RESERVA_HABITACION
        WHERE id_habitacion = :v_h4 AND check_in = DATE '2026-12-29') AS lineas_en_la_habitacion
FROM DUAL;
-- RESULTADO ESPERADO: reservas_antes = reservas_despues y lineas_en_la_habitacion = 0.


-- ==============================================================================
-- PRUEBA E: el SAVEPOINT paso a paso (demostracion manual del rollback parcial)
-- Aqui no usamos el procedimiento. Hacemos a mano lo mismo para poder contar las filas en
-- cada momento: insertamos la reserva, ponemos un SAVEPOINT, insertamos un pago, volvemos al
-- SAVEPOINT (el pago desaparece pero la reserva sigue) y al final hacemos ROLLBACK de todo.
-- RESULTADO ESPERADO (en la salida):
--   1) reservas: 1
--   2) pagos: 1
--   3) pagos: 0 y reservas: 1   <- rollback parcial
--   4) reservas: 0              <- rollback total
-- ==============================================================================
DECLARE
    v_res  NUMBER;
    v_cont NUMBER;
BEGIN
    INSERT INTO RESERVA (id_cliente, id_alojamiento, fecha_creacion, check_in, check_out, estado)
    VALUES (5, :v_a5, TRUNC(SYSDATE), DATE '2026-12-29', DATE '2026-12-31', 'PENDIENTE')
    RETURNING id_reserva INTO v_res;

    INSERT INTO RESERVA_HABITACION (id_reserva, id_alojamiento, id_habitacion, check_in, check_out,
                                    num_huespedes, valor_estadia)
    VALUES (v_res, :v_a5, :v_h5, DATE '2026-12-29', DATE '2026-12-31', 2, 100000);

    SELECT COUNT(*) INTO v_cont FROM RESERVA WHERE id_reserva = v_res;
    DBMS_OUTPUT.PUT_LINE('1) Despues de insertar la reserva -> reservas: ' || v_cont);

    SAVEPOINT sp_demo;

    INSERT INTO PAGO (id_reserva, fecha_pago, monto, metodo, estado)
    VALUES (v_res, SYSDATE, 100000, 'PSE', 'EXITOSO');
    SELECT COUNT(*) INTO v_cont FROM PAGO WHERE id_reserva = v_res;
    DBMS_OUTPUT.PUT_LINE('2) Despues de insertar el pago    -> pagos: ' || v_cont);

    ROLLBACK TO sp_demo;   -- rollback PARCIAL: solo se deshace lo que paso despues del savepoint
    SELECT COUNT(*) INTO v_cont FROM PAGO WHERE id_reserva = v_res;
    DBMS_OUTPUT.PUT_LINE('3) Despues del ROLLBACK TO sp_demo -> pagos: ' || v_cont);
    SELECT COUNT(*) INTO v_cont FROM RESERVA WHERE id_reserva = v_res;
    DBMS_OUTPUT.PUT_LINE('   y la reserva sigue ahi        -> reservas: ' || v_cont);

    ROLLBACK;              -- rollback TOTAL: se deshace toda la transaccion
    SELECT COUNT(*) INTO v_cont FROM RESERVA WHERE id_reserva = v_res;
    DBMS_OUTPUT.PUT_LINE('4) Despues del ROLLBACK total     -> reservas: ' || v_cont);
END;
/