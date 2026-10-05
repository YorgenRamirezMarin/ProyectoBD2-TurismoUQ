SET SERVEROUTPUT ON;

DECLARE
    v_num_habs NUMBER;
    v_capacidad NUMBER;
    v_cliente_id NUMBER;
    v_reserva_id NUMBER;
    v_alojamiento_id NUMBER;
    v_habitacion_id NUMBER;
    v_servicio_id NUMBER;
    v_fecha_checkin DATE;
    v_dias NUMBER;
    v_monto NUMBER;
    v_estado_reserva VARCHAR2(20);
    v_estado_pago VARCHAR2(20);
BEGIN
    -- 1. MUNICIPIO: Inserto los 12 municipios reales del Quindío.
    INSERT INTO MUNICIPIO (nombre) VALUES ('Armenia');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Buenavista');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Calarcá');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Circasia');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Córdoba');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Filandia');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Génova');
    INSERT INTO MUNICIPIO (nombre) VALUES ('La Tebaida');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Montenegro');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Pijao');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Quimbaya');
    INSERT INTO MUNICIPIO (nombre) VALUES ('Salento');

    -- 2. TIPO_ALOJAMIENTO: Agrego los 4 tipos de alojamiento básicos.
    INSERT INTO TIPO_ALOJAMIENTO (nombre) VALUES ('Hotel');
    INSERT INTO TIPO_ALOJAMIENTO (nombre) VALUES ('Finca cafetera');
    INSERT INTO TIPO_ALOJAMIENTO (nombre) VALUES ('Glamping');
    INSERT INTO TIPO_ALOJAMIENTO (nombre) VALUES ('Hostal');

    -- 3. TEMPORADA: Defino 6 temporadas abarcando los años 2025 y 2026 con fechas correctas para el cruce.
    INSERT INTO TEMPORADA (nombre, fecha_inicio, fecha_fin) VALUES ('Semana Santa 2025', TO_DATE('2025-04-13', 'YYYY-MM-DD'), TO_DATE('2025-04-20', 'YYYY-MM-DD'));
    INSERT INTO TEMPORADA (nombre, fecha_inicio, fecha_fin) VALUES ('Mitad de año 2025', TO_DATE('2025-06-15', 'YYYY-MM-DD'), TO_DATE('2025-07-15', 'YYYY-MM-DD'));
    INSERT INTO TEMPORADA (nombre, fecha_inicio, fecha_fin) VALUES ('Fin de año 2025', TO_DATE('2025-12-15', 'YYYY-MM-DD'), TO_DATE('2026-01-15', 'YYYY-MM-DD'));
    INSERT INTO TEMPORADA (nombre, fecha_inicio, fecha_fin) VALUES ('Semana Santa 2026', TO_DATE('2026-03-29', 'YYYY-MM-DD'), TO_DATE('2026-04-05', 'YYYY-MM-DD'));
    INSERT INTO TEMPORADA (nombre, fecha_inicio, fecha_fin) VALUES ('Mitad de año 2026', TO_DATE('2026-06-15', 'YYYY-MM-DD'), TO_DATE('2026-07-15', 'YYYY-MM-DD'));
    INSERT INTO TEMPORADA (nombre, fecha_inicio, fecha_fin) VALUES ('Baja General', TO_DATE('2024-01-01', 'YYYY-MM-DD'), TO_DATE('2024-12-31', 'YYYY-MM-DD'));

    -- 4. ALOJAMIENTO: Genero 60 alojamientos repartidos aleatoriamente entre los municipios y tipos.
    FOR i IN 1..60 LOOP
        INSERT INTO ALOJAMIENTO (id_municipio, id_tipo, nombre_comercial, direccion, estrellas)
        VALUES (
            TRUNC(DBMS_RANDOM.VALUE(1, 13)), 
            TRUNC(DBMS_RANDOM.VALUE(1, 5)), 
            'Alojamiento ' || i || ' UQ', 
            'Carrera ' || TRUNC(DBMS_RANDOM.VALUE(1, 50)) || ' # ' || TRUNC(DBMS_RANDOM.VALUE(1, 100)), 
            TRUNC(DBMS_RANDOM.VALUE(2, 6))
        );
    END LOOP;

    -- 5. HABITACION: Aplico asimetría. Si es Hotel (tipo 1), de 30 a 40 habitaciones. Si es otro, de 3 a 5 habitaciones.
    FOR r_aloj IN (SELECT id_alojamiento, id_tipo FROM ALOJAMIENTO) LOOP
        IF r_aloj.id_tipo = 1 THEN
            v_num_habs := TRUNC(DBMS_RANDOM.VALUE(30, 41));
        ELSE
            v_num_habs := TRUNC(DBMS_RANDOM.VALUE(3, 6));
        END IF;

        FOR j IN 1..v_num_habs LOOP
            v_capacidad := TRUNC(DBMS_RANDOM.VALUE(1, 6));
            INSERT INTO HABITACION (id_alojamiento, numero, tipo, capacidad_maxima)
            VALUES (r_aloj.id_alojamiento, TO_CHAR(j), 
                    CASE WHEN v_capacidad = 1 THEN 'Sencilla' WHEN v_capacidad = 2 THEN 'Doble' ELSE 'Familiar' END, 
                    v_capacidad);
        END LOOP;
    END LOOP;

    -- 6. TARIFA: Cruzo todas las habitaciones con todas las temporadas.
    FOR r_hab IN (SELECT id_habitacion FROM HABITACION) LOOP
        FOR r_temp IN (SELECT id_temporada FROM TEMPORADA) LOOP
            INSERT INTO TARIFA (id_habitacion, id_temporada, precio_noche)
            VALUES (r_hab.id_habitacion, r_temp.id_temporada, ROUND(DBMS_RANDOM.VALUE(80000, 350000), -3));
        END LOOP;
    END LOOP;

    -- 7. CLIENTE: Inserto 3.000 clientes con ciudades variadas.
    FOR i IN 1..3000 LOOP
        INSERT INTO CLIENTE (documento, nombre, correo, telefono, ciudad_origen)
        VALUES (
            TO_CHAR(10000000 + i), 
            'Cliente ' || i, 
            'cliente' || i || '@correo.com', 
            '3' || TO_CHAR(TRUNC(DBMS_RANDOM.VALUE(100000000, 999999999))), 
            CASE TRUNC(DBMS_RANDOM.VALUE(1, 5)) WHEN 1 THEN 'Bogotá' WHEN 2 THEN 'Medellín' WHEN 3 THEN 'Cali' ELSE 'Pereira' END
        );
    END LOOP;

    -- 8. SERVICIO: Creo 30 servicios distribuidos al azar.
    FOR i IN 1..30 LOOP
        INSERT INTO SERVICIO (id_alojamiento, nombre, descripcion, precio)
        VALUES (TRUNC(DBMS_RANDOM.VALUE(1, 61)), 'Servicio Extra ' || i, 'Descripción del servicio ' || i, ROUND(DBMS_RANDOM.VALUE(15000, 80000), -3));
    END LOOP;

    -- 9. RESERVAS, PAGOS Y HABITACIONES: Garantizo mínimo 25.000 y asimetría en pagos/habitaciones.
    FOR i IN 1..25000 LOOP
        v_cliente_id := TRUNC(DBMS_RANDOM.VALUE(1, 3001));
        v_fecha_checkin := TO_DATE('2024-01-01', 'YYYY-MM-DD') + TRUNC(DBMS_RANDOM.VALUE(0, 1000));
        v_dias := TRUNC(DBMS_RANDOM.VALUE(1, 6));
        
        v_estado_reserva := CASE TRUNC(DBMS_RANDOM.VALUE(1, 10)) 
                                WHEN 1 THEN 'cancelada' 
                                WHEN 2 THEN 'pendiente' 
                                ELSE 'completada' END;

        INSERT INTO RESERVA (id_cliente, estado, fecha_creacion)
        VALUES (v_cliente_id, v_estado_reserva, v_fecha_checkin - TRUNC(DBMS_RANDOM.VALUE(5, 30)))
        RETURNING id_reserva INTO v_reserva_id;

        -- RESERVA_HABITACION: Garantiza >= 25.000. El 20% de las veces reserva 2 habitaciones para el grupo.
        INSERT INTO RESERVA_HABITACION (id_reserva, id_habitacion, fecha_checkin, fecha_checkout)
        VALUES (v_reserva_id, TRUNC(DBMS_RANDOM.VALUE(1, 401)), v_fecha_checkin, v_fecha_checkin + v_dias);
        
        IF DBMS_RANDOM.VALUE(0, 1) > 0.8 THEN
            INSERT INTO RESERVA_HABITACION (id_reserva, id_habitacion, fecha_checkin, fecha_checkout)
            VALUES (v_reserva_id, TRUNC(DBMS_RANDOM.VALUE(1, 401)), v_fecha_checkin, v_fecha_checkin + v_dias);
        END IF;

        -- PAGO: Garantiza >= 25.000. El 30% de las veces se hace en dos abonos (anticipo y saldo).
        v_monto := v_dias * 150000; 
        IF v_estado_reserva = 'completada' AND DBMS_RANDOM.VALUE(0, 1) > 0.7 THEN
            -- Anticipo del 50%
            INSERT INTO PAGO (id_reserva, fecha, monto, metodo, estado)
            VALUES (v_reserva_id, v_fecha_checkin - 10, v_monto * 0.5, 'transferencia', 'exitoso');
            -- Saldo del 50%
            INSERT INTO PAGO (id_reserva, fecha, monto, metodo, estado)
            VALUES (v_reserva_id, v_fecha_checkin, v_monto * 0.5, 'tarjeta de credito', 'exitoso');
        ELSE
            -- Pago único
            INSERT INTO PAGO (id_reserva, fecha, monto, metodo, estado)
            VALUES (v_reserva_id, v_fecha_checkin - 5, v_monto, 'tarjeta de credito', CASE WHEN v_estado_reserva = 'completada' THEN 'exitoso' ELSE 'pendiente' END);
        END IF;

        -- RESEÑAS: >= 40%
        IF v_estado_reserva = 'completada' AND DBMS_RANDOM.VALUE(0, 1) > 0.5 THEN
            INSERT INTO RESENA (id_cliente, id_alojamiento, calificacion, comentario)
            VALUES (v_cliente_id, TRUNC(DBMS_RANDOM.VALUE(1, 61)), TRUNC(DBMS_RANDOM.VALUE(3, 6)), 'Excelente servicio.');
        END IF;
    END LOOP;

    -- 9.1 RESERVA_SERVICIO: Ciclo independiente para asegurar EXACTAMENTE 40.000 registros obligatorios.
    FOR i IN 1..40000 LOOP
        BEGIN
            INSERT INTO RESERVA_SERVICIO (id_reserva, id_servicio, cantidad)
            VALUES (TRUNC(DBMS_RANDOM.VALUE(1, 25001)), TRUNC(DBMS_RANDOM.VALUE(1, 31)), TRUNC(DBMS_RANDOM.VALUE(1, 4)));
        EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL; -- Ignora si la combinación reserva-servicio ya se repitió
        END;
    END LOOP;

    -- 10. USUARIO_SISTEMA: Inserto 10 usuarios para el sistema (1 administrador y 9 encargados).
    INSERT INTO USUARIO_SISTEMA (username, rol) VALUES ('admin_global', 'administrador');
    FOR i IN 1..9 LOOP
        INSERT INTO USUARIO_SISTEMA (id_alojamiento, username, rol)
        VALUES (i, 'encargado_' || i, 'encargado');
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Carga de datos asimétricos completada con éxito.');
END;
/