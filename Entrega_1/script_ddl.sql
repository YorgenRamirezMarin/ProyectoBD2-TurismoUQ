--
-- Estrategia:
--   * Catalogos y datos "de diseno" (municipios, tipos, alojamientos,
--     temporadas, servicios, usuarios): INSERT explicito y determinista.
--   * Tablas grandes (habitaciones, tarifas, clientes, reservas, lineas,
--     servicios contratados, pagos, resenas): PL/SQL con DBMS_RANDOM.
--
-- Asimetria (para que ROLLUP/CUBE/PIVOT/RANK muestren algo):
--   * Municipios: Armenia 16 alojamientos y Genova/Cordoba 1 cada uno.
--   * Habitaciones: hoteles de Armenia con 25-40, fincas con 3-5.
--   * Demanda por temporada (alta >> media >> baja), por dia de la semana,
--     por anio (crece 2024 -> 2026) y por popularidad del alojamiento.
--   * Clientes: pocos clientes muy frecuentes y muchos ocasionales.
--   * Cada alojamiento tiene una calidad "real" (que guia las reseñas)
--     distinta de las estrellas que se autoasigna.

--  Restricciones que usamos:
--   PRIMARY KEY -> identifica cada fila de forma unica
--   FOREIGN KEY -> amarra una fila con la fila de otra tabla (integridad referencial)
--   NOT NULL    -> el dato es obligatorio
--   UNIQUE      -> el dato (o la combinacion de datos) no se puede repetir
--   CHECK       -> el dato solo puede tomar valores validos (rangos, listas, fechas)

-- Fecha de corte de los datos: 2026-09-29 (lo anterior son estadias
-- completadas/canceladas; lo posterior, reservas futuras).
-- =====================================================================
SET DEFINE OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD';

BEGIN
  DBMS_RANDOM.SEED(20260930);
END;
/

-- ---------------------------------------------------------------------
-- 1. MUNICIPIO (12) y TIPO_ALOJAMIENTO (5)
-- ---------------------------------------------------------------------
INSERT INTO municipio (id_municipio, nombre) VALUES (1, 'Armenia');
INSERT INTO municipio (id_municipio, nombre) VALUES (2, 'Buenavista');
INSERT INTO municipio (id_municipio, nombre) VALUES (3, 'Calarcá');
INSERT INTO municipio (id_municipio, nombre) VALUES (4, 'Circasia');
INSERT INTO municipio (id_municipio, nombre) VALUES (5, 'Córdoba');
INSERT INTO municipio (id_municipio, nombre) VALUES (6, 'Filandia');
INSERT INTO municipio (id_municipio, nombre) VALUES (7, 'Génova');
INSERT INTO municipio (id_municipio, nombre) VALUES (8, 'La Tebaida');
INSERT INTO municipio (id_municipio, nombre) VALUES (9, 'Montenegro');
INSERT INTO municipio (id_municipio, nombre) VALUES (10, 'Pijao');
INSERT INTO municipio (id_municipio, nombre) VALUES (11, 'Quimbaya');
INSERT INTO municipio (id_municipio, nombre) VALUES (12, 'Salento');
INSERT INTO tipo_alojamiento (id_tipo, nombre, descripcion) VALUES (1, 'Finca cafetera', 'Finca productora de cafe con alojamiento rural');
INSERT INTO tipo_alojamiento (id_tipo, nombre, descripcion) VALUES (2, 'Hotel', 'Hotel urbano o campestre con servicios completos');
INSERT INTO tipo_alojamiento (id_tipo, nombre, descripcion) VALUES (3, 'Glamping', 'Alojamiento en domos o carpas de lujo en la naturaleza');
INSERT INTO tipo_alojamiento (id_tipo, nombre, descripcion) VALUES (4, 'Hostal', 'Alojamiento economico con habitaciones y zonas comunes');
INSERT INTO tipo_alojamiento (id_tipo, nombre, descripcion) VALUES (5, 'Posada rural', 'Casa rural con pocas habitaciones y trato familiar');
COMMIT;

-- ---------------------------------------------------------------------
-- 2. ALOJAMIENTO (64) - repartidos de forma desigual entre municipios
-- ---------------------------------------------------------------------
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (1, 1, 2, 'Torre Cafetera', 'Calle 4 # 19-91, Armenia', 3, '3479600712', 'reservas@torrecafetera1.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (2, 1, 2, 'Palmares del Centro', 'Carrera 3 # 8-1, Armenia', 4, '3847881398', 'reservas@palmaresdelcentro2.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (3, 1, 2, 'Plaza Bolivar', 'Carrera 3 # 16-85, Armenia', 5, '3984408535', 'reservas@plazabolivar3.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (4, 1, 2, 'Cordillera Central', 'Carrera 30 # 27-36, Armenia', 3, '3570844104', 'reservas@cordilleracentral4.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (5, 1, 2, 'Los Yarumos', 'Carrera 24 # 1-6, Armenia', 5, '3380166696', 'reservas@losyarumos5.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (6, 1, 2, 'Bosque de Palma', 'Calle 38 # 21-48, Armenia', 4, '3550141798', 'reservas@bosquedepalma6.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (7, 1, 4, 'Hostal La Estacion', 'Calle 17 # 17-99, Armenia', 3, '3916725906', 'reservas@hostallaestacion7.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (8, 1, 4, 'Hostal Casa Vieja', 'Calle 33 # 8-2, Armenia', 5, '3380852668', 'reservas@hostalcasavieja8.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (9, 1, 4, 'Hostal Mochileros', 'Calle 8 # 15-93, Armenia', 5, '3999880768', 'reservas@hostalmochileros9.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (10, 1, 4, 'Hostal El Camino', 'Calle 31 # 1-62, Armenia', 5, '3552687381', 'reservas@hostalelcamino10.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (11, 1, 4, 'Hostal Parque Central', 'Carrera 11 # 8-75, Armenia', 3, '3207096798', 'reservas@hostalparquecentral11.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (12, 1, 3, 'Domos del Cocora', 'Vereda Los Andes, Armenia', 5, '3869423183', 'reservas@domosdelcocora12.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (13, 1, 1, 'La Esmeralda', 'Vereda San Antonio, Armenia', 3, '3342797389', 'reservas@laesmeralda13.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (14, 1, 1, 'El Guayabo', 'Vereda La Julia, Armenia', 4, '3558978581', 'reservas@elguayabo14.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (15, 1, 1, 'Hacienda Los Cafetos', 'Vereda San Antonio, Armenia', 4, '3183663902', 'reservas@haciendaloscafetos15.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (16, 1, 5, 'Posada Los Abuelos', 'Vereda La Cristalina, Armenia', 2, '3634783890', 'reservas@posadalosabuelos16.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (17, 2, 3, 'Nube Andina', 'Carrera 7 # 1-39, Buenavista', 4, '3902934291', 'reservas@nubeandina17.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (18, 2, 5, 'Posada El Trapiche', 'Carrera 5 # 5-56, Buenavista', 5, '3029674898', 'reservas@posadaeltrapiche18.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (19, 3, 2, 'Mirador del Valle', 'Carrera 3 # 15-7, Calarcá', 3, '3476911920', 'reservas@miradordelvalle19.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (20, 3, 1, 'La Primavera', 'Vereda La Cristalina, Calarcá', 3, '3997090132', 'reservas@laprimavera20.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (21, 3, 1, 'El Cafetal Alto', 'Vereda La Julia, Calarcá', 4, '3782874831', 'reservas@elcafetalalto21.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (22, 3, 1, 'Villa Maria', 'Vereda Los Andes, Calarcá', 3, '3111702419', 'reservas@villamaria22.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (23, 3, 3, 'Luna de Cafe', 'Vereda San Antonio, Calarcá', 4, '3934293518', 'reservas@lunadecafe23.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (24, 3, 4, 'Hostal Las Palmas', 'Calle 3 # 11-48, Calarcá', 3, '3554220549', 'reservas@hostallaspalmas24.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (25, 3, 5, 'Posada La Ceiba', 'Vereda El Jazmin, Calarcá', 4, '3960481566', 'reservas@posadalaceiba25.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (26, 4, 1, 'Los Naranjos', 'Vereda La Cristalina, Circasia', 5, '3736971359', 'reservas@losnaranjos26.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (27, 4, 1, 'El Paraiso Cafetero', 'Vereda La Cristalina, Circasia', 4, '3536996599', 'reservas@elparaisocafetero27.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (28, 4, 3, 'Estrella del Valle', 'Vereda Patio Bonito, Circasia', 5, '3230159494', 'reservas@estrelladelvalle28.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (29, 4, 5, 'Posada Rural El Sauce', 'Vereda Los Andes, Circasia', 5, '3313766509', 'reservas@posadaruralelsauce29.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (30, 5, 4, 'Hostal Kiwi', 'Carrera 9 # 5-16, Córdoba', 3, '3827364902', 'reservas@hostalkiwi30.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (31, 6, 1, 'La Colina', 'Carrera 13 # 9-60, Filandia', 4, '3437463168', 'reservas@lacolina31.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (32, 6, 1, 'San Jose de los Andes', 'Carrera 10 # 4-15, Filandia', 4, '3189731373', 'reservas@sanjosedelosandes32.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (33, 6, 1, 'El Arriero', 'Calle 14 # 9-50, Filandia', 3, '3893979846', 'reservas@elarriero33.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (34, 6, 3, 'Refugio Los Alisos', 'Carrera 11 # 5-56, Filandia', 5, '3150676232', 'reservas@refugiolosalisos34.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (35, 6, 3, 'Bosque Sereno', 'Carrera 4 # 13-11, Filandia', 4, '3787357780', 'reservas@bosquesereno35.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (36, 6, 4, 'Hostal El Descanso', 'Carrera 6 # 13-29, Filandia', 4, '3417060945', 'reservas@hostaleldescanso36.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (37, 7, 4, 'Hostal Andes', 'Carrera 2 # 14-7, Génova', 4, '3668322272', 'reservas@hostalandes37.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (38, 8, 1, 'Buena Vista Cafetera', 'Vereda Patio Bonito, La Tebaida', 4, '3985855251', 'reservas@buenavistacafetera38.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (39, 8, 1, 'Los Guaduales', 'Vereda La Julia, La Tebaida', 5, '3146926490', 'reservas@losguaduales39.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (40, 8, 3, 'Cielo Abierto', 'Vereda La Cristalina, La Tebaida', 3, '3285378736', 'reservas@cieloabierto40.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (41, 8, 4, 'Hostal Rio Verde', 'Calle 6 # 7-18, La Tebaida', 4, '3241674471', 'reservas@hostalrioverde41.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (42, 9, 2, 'Aurora Andina', 'Carrera 12 # 14-6, Montenegro', 4, '3356597841', 'reservas@auroraandina42.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (43, 9, 1, 'El Mirador Verde', 'Vereda San Antonio, Montenegro', 5, '3906742382', 'reservas@elmiradorverde43.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (44, 9, 1, 'La Argentina', 'Vereda El Jazmin, Montenegro', 4, '3302654374', 'reservas@laargentina44.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (45, 9, 1, 'Las Camelias', 'Vereda El Jazmin, Montenegro', 3, '3096730197', 'reservas@lascamelias45.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (46, 9, 3, 'Brisa de Montana', 'Vereda Los Andes, Montenegro', 5, '3079289495', 'reservas@brisademontana46.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (47, 9, 5, 'Posada Don Jose', 'Vereda La Cristalina, Montenegro', 5, '3799364942', 'reservas@posadadonjose47.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (48, 10, 3, 'Atardecer Cafetero', 'Carrera 8 # 2-54, Pijao', 5, '3146425023', 'reservas@atardecercafetero48.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (49, 10, 5, 'Posada La Palma', 'Calle 2 # 4-20, Pijao', 4, '3839636081', 'reservas@posadalapalma49.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (50, 10, 1, 'Hacienda El Roble', 'Calle 18 # 8-56, Pijao', 3, '3945382920', 'reservas@haciendaelroble50.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (51, 11, 2, 'Sol de Montenegro', 'Carrera 15 # 1-47, Quimbaya', 5, '3964747820', 'reservas@soldemontenegro51.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (52, 11, 1, 'Finca Los Nogales', 'Vereda Patio Bonito, Quimbaya', 4, '3054188752', 'reservas@fincalosnogales52.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (53, 11, 1, 'La Divisa', 'Vereda La Cristalina, Quimbaya', 5, '3382744351', 'reservas@ladivisa53.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (54, 11, 4, 'Hostal Ruta Cafetera', 'Carrera 13 # 3-38, Quimbaya', 5, '3614296420', 'reservas@hostalrutacafetera54.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (55, 12, 2, 'Portal del Eje', 'Calle 4 # 15-50, Salento', 5, '3211601255', 'reservas@portaldeleje55.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (56, 12, 1, 'El Recuerdo', 'Carrera 3 # 1-22, Salento', 3, '3457763729', 'reservas@elrecuerdo56.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (57, 12, 1, 'Monte Bello', 'Carrera 3 # 11-60, Salento', 3, '3754830429', 'reservas@montebello57.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (58, 12, 1, 'La Fortuna', 'Calle 11 # 6-36, Salento', 4, '3201650073', 'reservas@lafortuna58.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (59, 12, 1, 'Los Pinos', 'Calle 5 # 8-59, Salento', 3, '3211039554', 'reservas@lospinos59.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (60, 12, 1, 'El Encanto', 'Carrera 4 # 14-23, Salento', 5, '3026543121', 'reservas@elencanto60.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (61, 12, 3, 'Raices del Quindio', 'Calle 4 # 6-17, Salento', 3, '3479650117', 'reservas@raicesdelquindio61.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (62, 12, 3, 'Aire Puro', 'Carrera 14 # 13-31, Salento', 4, '3223215819', 'reservas@airepuro62.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (63, 12, 3, 'Mundo Verde', 'Calle 10 # 1-39, Salento', 5, '3780993176', 'reservas@mundoverde63.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (64, 12, 4, 'Hostal La Posada del Sol', 'Carrera 20 # 9-48, Salento', 4, '3454024377', 'reservas@hostallaposadadelsol64.co');
COMMIT;

-- Tabla auxiliar (se elimina al final): parametros "ocultos" de cada alojamiento
-- que guian la generacion: numero de habitaciones, popularidad (demanda),
-- calidad real (resenas), factor de precio y multiplicadores de temporada
-- (cada alojamiento decide cuanto sube en temporada alta: no es un % fijo).
CREATE TABLE stg_aloj_param (
  id_alojamiento NUMBER(5) PRIMARY KEY,
  id_tipo        NUMBER(2) NOT NULL,
  n_hab          NUMBER(3) NOT NULL,
  popularidad    NUMBER(6,3) NOT NULL,
  calidad        NUMBER(4,2) NOT NULL,
  factor_precio  NUMBER(6,3) NOT NULL,
  mult_alta      NUMBER(6,3) NOT NULL,
  mult_media     NUMBER(6,3) NOT NULL
);
INSERT INTO stg_aloj_param VALUES (1, 2, 36, 1.412, 3.13, 0.89, 1.376, 1.219);
INSERT INTO stg_aloj_param VALUES (2, 2, 30, 1.52, 4.15, 1.181, 1.277, 1.153);
INSERT INTO stg_aloj_param VALUES (3, 2, 33, 1.635, 4.73, 1.351, 1.252, 1.132);
INSERT INTO stg_aloj_param VALUES (4, 2, 30, 1.669, 3.32, 0.918, 1.175, 1.097);
INSERT INTO stg_aloj_param VALUES (5, 2, 29, 1.124, 4.66, 1.471, 1.124, 1.072);
INSERT INTO stg_aloj_param VALUES (6, 2, 30, 1.633, 3.21, 0.919, 1.51, 1.279);
INSERT INTO stg_aloj_param VALUES (7, 4, 7, 0.871, 3.14, 0.587, 1.572, 1.19);
INSERT INTO stg_aloj_param VALUES (8, 4, 11, 0.881, 4.32, 0.685, 1.629, 1.252);
INSERT INTO stg_aloj_param VALUES (9, 4, 8, 1.449, 3.81, 0.714, 1.504, 1.238);
INSERT INTO stg_aloj_param VALUES (10, 4, 12, 1.363, 4.79, 0.911, 1.583, 1.196);
INSERT INTO stg_aloj_param VALUES (11, 4, 8, 1.405, 2.65, 0.477, 1.542, 1.273);
INSERT INTO stg_aloj_param VALUES (12, 3, 6, 1.565, 4.58, 1.876, 1.608, 1.286);
INSERT INTO stg_aloj_param VALUES (13, 1, 5, 1.344, 3.31, 1.069, 1.333, 1.131);
INSERT INTO stg_aloj_param VALUES (14, 1, 5, 1.198, 3.92, 1.215, 1.162, 1.078);
INSERT INTO stg_aloj_param VALUES (15, 1, 5, 0.873, 3.67, 1.006, 1.456, 1.165);
INSERT INTO stg_aloj_param VALUES (16, 5, 6, 0.859, 2.64, 0.614, 1.572, 1.285);
INSERT INTO stg_aloj_param VALUES (17, 3, 6, 0.459, 4.52, 1.777, 1.514, 1.227);
INSERT INTO stg_aloj_param VALUES (18, 5, 4, 0.313, 4.75, 1.059, 1.382, 1.137);
INSERT INTO stg_aloj_param VALUES (19, 2, 24, 1.215, 3.7, 1.075, 1.475, 1.228);
INSERT INTO stg_aloj_param VALUES (20, 1, 5, 0.704, 2.76, 0.851, 1.489, 1.213);
INSERT INTO stg_aloj_param VALUES (21, 1, 3, 1.031, 2.6, 0.809, 1.402, 1.125);
INSERT INTO stg_aloj_param VALUES (22, 1, 3, 0.837, 3.7, 1.048, 1.317, 1.164);
INSERT INTO stg_aloj_param VALUES (23, 3, 7, 1.157, 4.06, 1.563, 1.152, 1.09);
INSERT INTO stg_aloj_param VALUES (24, 4, 10, 0.668, 2.97, 0.544, 1.227, 1.103);
INSERT INTO stg_aloj_param VALUES (25, 5, 8, 0.827, 3.17, 0.741, 1.207, 1.071);
INSERT INTO stg_aloj_param VALUES (26, 1, 3, 1.029, 3.46, 1.018, 1.649, 1.27);
INSERT INTO stg_aloj_param VALUES (27, 1, 3, 0.948, 3.64, 1.05, 1.17, 1.059);
INSERT INTO stg_aloj_param VALUES (28, 3, 5, 1.315, 4.31, 1.614, 1.508, 1.163);
INSERT INTO stg_aloj_param VALUES (29, 5, 7, 0.766, 4.73, 1.053, 1.449, 1.162);
INSERT INTO stg_aloj_param VALUES (30, 4, 11, 0.254, 3.27, 0.557, 1.584, 1.339);
INSERT INTO stg_aloj_param VALUES (31, 1, 3, 1.181, 2.6, 0.756, 1.332, 1.116);
INSERT INTO stg_aloj_param VALUES (32, 1, 4, 1.007, 3.28, 0.879, 1.153, 1.054);
INSERT INTO stg_aloj_param VALUES (33, 1, 5, 1.122, 3.5, 0.977, 1.436, 1.198);
INSERT INTO stg_aloj_param VALUES (34, 3, 6, 1.146, 4.6, 1.913, 1.587, 1.331);
INSERT INTO stg_aloj_param VALUES (35, 3, 7, 1.803, 3.61, 1.398, 1.153, 1.088);
INSERT INTO stg_aloj_param VALUES (36, 4, 7, 0.987, 4.28, 0.769, 1.587, 1.193);
INSERT INTO stg_aloj_param VALUES (37, 4, 14, 0.334, 3.33, 0.633, 1.172, 1.055);
INSERT INTO stg_aloj_param VALUES (38, 1, 5, 0.629, 3.51, 0.987, 1.467, 1.271);
INSERT INTO stg_aloj_param VALUES (39, 1, 4, 0.784, 4.19, 1.284, 1.526, 1.176);
INSERT INTO stg_aloj_param VALUES (40, 3, 4, 0.873, 3.08, 1.11, 1.171, 1.08);
INSERT INTO stg_aloj_param VALUES (41, 4, 7, 0.871, 3.76, 0.608, 1.451, 1.248);
INSERT INTO stg_aloj_param VALUES (42, 2, 23, 1.216, 3.91, 1.111, 1.36, 1.118);
INSERT INTO stg_aloj_param VALUES (43, 1, 5, 1.198, 4.66, 1.262, 1.333, 1.1);
INSERT INTO stg_aloj_param VALUES (44, 1, 4, 0.889, 3.29, 0.986, 1.375, 1.215);
INSERT INTO stg_aloj_param VALUES (45, 1, 5, 1.071, 3.21, 0.978, 1.611, 1.325);
INSERT INTO stg_aloj_param VALUES (46, 3, 4, 1.145, 4.9, 2.013, 1.409, 1.205);
INSERT INTO stg_aloj_param VALUES (47, 5, 6, 0.715, 4.39, 1.082, 1.254, 1.145);
INSERT INTO stg_aloj_param VALUES (48, 3, 6, 0.638, 3.51, 1.404, 1.415, 1.139);
INSERT INTO stg_aloj_param VALUES (49, 5, 5, 0.492, 3.58, 0.77, 1.467, 1.174);
INSERT INTO stg_aloj_param VALUES (50, 1, 3, 0.592, 2.6, 0.708, 1.466, 1.231);
INSERT INTO stg_aloj_param VALUES (51, 2, 22, 0.711, 4.06, 1.144, 1.538, 1.282);
INSERT INTO stg_aloj_param VALUES (52, 1, 4, 0.587, 3.64, 1.012, 1.258, 1.115);
INSERT INTO stg_aloj_param VALUES (53, 1, 3, 0.755, 4.58, 1.368, 1.212, 1.076);
INSERT INTO stg_aloj_param VALUES (54, 4, 9, 0.883, 4.25, 0.676, 1.311, 1.155);
INSERT INTO stg_aloj_param VALUES (55, 2, 17, 1.323, 4.9, 1.318, 1.576, 1.33);
INSERT INTO stg_aloj_param VALUES (56, 1, 5, 1.381, 3.55, 1.071, 1.446, 1.209);
INSERT INTO stg_aloj_param VALUES (57, 1, 3, 1.286, 2.93, 0.818, 1.57, 1.227);
INSERT INTO stg_aloj_param VALUES (58, 1, 5, 1.1, 2.69, 0.742, 1.119, 1.071);
INSERT INTO stg_aloj_param VALUES (59, 1, 4, 1.287, 3.27, 1.023, 1.354, 1.142);
INSERT INTO stg_aloj_param VALUES (60, 1, 3, 1.728, 3.48, 1.012, 1.415, 1.224);
INSERT INTO stg_aloj_param VALUES (61, 3, 5, 2.134, 3.42, 1.487, 1.512, 1.284);
INSERT INTO stg_aloj_param VALUES (62, 3, 5, 1.791, 3.94, 1.583, 1.347, 1.114);
INSERT INTO stg_aloj_param VALUES (63, 3, 6, 2.298, 4.02, 1.461, 1.368, 1.125);
INSERT INTO stg_aloj_param VALUES (64, 4, 12, 1.43, 3.35, 0.559, 1.202, 1.093);
COMMIT;

-- ---------------------------------------------------------------------
-- 3. TEMPORADA (40): alta/media/baja para 2024, 2025 y 2026
--    (mas el tramo diciembre-enero 2023-2024 para cubrir enero de 2024).
--    Rangos continuos: cada dia del calendario pertenece a UNA temporada.
-- ---------------------------------------------------------------------
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (1, 'Alta diciembre-enero 2023-2024', 'ALTA', 2023, DATE '2023-12-15', DATE '2024-01-10');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (2, 'Baja enero-febrero 2024', 'BAJA', 2024, DATE '2024-01-11', DATE '2024-02-29');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (3, 'Media marzo 2024', 'MEDIA', 2024, DATE '2024-03-01', DATE '2024-03-23');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (4, 'Alta Semana Santa 2024', 'ALTA', 2024, DATE '2024-03-24', DATE '2024-03-31');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (5, 'Baja abril-mayo 2024', 'BAJA', 2024, DATE '2024-04-01', DATE '2024-05-31');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (6, 'Media junio 2024', 'MEDIA', 2024, DATE '2024-06-01', DATE '2024-06-14');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (7, 'Alta mitad de ano 2024', 'ALTA', 2024, DATE '2024-06-15', DATE '2024-07-15');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (8, 'Media julio-agosto 2024', 'MEDIA', 2024, DATE '2024-07-16', DATE '2024-08-31');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (9, 'Baja septiembre-octubre 2024', 'BAJA', 2024, DATE '2024-09-01', DATE '2024-10-10');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (10, 'Alta puente festivo de octubre 2024', 'ALTA', 2024, DATE '2024-10-11', DATE '2024-10-14');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (11, 'Media octubre-noviembre 2024', 'MEDIA', 2024, DATE '2024-10-15', DATE '2024-11-07');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (12, 'Alta puente festivo de noviembre 2024', 'ALTA', 2024, DATE '2024-11-08', DATE '2024-11-11');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (13, 'Media noviembre-diciembre 2024', 'MEDIA', 2024, DATE '2024-11-12', DATE '2024-12-14');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (14, 'Alta diciembre-enero 2024-2025', 'ALTA', 2024, DATE '2024-12-15', DATE '2025-01-10');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (15, 'Baja enero-febrero 2025', 'BAJA', 2025, DATE '2025-01-11', DATE '2025-02-28');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (16, 'Media marzo 2025', 'MEDIA', 2025, DATE '2025-03-01', DATE '2025-04-12');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (17, 'Alta Semana Santa 2025', 'ALTA', 2025, DATE '2025-04-13', DATE '2025-04-20');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (18, 'Baja abril-mayo 2025', 'BAJA', 2025, DATE '2025-04-21', DATE '2025-05-31');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (19, 'Media junio 2025', 'MEDIA', 2025, DATE '2025-06-01', DATE '2025-06-14');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (20, 'Alta mitad de ano 2025', 'ALTA', 2025, DATE '2025-06-15', DATE '2025-07-15');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (21, 'Media julio-agosto 2025', 'MEDIA', 2025, DATE '2025-07-16', DATE '2025-08-31');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (22, 'Baja septiembre-octubre 2025', 'BAJA', 2025, DATE '2025-09-01', DATE '2025-10-09');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (23, 'Alta puente festivo de octubre 2025', 'ALTA', 2025, DATE '2025-10-10', DATE '2025-10-13');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (24, 'Media octubre-noviembre 2025', 'MEDIA', 2025, DATE '2025-10-14', DATE '2025-11-13');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (25, 'Alta puente festivo de noviembre 2025', 'ALTA', 2025, DATE '2025-11-14', DATE '2025-11-17');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (26, 'Media noviembre-diciembre 2025', 'MEDIA', 2025, DATE '2025-11-18', DATE '2025-12-14');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (27, 'Alta diciembre-enero 2025-2026', 'ALTA', 2025, DATE '2025-12-15', DATE '2026-01-10');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (28, 'Baja enero-febrero 2026', 'BAJA', 2026, DATE '2026-01-11', DATE '2026-02-28');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (29, 'Media marzo 2026', 'MEDIA', 2026, DATE '2026-03-01', DATE '2026-03-28');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (30, 'Alta Semana Santa 2026', 'ALTA', 2026, DATE '2026-03-29', DATE '2026-04-05');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (31, 'Baja abril-mayo 2026', 'BAJA', 2026, DATE '2026-04-06', DATE '2026-05-31');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (32, 'Media junio 2026', 'MEDIA', 2026, DATE '2026-06-01', DATE '2026-06-14');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (33, 'Alta mitad de ano 2026', 'ALTA', 2026, DATE '2026-06-15', DATE '2026-07-15');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (34, 'Media julio-agosto 2026', 'MEDIA', 2026, DATE '2026-07-16', DATE '2026-08-31');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (35, 'Baja septiembre-octubre 2026', 'BAJA', 2026, DATE '2026-09-01', DATE '2026-10-08');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (36, 'Alta puente festivo de octubre 2026', 'ALTA', 2026, DATE '2026-10-09', DATE '2026-10-12');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (37, 'Media octubre-noviembre 2026', 'MEDIA', 2026, DATE '2026-10-13', DATE '2026-11-12');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (38, 'Alta puente festivo de noviembre 2026', 'ALTA', 2026, DATE '2026-11-13', DATE '2026-11-16');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (39, 'Media noviembre-diciembre 2026', 'MEDIA', 2026, DATE '2026-11-17', DATE '2026-12-14');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (40, 'Alta diciembre-enero 2026-2027', 'ALTA', 2026, DATE '2026-12-15', DATE '2027-01-10');
COMMIT;

-- ---------------------------------------------------------------------
-- 4. HABITACION (~590): hoteles grandes con 15-40, fincas con 3-5
-- ---------------------------------------------------------------------
DECLARE
  v_id    NUMBER := 0;
  v_r     NUMBER;
  v_tipo  VARCHAR2(10);
  v_cap   NUMBER;
  v_num   NUMBER;
  v_desc  VARCHAR2(300);
BEGIN
  FOR a IN (SELECT id_alojamiento, id_tipo, n_hab FROM stg_aloj_param ORDER BY id_alojamiento) LOOP
    FOR n IN 1 .. a.n_hab LOOP
      v_r := DBMS_RANDOM.VALUE;
      IF a.id_tipo = 2 THEN          -- Hotel
        v_tipo := CASE WHEN v_r < 0.30 THEN 'SENCILLA' WHEN v_r < 0.75 THEN 'DOBLE' ELSE 'SUITE' END;
      ELSIF a.id_tipo = 1 THEN       -- Finca cafetera
        v_tipo := CASE WHEN v_r < 0.60 THEN 'CABANA' ELSE 'DOBLE' END;
      ELSIF a.id_tipo = 3 THEN       -- Glamping
        v_tipo := CASE WHEN v_r < 0.70 THEN 'CABANA' ELSE 'SUITE' END;
      ELSIF a.id_tipo = 4 THEN       -- Hostal
        v_tipo := CASE WHEN v_r < 0.50 THEN 'SENCILLA' ELSE 'DOBLE' END;
      ELSE                           -- Posada rural
        v_tipo := CASE WHEN v_r < 0.30 THEN 'SENCILLA' WHEN v_r < 0.80 THEN 'DOBLE' ELSE 'CABANA' END;
      END IF;

      IF v_tipo = 'SENCILLA' THEN
        v_cap := TRUNC(DBMS_RANDOM.VALUE(1, 3));      -- 1..2
        v_desc := 'Habitacion sencilla con bano privado';
      ELSIF v_tipo = 'DOBLE' THEN
        v_cap := TRUNC(DBMS_RANDOM.VALUE(2, 5));      -- 2..4
        v_desc := 'Habitacion doble con bano privado y vista al paisaje';
      ELSIF v_tipo = 'SUITE' THEN
        v_cap := TRUNC(DBMS_RANDOM.VALUE(3, 6));      -- 3..5
        v_desc := 'Suite amplia con sala, zona de descanso y balcon';
      ELSE
        v_cap := TRUNC(DBMS_RANDOM.VALUE(4, 9));      -- 4..8
        v_desc := 'Cabana independiente con cocineta y terraza';
      END IF;

      -- Hoteles: numeracion por pisos (101..110, 201..210...); resto: 1, 2, 3...
      IF a.id_tipo = 2 THEN
        v_num := 100 * (1 + TRUNC((n - 1) / 10)) + MOD(n - 1, 10) + 1;
      ELSE
        v_num := n;
      END IF;

      v_id := v_id + 1;
      INSERT INTO habitacion (id_habitacion, id_alojamiento, numero, capacidad, tipo, descripcion)
      VALUES (v_id, a.id_alojamiento, v_num, v_cap, v_tipo, v_desc);
    END LOOP;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('HABITACION cargadas: ' || v_id);
END;
/

-- ---------------------------------------------------------------------
-- 5. TARIFA: una fila por cada combinacion habitacion x temporada.
--    Precio = base del tipo de habitacion x factor del alojamiento
--             x inflacion del anio x multiplicador de temporada DEL
--             ALOJAMIENTO (no es un % fijo) x ruido; redondeado a miles.
-- ---------------------------------------------------------------------
INSERT INTO tarifa (id_habitacion, id_temporada, valor_noche)
SELECT h.id_habitacion,
       t.id_temporada,
       ROUND( CASE h.tipo WHEN 'SENCILLA' THEN 90000 WHEN 'DOBLE' THEN 140000
                          WHEN 'SUITE' THEN 260000 ELSE 220000 END
              * p.factor_precio
              * CASE t.anio WHEN 2023 THEN 0.95 WHEN 2024 THEN 1.00 WHEN 2025 THEN 1.06 ELSE 1.12 END
              * CASE t.nivel WHEN 'ALTA' THEN p.mult_alta WHEN 'MEDIA' THEN p.mult_media ELSE 1 END
              * (0.97 + DBMS_RANDOM.VALUE(0, 0.06)), -3)
FROM   habitacion h
JOIN   stg_aloj_param p ON p.id_alojamiento = h.id_alojamiento
CROSS JOIN temporada t;
COMMIT;

-- ---------------------------------------------------------------------
-- 6. SERVICIO (120): al menos un servicio por alojamiento
-- ---------------------------------------------------------------------
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (1, 1, 'Desayuno buffet', 'Desayuno buffet con productos de la region', 21500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (2, 1, 'Transporte al aeropuerto', 'Traslado privado al aeropuerto El Eden', 76000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (3, 1, 'Spa y masajes', 'Sesion de spa y masaje relajante de 60 minutos', 109500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (4, 2, 'Desayuno buffet', 'Desayuno buffet con productos de la region', 27500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (5, 2, 'Transporte al aeropuerto', 'Traslado privado al aeropuerto El Eden', 116000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (6, 2, 'Spa y masajes', 'Sesion de spa y masaje relajante de 60 minutos', 148000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (7, 3, 'Desayuno buffet', 'Desayuno buffet con productos de la region', 32500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (8, 3, 'Transporte al aeropuerto', 'Traslado privado al aeropuerto El Eden', 130000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (9, 3, 'Spa y masajes', 'Sesion de spa y masaje relajante de 60 minutos', 181500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (10, 4, 'Desayuno buffet', 'Desayuno buffet con productos de la region', 25000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (11, 4, 'Transporte al aeropuerto', 'Traslado privado al aeropuerto El Eden', 84500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (12, 4, 'Spa y masajes', 'Sesion de spa y masaje relajante de 60 minutos', 120000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (13, 5, 'Desayuno buffet', 'Desayuno buffet con productos de la region', 37000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (14, 5, 'Transporte al aeropuerto', 'Traslado privado al aeropuerto El Eden', 126500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (15, 5, 'Spa y masajes', 'Sesion de spa y masaje relajante de 60 minutos', 215000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (16, 6, 'Desayuno buffet', 'Desayuno buffet con productos de la region', 22000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (17, 6, 'Transporte al aeropuerto', 'Traslado privado al aeropuerto El Eden', 82500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (18, 6, 'Spa y masajes', 'Sesion de spa y masaje relajante de 60 minutos', 128000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (19, 7, 'Alquiler de bicicletas', 'Bicicleta de montana por dia', 14500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (20, 8, 'Alquiler de bicicletas', 'Bicicleta de montana por dia', 19000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (21, 9, 'Alquiler de bicicletas', 'Bicicleta de montana por dia', 20500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (22, 10, 'Alquiler de bicicletas', 'Bicicleta de montana por dia', 23500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (23, 11, 'Alquiler de bicicletas', 'Bicicleta de montana por dia', 14000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (24, 12, 'Desayuno en el domo', 'Desayuno servido en la terraza del domo', 62000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (25, 12, 'Cena romantica', 'Cena a la luz de las velas con fogata', 236000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (26, 13, 'Tour guiado del cafe', 'Recorrido guiado por el cultivo y beneficio del cafe', 52000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (27, 13, 'Desayuno campesino', 'Desayuno tipico con arepa, huevos y cafe de la finca', 20500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (28, 14, 'Tour guiado del cafe', 'Recorrido guiado por el cultivo y beneficio del cafe', 56500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (29, 14, 'Desayuno campesino', 'Desayuno tipico con arepa, huevos y cafe de la finca', 21000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (30, 15, 'Tour guiado del cafe', 'Recorrido guiado por el cultivo y beneficio del cafe', 46000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (31, 15, 'Desayuno campesino', 'Desayuno tipico con arepa, huevos y cafe de la finca', 22000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (32, 16, 'Desayuno tipico', 'Desayuno tipico quindiano', 11500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (33, 17, 'Desayuno en el domo', 'Desayuno servido en la terraza del domo', 57500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (34, 17, 'Cena romantica', 'Cena a la luz de las velas con fogata', 230000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (35, 18, 'Desayuno tipico', 'Desayuno tipico quindiano', 20000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (36, 19, 'Desayuno buffet', 'Desayuno buffet con productos de la region', 29500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (37, 19, 'Transporte al aeropuerto', 'Traslado privado al aeropuerto El Eden', 95500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (38, 19, 'Spa y masajes', 'Sesion de spa y masaje relajante de 60 minutos', 133500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (39, 20, 'Tour guiado del cafe', 'Recorrido guiado por el cultivo y beneficio del cafe', 46000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (40, 20, 'Desayuno campesino', 'Desayuno tipico con arepa, huevos y cafe de la finca', 15000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (41, 21, 'Tour guiado del cafe', 'Recorrido guiado por el cultivo y beneficio del cafe', 42500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (42, 21, 'Desayuno campesino', 'Desayuno tipico con arepa, huevos y cafe de la finca', 16000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (43, 22, 'Tour guiado del cafe', 'Recorrido guiado por el cultivo y beneficio del cafe', 57500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (44, 22, 'Desayuno campesino', 'Desayuno tipico con arepa, huevos y cafe de la finca', 22500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (45, 23, 'Desayuno en el domo', 'Desayuno servido en la terraza del domo', 53500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (46, 23, 'Cena romantica', 'Cena a la luz de las velas con fogata', 163500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (47, 24, 'Alquiler de bicicletas', 'Bicicleta de montana por dia', 13000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (48, 25, 'Desayuno tipico', 'Desayuno tipico quindiano', 13500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (49, 26, 'Tour guiado del cafe', 'Recorrido guiado por el cultivo y beneficio del cafe', 54000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (50, 26, 'Desayuno campesino', 'Desayuno tipico con arepa, huevos y cafe de la finca', 18000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (51, 27, 'Tour guiado del cafe', 'Recorrido guiado por el cultivo y beneficio del cafe', 50500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (52, 27, 'Desayuno campesino', 'Desayuno tipico con arepa, huevos y cafe de la finca', 18500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (53, 28, 'Desayuno en el domo', 'Desayuno servido en la terraza del domo', 50500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (54, 28, 'Cena romantica', 'Cena a la luz de las velas con fogata', 167500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (55, 29, 'Desayuno tipico', 'Desayuno tipico quindiano', 18500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (56, 30, 'Alquiler de bicicletas', 'Bicicleta de montana por dia', 15000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (57, 31, 'Tour guiado del cafe', 'Recorrido guiado por el cultivo y beneficio del cafe', 34500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (58, 31, 'Desayuno campesino', 'Desayuno tipico con arepa, huevos y cafe de la finca', 16000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (59, 32, 'Tour guiado del cafe', 'Recorrido guiado por el cultivo y beneficio del cafe', 38500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (60, 32, 'Desayuno campesino', 'Desayuno tipico con arepa, huevos y cafe de la finca', 16000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (61, 33, 'Tour guiado del cafe', 'Recorrido guiado por el cultivo y beneficio del cafe', 45000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (62, 33, 'Desayuno campesino', 'Desayuno tipico con arepa, huevos y cafe de la finca', 18500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (63, 34, 'Desayuno en el domo', 'Desayuno servido en la terraza del domo', 67000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (64, 34, 'Cena romantica', 'Cena a la luz de las velas con fogata', 217500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (65, 35, 'Desayuno en el domo', 'Desayuno servido en la terraza del domo', 48000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (66, 35, 'Cena romantica', 'Cena a la luz de las velas con fogata', 182000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (67, 36, 'Alquiler de bicicletas', 'Bicicleta de montana por dia', 18500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (68, 37, 'Alquiler de bicicletas', 'Bicicleta de montana por dia', 18500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (69, 38, 'Tour guiado del cafe', 'Recorrido guiado por el cultivo y beneficio del cafe', 49500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (70, 38, 'Desayuno campesino', 'Desayuno tipico con arepa, huevos y cafe de la finca', 20500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (71, 39, 'Tour guiado del cafe', 'Recorrido guiado por el cultivo y beneficio del cafe', 65000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (72, 39, 'Desayuno campesino', 'Desayuno tipico con arepa, huevos y cafe de la finca', 24500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (73, 40, 'Desayuno en el domo', 'Desayuno servido en la terraza del domo', 33000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (74, 40, 'Cena romantica', 'Cena a la luz de las velas con fogata', 119500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (75, 41, 'Alquiler de bicicletas', 'Bicicleta de montana por dia', 15000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (76, 42, 'Desayuno buffet', 'Desayuno buffet con productos de la region', 25000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (77, 42, 'Transporte al aeropuerto', 'Traslado privado al aeropuerto El Eden', 93500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (78, 42, 'Spa y masajes', 'Sesion de spa y masaje relajante de 60 minutos', 137500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (79, 43, 'Tour guiado del cafe', 'Recorrido guiado por el cultivo y beneficio del cafe', 63000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (80, 43, 'Desayuno campesino', 'Desayuno tipico con arepa, huevos y cafe de la finca', 26000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (81, 44, 'Tour guiado del cafe', 'Recorrido guiado por el cultivo y beneficio del cafe', 52000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (82, 44, 'Desayuno campesino', 'Desayuno tipico con arepa, huevos y cafe de la finca', 21000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (83, 45, 'Tour guiado del cafe', 'Recorrido guiado por el cultivo y beneficio del cafe', 43500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (84, 45, 'Desayuno campesino', 'Desayuno tipico con arepa, huevos y cafe de la finca', 20500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (85, 46, 'Desayuno en el domo', 'Desayuno servido en la terraza del domo', 61000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (86, 46, 'Cena romantica', 'Cena a la luz de las velas con fogata', 212500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (87, 47, 'Desayuno tipico', 'Desayuno tipico quindiano', 19000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (88, 48, 'Desayuno en el domo', 'Desayuno servido en la terraza del domo', 47000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (89, 48, 'Cena romantica', 'Cena a la luz de las velas con fogata', 147000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (90, 49, 'Desayuno tipico', 'Desayuno tipico quindiano', 13000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (91, 50, 'Tour guiado del cafe', 'Recorrido guiado por el cultivo y beneficio del cafe', 34000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (92, 50, 'Desayuno campesino', 'Desayuno tipico con arepa, huevos y cafe de la finca', 15000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (93, 51, 'Desayuno buffet', 'Desayuno buffet con productos de la region', 27500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (94, 51, 'Transporte al aeropuerto', 'Traslado privado al aeropuerto El Eden', 103500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (95, 51, 'Spa y masajes', 'Sesion de spa y masaje relajante de 60 minutos', 147500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (96, 52, 'Tour guiado del cafe', 'Recorrido guiado por el cultivo y beneficio del cafe', 45000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (97, 52, 'Desayuno campesino', 'Desayuno tipico con arepa, huevos y cafe de la finca', 21500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (98, 53, 'Tour guiado del cafe', 'Recorrido guiado por el cultivo y beneficio del cafe', 74500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (99, 53, 'Desayuno campesino', 'Desayuno tipico con arepa, huevos y cafe de la finca', 28000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (100, 54, 'Alquiler de bicicletas', 'Bicicleta de montana por dia', 17500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (101, 55, 'Desayuno buffet', 'Desayuno buffet con productos de la region', 32000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (102, 55, 'Transporte al aeropuerto', 'Traslado privado al aeropuerto El Eden', 116000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (103, 55, 'Spa y masajes', 'Sesion de spa y masaje relajante de 60 minutos', 182000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (104, 56, 'Tour guiado del cafe', 'Recorrido guiado por el cultivo y beneficio del cafe', 54500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (105, 56, 'Desayuno campesino', 'Desayuno tipico con arepa, huevos y cafe de la finca', 20000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (106, 57, 'Tour guiado del cafe', 'Recorrido guiado por el cultivo y beneficio del cafe', 44000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (107, 57, 'Desayuno campesino', 'Desayuno tipico con arepa, huevos y cafe de la finca', 17000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (108, 58, 'Tour guiado del cafe', 'Recorrido guiado por el cultivo y beneficio del cafe', 34000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (109, 58, 'Desayuno campesino', 'Desayuno tipico con arepa, huevos y cafe de la finca', 15500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (110, 59, 'Tour guiado del cafe', 'Recorrido guiado por el cultivo y beneficio del cafe', 52500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (111, 59, 'Desayuno campesino', 'Desayuno tipico con arepa, huevos y cafe de la finca', 18500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (112, 60, 'Tour guiado del cafe', 'Recorrido guiado por el cultivo y beneficio del cafe', 47500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (113, 60, 'Desayuno campesino', 'Desayuno tipico con arepa, huevos y cafe de la finca', 21000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (114, 61, 'Desayuno en el domo', 'Desayuno servido en la terraza del domo', 44000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (115, 61, 'Cena romantica', 'Cena a la luz de las velas con fogata', 172500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (116, 62, 'Desayuno en el domo', 'Desayuno servido en la terraza del domo', 58000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (117, 62, 'Cena romantica', 'Cena a la luz de las velas con fogata', 175500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (118, 63, 'Desayuno en el domo', 'Desayuno servido en la terraza del domo', 48000);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (119, 63, 'Cena romantica', 'Cena a la luz de las velas con fogata', 189500);
INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio) VALUES (120, 64, 'Alquiler de bicicletas', 'Bicicleta de montana por dia', 16500);
COMMIT;

-- ---------------------------------------------------------------------
-- 7. CLIENTE (3.000): ciudades variadas (no solo del Quindio), con
--    sesgo: muchos de Armenia/Bogota/Pereira y pocos del exterior.
-- ---------------------------------------------------------------------
DECLARE
  TYPE t_lista IS TABLE OF VARCHAR2(40);
  v_nom t_lista := t_lista('Juan','Maria','Carlos','Luisa','Andres','Paola','Camilo','Diana','Felipe','Natalia',
                           'Sebastian','Valentina','Santiago','Laura','Daniel','Carolina','Jorge','Sofia','Alejandro','Juliana',
                           'Mateo','Catalina','Nicolas','Isabella','David','Marcela','Ricardo','Angela','Oscar','Lina');
  v_ape t_lista := t_lista('Garcia','Rodriguez','Martinez','Lopez','Gonzalez','Hernandez','Ramirez','Torres','Diaz','Vargas',
                           'Castro','Ruiz','Ortiz','Moreno','Munoz','Rojas','Gomez','Jimenez','Suarez','Patino',
                           'Osorio','Giraldo','Zapata','Arias','Cardona','Londono','Valencia','Salazar','Herrera','Henao');
  -- Las primeras 20 ciudades son colombianas; las ultimas 5, del exterior
  v_ciu t_lista := t_lista('Armenia','Bogota','Pereira','Cali','Medellin','Manizales','Calarca','Ibague','Bucaramanga','Barranquilla',
                           'Cartagena','Cucuta','Neiva','Villavicencio','Popayan','Pasto','Tulua','Cartago','Monteria','Santa Marta',
                           'Buenos Aires','Quito','Miami','Madrid','Ciudad de Mexico');
  v_ci  PLS_INTEGER;
  v_a   PLS_INTEGER;
  v_b   PLS_INTEGER;
  v_td  VARCHAR2(3);
  v_doc VARCHAR2(20);
  v_dom VARCHAR2(20);
BEGIN
  FOR i IN 1 .. 3000 LOOP
    v_ci := 1 + TRUNC(POWER(DBMS_RANDOM.VALUE, 2.2) * v_ciu.COUNT);
    v_a  := 1 + TRUNC(DBMS_RANDOM.VALUE * v_nom.COUNT);
    v_b  := 1 + TRUNC(DBMS_RANDOM.VALUE * v_ape.COUNT);
    IF v_ci > 20 THEN
      v_td := 'PAS';
    ELSIF DBMS_RANDOM.VALUE < 0.05 THEN
      v_td := 'CE';
    ELSE
      v_td := 'CC';
    END IF;
    v_doc := TO_CHAR(10000000 + i * 12347 + TRUNC(DBMS_RANDOM.VALUE(0, 10000)));
    IF v_td = 'PAS' THEN v_doc := 'PA' || v_doc; END IF;
    v_dom := CASE MOD(i, 4) WHEN 0 THEN 'gmail.com' WHEN 1 THEN 'hotmail.com' WHEN 2 THEN 'outlook.com' ELSE 'yahoo.com' END;
    INSERT INTO cliente (id_cliente, tipo_documento, numero_documento, nombre, apellido, correo, telefono, ciudad_origen)
    VALUES (i, v_td, v_doc, v_nom(v_a), v_ape(v_b),
            LOWER(v_nom(v_a)) || '.' || LOWER(v_ape(v_b)) || i || '@' || v_dom,
            '3' || LPAD(TRUNC(DBMS_RANDOM.VALUE(0, 1000000000)), 9, '0'),
            v_ciu(v_ci));
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('CLIENTE cargados: 3000');
END;
/

-- ---------------------------------------------------------------------
-- 8. USUARIO_SISTEMA (10): administradores y al menos un encargado por
--    cada tipo de alojamiento (cada encargado, atado a UN alojamiento).
-- ---------------------------------------------------------------------
INSERT INTO usuario_sistema (id_usuario, username, nombre_completo, correo, rol, id_alojamiento) VALUES (1, 'admin.turismo', 'Carolina Restrepo Gil', 'admin@turismouq.co', 'ADMIN_PLATAFORMA', NULL);
INSERT INTO usuario_sistema (id_usuario, username, nombre_completo, correo, rol, id_alojamiento) VALUES (2, 'soporte.plataforma', 'Miguel Angel Ospina', 'soporte@turismouq.co', 'ADMIN_PLATAFORMA', NULL);
INSERT INTO usuario_sistema (id_usuario, username, nombre_completo, correo, rol, id_alojamiento) VALUES (3, 'enc.finca1', 'Luz Marina Cardona', 'luz.cardona@turismouq.co', 'ENCARGADO_ALOJAMIENTO', 13);
INSERT INTO usuario_sistema (id_usuario, username, nombre_completo, correo, rol, id_alojamiento) VALUES (4, 'enc.hotel1', 'Andres Felipe Salazar', 'andres.salazar@turismouq.co', 'ENCARGADO_ALOJAMIENTO', 1);
INSERT INTO usuario_sistema (id_usuario, username, nombre_completo, correo, rol, id_alojamiento) VALUES (5, 'enc.glamping1', 'Paula Andrea Giraldo', 'paula.giraldo@turismouq.co', 'ENCARGADO_ALOJAMIENTO', 12);
INSERT INTO usuario_sistema (id_usuario, username, nombre_completo, correo, rol, id_alojamiento) VALUES (6, 'enc.hostal1', 'Jhon Fredy Zapata', 'jhon.zapata@turismouq.co', 'ENCARGADO_ALOJAMIENTO', 7);
INSERT INTO usuario_sistema (id_usuario, username, nombre_completo, correo, rol, id_alojamiento) VALUES (7, 'enc.posada1', 'Gloria Patricia Arias', 'gloria.arias@turismouq.co', 'ENCARGADO_ALOJAMIENTO', 16);
INSERT INTO usuario_sistema (id_usuario, username, nombre_completo, correo, rol, id_alojamiento) VALUES (8, 'enc.hotel2', 'Diego Armando Henao', 'diego.henao@turismouq.co', 'ENCARGADO_ALOJAMIENTO', 2);
INSERT INTO usuario_sistema (id_usuario, username, nombre_completo, correo, rol, id_alojamiento) VALUES (9, 'enc.finca2', 'Sandra Milena Osorio', 'sandra.osorio@turismouq.co', 'ENCARGADO_ALOJAMIENTO', 14);
INSERT INTO usuario_sistema (id_usuario, username, nombre_completo, correo, rol, id_alojamiento) VALUES (10, 'enc.glamping2', 'Julian David Londono', 'julian.londono@turismouq.co', 'ENCARGADO_ALOJAMIENTO', 17);
COMMIT;

-- ---------------------------------------------------------------------
-- 9. RESERVA + RESERVA_HABITACION (~31.000 reservas, ~38.000 lineas)
--    Se recorre el calendario dia a dia (2024-01-01 .. 2026-12-31); cada
--    habitacion LIBRE ese dia puede iniciar una estadia con probabilidad
--    que depende de la temporada, el dia de la semana, el anio y la
--    popularidad del alojamiento. Como una habitacion solo inicia estadia
--    cuando esta libre, NUNCA hay solapes. El ~11% de las reservas son de
--    grupo: toman 2 a 4 habitaciones libres del mismo alojamiento y a
--    veces una linea llega un dia despues (fechas propias dentro del rango).
--    El valor_estadia se deja en 0 y se calcula en el paso 10.
-- ---------------------------------------------------------------------
DECLARE
  c_corte   CONSTANT DATE := DATE '2026-09-29';   -- "hoy" de los datos
  c_ini     CONSTANT DATE := DATE '2024-01-01';   -- lunes
  c_fin_in  CONSTANT DATE := DATE '2026-12-31';   -- ultimo check-in posible

  TYPE t_num  IS TABLE OF NUMBER      INDEX BY PLS_INTEGER;
  TYPE t_date IS TABLE OF DATE        INDEX BY PLS_INTEGER;
  TYPE t_niv  IS TABLE OF VARCHAR2(5) INDEX BY PLS_INTEGER;

  v_hab_id   t_num;    -- id de habitacion
  v_hab_alo  t_num;    -- id de alojamiento de esa habitacion
  v_hab_cap  t_num;    -- capacidad
  v_hab_pop  t_num;    -- popularidad del alojamiento
  v_libre    t_date;   -- primer dia en que la habitacion esta libre
  v_primera  t_num;    -- alojamiento -> primer indice de sus habitaciones
  v_ultima   t_num;    -- alojamiento -> ultimo indice de sus habitaciones
  v_nivel    t_niv;    -- indice de dia (0..) -> nivel de temporada

  v_dias     PLS_INTEGER := c_fin_in - c_ini;
  v_d        DATE;
  v_base     NUMBER;
  v_yf       NUMBER;
  v_fut      NUMBER;
  v_dow      NUMBER;
  v_pd       NUMBER;
  v_r        NUMBER;
  v_len      NUMBER;
  v_estado   VARCHAR2(10);
  v_creacion DATE;
  v_cancel   DATE;
  v_x        DATE;
  v_cli      NUMBER;
  v_res      NUMBER := 0;
  v_lin      NUMBER := 0;
  v_huesp    NUMBER;
  v_lin_in   DATE;
  v_k        PLS_INTEGER;
  v_n_ext    PLS_INTEGER;
  v_nh       PLS_INTEGER;
  v_off      PLS_INTEGER;
  v_j        PLS_INTEGER;
  v_alo      NUMBER;
BEGIN
  -- Calendario de temporadas en memoria: indice de dia -> nivel
  FOR t IN (SELECT nivel, fecha_inicio, fecha_fin FROM temporada) LOOP
    FOR k IN (GREATEST(t.fecha_inicio, c_ini) - c_ini) .. (LEAST(t.fecha_fin, c_fin_in) - c_ini) LOOP
      v_nivel(k) := t.nivel;
    END LOOP;
  END LOOP;

  -- Habitaciones en memoria (ordenadas por alojamiento)
  SELECT h.id_habitacion, h.id_alojamiento, h.capacidad, p.popularidad
    BULK COLLECT INTO v_hab_id, v_hab_alo, v_hab_cap, v_hab_pop
    FROM habitacion h
    JOIN stg_aloj_param p ON p.id_alojamiento = h.id_alojamiento
   ORDER BY h.id_alojamiento, h.id_habitacion;

  FOR i IN 1 .. v_hab_id.COUNT LOOP
    v_libre(i) := c_ini;
    IF NOT v_primera.EXISTS(v_hab_alo(i)) THEN
      v_primera(v_hab_alo(i)) := i;
    END IF;
    v_ultima(v_hab_alo(i)) := i;
  END LOOP;

  FOR k IN 0 .. v_dias LOOP
    v_d := c_ini + k;

    -- Demanda base del dia: temporada x anio x reservas futuras x dia de semana
    v_base := CASE v_nivel(k) WHEN 'ALTA' THEN 0.125 WHEN 'MEDIA' THEN 0.056 ELSE 0.025 END;
    v_yf   := CASE EXTRACT(YEAR FROM v_d) WHEN 2024 THEN 0.85 WHEN 2025 THEN 1.00 ELSE 1.10 END;
    v_fut  := CASE WHEN v_d > c_corte + 90 THEN 0.35 WHEN v_d > c_corte THEN 0.75 ELSE 1 END;
    v_dow  := CASE MOD(k, 7) WHEN 4 THEN 1.6 WHEN 5 THEN 1.4 WHEN 6 THEN 0.7 WHEN 3 THEN 1.0 ELSE 0.6 END;  -- 0 = lunes
    v_pd   := v_base * v_yf * v_fut * v_dow;

    FOR i IN 1 .. v_hab_id.COUNT LOOP
      IF v_libre(i) <= v_d THEN
        IF DBMS_RANDOM.VALUE < LEAST(0.95, v_pd * v_hab_pop(i)) THEN

          -- Duracion de la estadia (1 a 10 noches, sesgada a 2-3)
          v_r := DBMS_RANDOM.VALUE;
          v_len := CASE WHEN v_r < 0.12 THEN 1 WHEN v_r < 0.40 THEN 2 WHEN v_r < 0.68 THEN 3
                        WHEN v_r < 0.82 THEN 4 WHEN v_r < 0.90 THEN 5 WHEN v_r < 0.95 THEN 6
                        WHEN v_r < 0.98 THEN 7 ELSE 8 + TRUNC(DBMS_RANDOM.VALUE(0, 3)) END;
          v_libre(i) := v_d + v_len;
          v_alo := v_hab_alo(i);

          -- Estado segun la fecha de corte
          IF v_d + v_len <= c_corte THEN
            v_estado := CASE WHEN DBMS_RANDOM.VALUE < 0.86 THEN 'COMPLETADA' ELSE 'CANCELADA' END;
          ELSIF v_d <= c_corte THEN
            v_estado := 'CONFIRMADA';                      -- estadia en curso
          ELSE
            v_r := DBMS_RANDOM.VALUE;
            v_estado := CASE WHEN v_r < 0.75 THEN 'CONFIRMADA' WHEN v_r < 0.95 THEN 'PENDIENTE' ELSE 'CANCELADA' END;
          END IF;

          -- Fecha en que se creo la reserva
          IF v_d > c_corte THEN
            IF v_estado = 'PENDIENTE' THEN
              v_creacion := c_corte - TRUNC(DBMS_RANDOM.VALUE(0, 7));
            ELSE
              v_creacion := c_corte - TRUNC(DBMS_RANDOM.VALUE(0, 60));
            END IF;
          ELSE
            v_creacion := v_d - (1 + TRUNC(DBMS_RANDOM.VALUE(0, 90)));
          END IF;

          -- Fecha de cancelacion (35% muy cerca del check-in: 0 a 5 dias antes)
          IF v_estado = 'CANCELADA' THEN
            IF DBMS_RANDOM.VALUE < 0.35 THEN
              v_x := v_d - TRUNC(DBMS_RANDOM.VALUE(0, 6));
            ELSE
              v_x := v_d - (6 + TRUNC(DBMS_RANDOM.VALUE(0, 40)));
            END IF;
            v_cancel := LEAST(c_corte, GREATEST(v_creacion, v_x));
          ELSE
            v_cancel := NULL;
          END IF;

          -- Cliente: sesgo hacia ids bajos (clientes frecuentes)
          v_cli := 1 + TRUNC(POWER(DBMS_RANDOM.VALUE, 1.7) * 3000);

          v_res := v_res + 1;
          INSERT INTO reserva (id_reserva, id_cliente, id_alojamiento, fecha_creacion,
                               check_in, check_out, estado, fecha_cancelacion)
          VALUES (v_res, v_cli, v_alo, v_creacion, v_d, v_d + v_len, v_estado, v_cancel);

          -- Linea principal
          v_huesp := 1 + TRUNC(DBMS_RANDOM.VALUE * v_hab_cap(i));
          v_lin := v_lin + 1;
          INSERT INTO reserva_habitacion (id_reserva_hab, id_reserva, id_alojamiento, id_habitacion,
                                          check_in, check_out, num_huespedes, valor_estadia)
          VALUES (v_lin, v_res, v_alo, v_hab_id(i), v_d, v_d + v_len, v_huesp, 0);

          -- Reserva de grupo (~11%): habitaciones extra libres del mismo alojamiento
          IF DBMS_RANDOM.VALUE < 0.11 THEN
            v_k     := 1 + TRUNC(DBMS_RANDOM.VALUE(0, 3));          -- 1..3 habitaciones extra
            v_nh    := v_ultima(v_alo) - v_primera(v_alo) + 1;
            v_off   := TRUNC(DBMS_RANDOM.VALUE(0, v_nh));
            v_n_ext := 0;
            FOR o IN 0 .. v_nh - 1 LOOP
              EXIT WHEN v_n_ext >= v_k;
              v_j := v_primera(v_alo) + MOD(v_off + o, v_nh);
              IF v_j <> i AND v_libre(v_j) <= v_d THEN
                v_libre(v_j) := v_d + v_len;
                v_n_ext := v_n_ext + 1;
                -- a veces alguien del grupo llega un dia despues
                IF v_len >= 2 AND DBMS_RANDOM.VALUE < 0.25 THEN
                  v_lin_in := v_d + 1;
                ELSE
                  v_lin_in := v_d;
                END IF;
                v_huesp := 1 + TRUNC(DBMS_RANDOM.VALUE * v_hab_cap(v_j));
                v_lin := v_lin + 1;
                INSERT INTO reserva_habitacion (id_reserva_hab, id_reserva, id_alojamiento, id_habitacion,
                                                check_in, check_out, num_huespedes, valor_estadia)
                VALUES (v_lin, v_res, v_alo, v_hab_id(v_j), v_lin_in, v_d + v_len, v_huesp, 0);
              END IF;
            END LOOP;
          END IF;

        END IF;
      END IF;
    END LOOP;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('RESERVA cargadas: ' || v_res || ' | RESERVA_HABITACION cargadas: ' || v_lin);
END;
/

-- ---------------------------------------------------------------------
-- 10. valor_estadia de cada linea = suma, por cada temporada que toca la
--     estadia, de (noches dentro de esa temporada x tarifa de la habitacion
--     en esa temporada). Asi una estadia que cruza temporadas cobra cada
--     noche con la tarifa que le corresponde.
--     noches dentro de la temporada = LEAST(check_out, fecha_fin + 1) - GREATEST(check_in, fecha_inicio)
-- ---------------------------------------------------------------------
MERGE INTO reserva_habitacion rh
USING (SELECT x.id_reserva_hab,
              SUM((LEAST(x.check_out, t.fecha_fin + 1) - GREATEST(x.check_in, t.fecha_inicio)) * ta.valor_noche) AS valor
         FROM reserva_habitacion x
         JOIN temporada t ON x.check_in <= t.fecha_fin AND x.check_out > t.fecha_inicio
         JOIN tarifa ta   ON ta.id_habitacion = x.id_habitacion AND ta.id_temporada = t.id_temporada
        GROUP BY x.id_reserva_hab) v
   ON (rh.id_reserva_hab = v.id_reserva_hab)
 WHEN MATCHED THEN UPDATE SET rh.valor_estadia = v.valor;
COMMIT;

-- ---------------------------------------------------------------------
-- 11. RESERVA_SERVICIO (>= 40.000): ~75% de las reservas confirmadas o
--     completadas contratan de 1 a 5 lineas de servicios DE SU alojamiento.
-- ---------------------------------------------------------------------
DECLARE
  v_id     NUMBER := 0;
  v_n      PLS_INTEGER;
  v_srv    NUMBER;
  v_precio NUMBER;
  v_fecha  DATE;
BEGIN
  FOR r IN (SELECT id_reserva, id_alojamiento, check_in, check_out
              FROM reserva
             WHERE estado IN ('CONFIRMADA', 'COMPLETADA')
             ORDER BY id_reserva) LOOP
    IF DBMS_RANDOM.VALUE < 0.75 THEN
      v_n := 1 + TRUNC(DBMS_RANDOM.VALUE(0, 5));
      FOR k IN 1 .. v_n LOOP
        SELECT id_servicio, precio INTO v_srv, v_precio
          FROM (SELECT id_servicio, precio
                  FROM servicio
                 WHERE id_alojamiento = r.id_alojamiento
                 ORDER BY DBMS_RANDOM.VALUE)
         WHERE ROWNUM = 1;
        v_fecha := r.check_in + TRUNC(DBMS_RANDOM.VALUE(0, r.check_out - r.check_in));
        BEGIN
          INSERT INTO reserva_servicio (id_reserva_serv, id_reserva, id_alojamiento, id_servicio,
                                        fecha_servicio, cantidad, precio_unitario)
          VALUES (v_id + 1, r.id_reserva, r.id_alojamiento, v_srv, v_fecha,
                  1 + TRUNC(DBMS_RANDOM.VALUE(0, 4)), v_precio);
          v_id := v_id + 1;
        EXCEPTION
          WHEN DUP_VAL_ON_INDEX THEN NULL;   -- mismo servicio, mismo dia: se omite
        END;
      END LOOP;
    END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('RESERVA_SERVICIO cargadas: ' || v_id);
END;
/

-- ---------------------------------------------------------------------
-- 12. PAGO (>= 25.000): segun el estado de la reserva
--     COMPLETADA / en curso : pagada completa (55% un pago, 45% anticipo + saldo)
--     CONFIRMADA futura     : anticipo exitoso (+ saldo pendiente en 40%)
--     PENDIENTE             : intento pendiente o fallido (60%) o ninguno
--     CANCELADA             : anticipo exitoso (85%); si cancelo con MAS de
--                             5 dias de anticipacion se registra un pago
--                             REEMBOLSADO por el 80% de lo abonado
--     ~6% de los pagos completos tuvieron antes un intento FALLIDO.
-- ---------------------------------------------------------------------
DECLARE
  c_corte CONSTANT DATE := DATE '2026-09-29';
  v_id    NUMBER := 0;
  v_t     NUMBER;
  v_ant   NUMBER;

  FUNCTION f_metodo RETURN VARCHAR2 IS
    v_r NUMBER := DBMS_RANDOM.VALUE;
  BEGIN
    RETURN CASE WHEN v_r < 0.35 THEN 'TARJETA_CREDITO'
                WHEN v_r < 0.50 THEN 'TARJETA_DEBITO'
                WHEN v_r < 0.75 THEN 'PSE'
                WHEN v_r < 0.90 THEN 'TRANSFERENCIA'
                ELSE 'EFECTIVO' END;
  END;

  PROCEDURE p_pago(p_res NUMBER, p_fecha DATE, p_monto NUMBER, p_estado VARCHAR2) IS
    v_met VARCHAR2(20);
  BEGIN
    v_met := f_metodo;      -- una funcion local no puede llamarse dentro del INSERT (SQL)
    v_id := v_id + 1;
    INSERT INTO pago (id_pago, id_reserva, fecha_pago, monto, metodo, estado)
    VALUES (v_id, p_res, p_fecha, p_monto, v_met, p_estado);
  END;
BEGIN
  FOR r IN (SELECT rv.id_reserva, rv.estado, rv.fecha_creacion, rv.check_in, rv.fecha_cancelacion,
                   (SELECT NVL(SUM(rh.valor_estadia), 0) FROM reserva_habitacion rh WHERE rh.id_reserva = rv.id_reserva)
                 + (SELECT NVL(SUM(rs.cantidad * rs.precio_unitario), 0) FROM reserva_servicio rs WHERE rs.id_reserva = rv.id_reserva)
                   AS total
              FROM reserva rv
             ORDER BY rv.id_reserva) LOOP
    v_t := r.total;

    IF r.estado = 'COMPLETADA' OR (r.estado = 'CONFIRMADA' AND r.check_in <= c_corte) THEN
      IF DBMS_RANDOM.VALUE < 0.55 THEN
        IF DBMS_RANDOM.VALUE < 0.06 THEN
          p_pago(r.id_reserva, r.fecha_creacion, v_t, 'FALLIDO');
        END IF;
        p_pago(r.id_reserva, r.fecha_creacion, v_t, 'EXITOSO');
      ELSE
        v_ant := ROUND(v_t * DBMS_RANDOM.VALUE(0.30, 0.60), -3);
        p_pago(r.id_reserva, r.fecha_creacion, v_ant, 'EXITOSO');
        p_pago(r.id_reserva, r.check_in, v_t - v_ant, 'EXITOSO');
      END IF;

    ELSIF r.estado = 'CONFIRMADA' THEN
      v_ant := ROUND(v_t * DBMS_RANDOM.VALUE(0.30, 0.60), -3);
      p_pago(r.id_reserva, r.fecha_creacion, v_ant, 'EXITOSO');
      IF DBMS_RANDOM.VALUE < 0.40 THEN
        p_pago(r.id_reserva, r.check_in, v_t - v_ant, 'PENDIENTE');
      END IF;

    ELSIF r.estado = 'PENDIENTE' THEN
      IF DBMS_RANDOM.VALUE < 0.60 THEN
        p_pago(r.id_reserva, r.fecha_creacion, ROUND(v_t * 0.30, -3),
               CASE WHEN DBMS_RANDOM.VALUE < 0.5 THEN 'PENDIENTE' ELSE 'FALLIDO' END);
      END IF;

    ELSE  -- CANCELADA
      IF DBMS_RANDOM.VALUE < 0.85 THEN
        v_ant := ROUND(v_t * DBMS_RANDOM.VALUE(0.30, 0.50), -3);
        p_pago(r.id_reserva, r.fecha_creacion, v_ant, 'EXITOSO');
        IF r.check_in - r.fecha_cancelacion > 5 THEN
          p_pago(r.id_reserva, r.fecha_cancelacion, ROUND(v_ant * 0.80), 'REEMBOLSADO');
        END IF;
      END IF;
    END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('PAGO cargados: ' || v_id);
END;
/

-- ---------------------------------------------------------------------
-- 13. RESENA (~52% de las reservas COMPLETADAS): la calificacion gira en
--     torno a la calidad real del alojamiento (no a sus estrellas).
-- ---------------------------------------------------------------------
DECLARE
  TYPE t_txt IS TABLE OF VARCHAR2(120) INDEX BY PLS_INTEGER;
  v_com   t_txt;
  v_id    NUMBER := 0;
  v_cal   NUMBER;
  v_coment VARCHAR2(500);
BEGIN
  v_com(1)  := 'Muy mala experiencia, no lo recomiendo';
  v_com(2)  := 'La habitacion no coincidia con lo publicado';
  v_com(3)  := 'Servicio deficiente y mucho ruido';
  v_com(4)  := 'Podria mejorar bastante la atencion';
  v_com(5)  := 'Limpieza regular y demoras en el servicio';
  v_com(6)  := 'No cumplio con lo esperado';
  v_com(7)  := 'Cumple, sin grandes sorpresas';
  v_com(8)  := 'Buena ubicacion pero instalaciones basicas';
  v_com(9)  := 'Aceptable por el precio';
  v_com(10) := 'Muy buena atencion y lindo paisaje';
  v_com(11) := 'Habitaciones comodas y personal amable';
  v_com(12) := 'Buena experiencia, volveria';
  v_com(13) := 'Excelente lugar, todo perfecto';
  v_com(14) := 'Atencion de primera y desayuno delicioso';
  v_com(15) := 'Una experiencia inolvidable en el Eje Cafetero';

  FOR r IN (SELECT rv.id_reserva, rv.check_out, p.calidad
              FROM reserva rv
              JOIN stg_aloj_param p ON p.id_alojamiento = rv.id_alojamiento
             WHERE rv.estado = 'COMPLETADA'
             ORDER BY rv.id_reserva) LOOP
    IF DBMS_RANDOM.VALUE < 0.52 THEN
      v_cal := GREATEST(1, LEAST(5, ROUND(r.calidad + DBMS_RANDOM.VALUE(-1.5, 1.2))));
      IF DBMS_RANDOM.VALUE < 0.35 THEN
        v_coment := NULL;                                    -- comentario opcional
      ELSE
        v_coment := v_com((v_cal - 1) * 3 + 1 + TRUNC(DBMS_RANDOM.VALUE(0, 3)));
      END IF;
      v_id := v_id + 1;
      INSERT INTO resena (id_resena, id_reserva, estado_reserva, calificacion, comentario, fecha_resena)
      VALUES (v_id, r.id_reserva, 'COMPLETADA', v_cal, v_coment,
              LEAST(DATE '2026-09-29', r.check_out + 1 + TRUNC(DBMS_RANDOM.VALUE(0, 10))));
    END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('RESENA cargadas: ' || v_id);
END;
/

-- ---------------------------------------------------------------------
-- 14. Cierre: reiniciamos los IDENTITY para que sigan despues del ultimo id
--     cargado, borramos la tabla auxiliar y calculamos estadisticas.
-- ---------------------------------------------------------------------
BEGIN
  FOR c IN (SELECT table_name, column_name FROM user_tab_identity_cols) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'ALTER TABLE ' || c.table_name || ' MODIFY (' || c.column_name ||
                        ' GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE))';
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Aviso: no se pudo reiniciar el identity de ' || c.table_name || ': ' || SQLERRM);
    END;
  END LOOP;
END;
/

DROP TABLE stg_aloj_param PURGE;

BEGIN
  DBMS_STATS.GATHER_SCHEMA_STATS(ownname => USER);
END;
/

-- ---------------------------------------------------------------------
-- 15. VERIFICACION del volumen minimo (todas las filas deben decir OK)
-- ---------------------------------------------------------------------
SELECT tabla, minimo, cargado,
       CASE WHEN cargado >= minimo THEN 'OK' ELSE 'FALTA' END AS estado
FROM (
  SELECT 'MUNICIPIO'          AS tabla, 12     AS minimo, (SELECT COUNT(*) FROM municipio)          AS cargado FROM dual UNION ALL
  SELECT 'TIPO_ALOJAMIENTO'   , 4      , (SELECT COUNT(*) FROM tipo_alojamiento)   FROM dual UNION ALL
  SELECT 'ALOJAMIENTO'        , 60     , (SELECT COUNT(*) FROM alojamiento)        FROM dual UNION ALL
  SELECT 'HABITACION'         , 400    , (SELECT COUNT(*) FROM habitacion)         FROM dual UNION ALL
  SELECT 'TEMPORADA'          , 6      , (SELECT COUNT(*) FROM temporada)          FROM dual UNION ALL
  SELECT 'TARIFA (hab x temp)', (SELECT COUNT(*) FROM habitacion) * (SELECT COUNT(*) FROM temporada),
                                (SELECT COUNT(*) FROM tarifa)                      FROM dual UNION ALL
  SELECT 'CLIENTE'            , 3000   , (SELECT COUNT(*) FROM cliente)            FROM dual UNION ALL
  SELECT 'RESERVA'            , 25000  , (SELECT COUNT(*) FROM reserva)            FROM dual UNION ALL
  SELECT 'RESERVA_HABITACION' , 25000  , (SELECT COUNT(*) FROM reserva_habitacion) FROM dual UNION ALL
  SELECT 'PAGO'               , 25000  , (SELECT COUNT(*) FROM pago)               FROM dual UNION ALL
  SELECT 'SERVICIO'           , 30     , (SELECT COUNT(*) FROM servicio)           FROM dual UNION ALL
  SELECT 'RESERVA_SERVICIO'   , 40000  , (SELECT COUNT(*) FROM reserva_servicio)   FROM dual UNION ALL
  SELECT 'RESENA (>=40% compl.)', (SELECT CEIL(0.4 * COUNT(*)) FROM reserva WHERE estado = 'COMPLETADA'),
                                (SELECT COUNT(*) FROM resena)                      FROM dual UNION ALL
  SELECT 'USUARIO_SISTEMA'    , 10     , (SELECT COUNT(*) FROM usuario_sistema)    FROM dual
);

-- Controles de calidad de los datos (deben dar 0 / valores iguales):
-- a) huecos o solapes entre temporadas consecutivas
SELECT COUNT(*) AS temporadas_con_hueco_o_solape
FROM (SELECT fecha_inicio, LAG(fecha_fin) OVER (ORDER BY fecha_inicio) AS fin_previo FROM temporada)
WHERE fin_previo IS NOT NULL AND fecha_inicio <> fin_previo + 1;

-- b) lineas cuyas noches NO quedaron cubiertas por temporadas (debe ser 0)
SELECT COUNT(*) AS lineas_con_noches_sin_temporada
FROM (SELECT rh.id_reserva_hab,
             rh.check_out - rh.check_in AS noches,
             SUM(LEAST(rh.check_out, t.fecha_fin + 1) - GREATEST(rh.check_in, t.fecha_inicio)) AS cubiertas
        FROM reserva_habitacion rh
        JOIN temporada t ON rh.check_in <= t.fecha_fin AND rh.check_out > t.fecha_inicio
       GROUP BY rh.id_reserva_hab, rh.check_in, rh.check_out)
WHERE noches <> cubiertas;

-- c) lineas sin valor calculado
SELECT COUNT(*) AS lineas_sin_valor FROM reserva_habitacion WHERE valor_estadia = 0;

-- d) solapes de una misma habitacion (debe ser 0)
SELECT COUNT(*) AS solapes_de_habitacion
FROM reserva_habitacion a
JOIN reserva_habitacion b
  ON a.id_habitacion = b.id_habitacion
 AND a.id_reserva_hab < b.id_reserva_hab
 AND a.check_in < b.check_out
 AND b.check_in < a.check_out;

-- e) asimetria: reservas por municipio (deben ser muy desiguales)
SELECT m.nombre AS municipio, COUNT(DISTINCT a.id_alojamiento) AS alojamientos, COUNT(*) AS reservas
FROM reserva r
JOIN alojamiento a ON a.id_alojamiento = r.id_alojamiento
JOIN municipio m   ON m.id_municipio = a.id_municipio
GROUP BY m.nombre
ORDER BY reservas DESC;