-- ==============================================================================
-- SCRIPT DDL: SISTEMA DE RESERVAS TURISMOUQ
-- ==============================================================================

-- 1. MUNICIPIO
-- Almacena los 12 municipios del Quindío.
CREATE TABLE MUNICIPIO (
    id_municipio NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR2(100) NOT NULL UNIQUE
);

-- 2. TIPO_ALOJAMIENTO
-- Clasifica los alojamientos (finca cafetera, hotel, glamping, etc.).
CREATE TABLE TIPO_ALOJAMIENTO (
    id_tipo NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR2(50) NOT NULL UNIQUE
);

-- 3. TEMPORADA
-- Define los rangos de fechas de las diferentes temporadas anuales (alta, media, baja).
CREATE TABLE TEMPORADA (
    id_temporada NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR2(50) NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    CONSTRAINT chk_fechas_temporada CHECK (fecha_inicio < fecha_fin)
);

-- 4. ALOJAMIENTO
-- Registra los establecimientos turísticos que ofrecen habitaciones.
CREATE TABLE ALOJAMIENTO (
    id_alojamiento NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_municipio NUMBER NOT NULL,
    id_tipo NUMBER NOT NULL,
    nombre_comercial VARCHAR2(150) NOT NULL,
    direccion VARCHAR2(200) NOT NULL,
    estrellas NUMBER(1) CHECK (estrellas BETWEEN 1 AND 5),
    CONSTRAINT fk_aloj_municipio FOREIGN KEY (id_municipio) REFERENCES MUNICIPIO(id_municipio),
    CONSTRAINT fk_aloj_tipo FOREIGN KEY (id_tipo) REFERENCES TIPO_ALOJAMIENTO(id_tipo)
);

-- 5. HABITACION
-- Detalla los espacios disponibles dentro de cada alojamiento.
CREATE TABLE HABITACION (
    id_habitacion NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_alojamiento NUMBER NOT NULL,
    numero VARCHAR2(10) NOT NULL,
    tipo VARCHAR2(50) NOT NULL,
    capacidad_maxima NUMBER(2) NOT NULL CHECK (capacidad_maxima > 0),
    CONSTRAINT fk_hab_alojamiento FOREIGN KEY (id_alojamiento) REFERENCES ALOJAMIENTO(id_alojamiento),
    CONSTRAINT uk_habitacion_alojamiento UNIQUE (id_alojamiento, numero)
);

-- 6. TARIFA
-- Catálogo de precios según la combinación de habitación y temporada.
CREATE TABLE TARIFA (
    id_tarifa NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_habitacion NUMBER NOT NULL,
    id_temporada NUMBER NOT NULL,
    precio_noche NUMBER(12,2) NOT NULL CHECK (precio_noche > 0),
    CONSTRAINT fk_tarifa_habitacion FOREIGN KEY (id_habitacion) REFERENCES HABITACION(id_habitacion),
    CONSTRAINT fk_tarifa_temporada FOREIGN KEY (id_temporada) REFERENCES TEMPORADA(id_temporada),
    CONSTRAINT uk_tarifa_hab_temp UNIQUE (id_habitacion, id_temporada)
);

-- 7. CLIENTE
-- Registra los datos de los usuarios que realizan las reservas.
CREATE TABLE CLIENTE (
    id_cliente NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    documento VARCHAR2(20) NOT NULL UNIQUE,
    nombre VARCHAR2(150) NOT NULL,
    correo VARCHAR2(100) NOT NULL UNIQUE,
    telefono VARCHAR2(20),
    ciudad_origen VARCHAR2(100)
);

-- 8. RESERVA
-- Tabla cabecera para agrupar múltiples habitaciones y servicios bajo una misma transacción.
CREATE TABLE RESERVA (
    id_reserva NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_cliente NUMBER NOT NULL,
    estado VARCHAR2(20) DEFAULT 'pendiente' NOT NULL CHECK (estado IN ('pendiente', 'confirmada', 'cancelada', 'completada')),
    fecha_creacion DATE DEFAULT SYSDATE NOT NULL,
    CONSTRAINT fk_reserva_cliente FOREIGN KEY (id_cliente) REFERENCES CLIENTE(id_cliente)
);

-- 9. RESERVA_HABITACION
-- Resuelve la decisión de diseño de que un grupo grande pueda reservar varias habitaciones.
CREATE TABLE RESERVA_HABITACION (
    id_reserva_hab NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_reserva NUMBER NOT NULL,
    id_habitacion NUMBER NOT NULL,
    fecha_checkin DATE NOT NULL,
    fecha_checkout DATE NOT NULL,
    CONSTRAINT fk_reshab_reserva FOREIGN KEY (id_reserva) REFERENCES RESERVA(id_reserva),
    CONSTRAINT fk_reshab_habitacion FOREIGN KEY (id_habitacion) REFERENCES HABITACION(id_habitacion),
    CONSTRAINT chk_fechas_reserva CHECK (fecha_checkin < fecha_checkout)
);

-- 10. PAGO
-- Registra los diferentes abonos o la cancelación total de la reserva.
CREATE TABLE PAGO (
    id_pago NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_reserva NUMBER NOT NULL,
    fecha DATE DEFAULT SYSDATE NOT NULL,
    monto NUMBER(12,2) NOT NULL CHECK (monto > 0),
    metodo VARCHAR2(50) NOT NULL CHECK (metodo IN ('tarjeta de credito', 'tarjeta debito', 'PSE', 'transferencia', 'efectivo')),
    estado VARCHAR2(20) DEFAULT 'pendiente' NOT NULL CHECK (estado IN ('exitoso', 'fallido', 'pendiente', 'reembolsado')),
    CONSTRAINT fk_pago_reserva FOREIGN KEY (id_reserva) REFERENCES RESERVA(id_reserva)
);

-- 11. SERVICIO
-- Servicios complementarios ofrecidos por cada establecimiento turístico.
CREATE TABLE SERVICIO (
    id_servicio NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_alojamiento NUMBER NOT NULL,
    nombre VARCHAR2(100) NOT NULL,
    descripcion VARCHAR2(255),
    precio NUMBER(12,2) NOT NULL CHECK (precio >= 0),
    CONSTRAINT fk_servicio_alojamiento FOREIGN KEY (id_alojamiento) REFERENCES ALOJAMIENTO(id_alojamiento)
);

-- 12. RESERVA_SERVICIO
-- Tabla puente para la contratación de varios servicios (o varias unidades) en una sola reserva.
CREATE TABLE RESERVA_SERVICIO (
    id_reserva NUMBER NOT NULL,
    id_servicio NUMBER NOT NULL,
    cantidad NUMBER(3) DEFAULT 1 NOT NULL CHECK (cantidad > 0),
    PRIMARY KEY (id_reserva, id_servicio),
    CONSTRAINT fk_resserv_reserva FOREIGN KEY (id_reserva) REFERENCES RESERVA(id_reserva),
    CONSTRAINT fk_resserv_servicio FOREIGN KEY (id_servicio) REFERENCES SERVICIO(id_servicio)
);

-- 13. RESENA
-- Opiniones y calificaciones dadas por los clientes a los alojamientos tras una estadía completada.
CREATE TABLE RESENA (
    id_resena NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_cliente NUMBER NOT NULL,
    id_alojamiento NUMBER NOT NULL,
    calificacion NUMBER(1) NOT NULL CHECK (calificacion BETWEEN 1 AND 5),
    comentario CLOB,
    CONSTRAINT fk_resena_cliente FOREIGN KEY (id_cliente) REFERENCES CLIENTE(id_cliente),
    CONSTRAINT fk_resena_alojamiento FOREIGN KEY (id_alojamiento) REFERENCES ALOJAMIENTO(id_alojamiento)
);

-- 14. USUARIO_SISTEMA
-- Credenciales y roles para el personal interno de la plataforma (administradores o encargados).
CREATE TABLE USUARIO_SISTEMA (
    id_usuario NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_alojamiento NUMBER, 
    username VARCHAR2(50) NOT NULL UNIQUE,
    rol VARCHAR2(50) NOT NULL CHECK (rol IN ('administrador', 'encargado')),
    CONSTRAINT fk_usr_alojamiento FOREIGN KEY (id_alojamiento) REFERENCES ALOJAMIENTO(id_alojamiento)
);

COMMIT;