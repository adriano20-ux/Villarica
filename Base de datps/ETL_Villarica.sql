/* =====================================================================
   SCRIPT 3 - ETL (Extract - Transform - Load) dentro de la base Villarica
   ---------------------------------------------------------------------
   Requisito: haber ejecutado 01_Villarica_BD.sql y
              02_Villarica_esquema_estrella.sql
   Este script contiene SOLO el proceso ETL (no crea el esquema estrella)
   y se puede ejecutar de forma independiente todas las veces que se
   necesite: vacia las tablas estrella y las vuelve a cargar.

   E (Extract)   : copia cruda de las tablas operacionales (dbo) hacia
                   tablas de paso (staging) en el esquema [stg].
   T (Transform) : limpieza y validacion de datos sobre el staging:
                     - quitar espacios, tabs y espacios dobles
                     - estandarizar mayusculas/minusculas en nombres
                     - valores nulos -> valores por defecto
                     - eliminar registros duplicados
                     - estandarizar el campo estado
                     - precios negativos -> NULL
                     - recalcular precio_venta y subtotal incorrectos
                     - rechazar ventas/detalles invalidos (fecha nula,
                       empleado/metodo/producto inexistente, cantidad<=0)
                   Todo queda registrado en [etl].[LogCalidad].
   L (Load)      : carga dimensiones y tabla de hechos con datos limpios.
   ===================================================================== */

USE Villarica;
GO

IF SCHEMA_ID('stg') IS NULL EXEC('CREATE SCHEMA stg');
IF SCHEMA_ID('etl') IS NULL EXEC('CREATE SCHEMA etl');
GO

/* ---------------------------------------------------------------------
   0. OBJETOS AUXILIARES DE LIMPIEZA
   --------------------------------------------------------------------- */

-- Tabla de auditoria de calidad de datos
IF OBJECT_ID('etl.LogCalidad') IS NULL
CREATE TABLE etl.LogCalidad (
    id_log        INT IDENTITY(1,1) PRIMARY KEY,
    fecha_proceso DATETIME     NOT NULL DEFAULT GETDATE(),
    tipo          VARCHAR(12)  NOT NULL,   -- CORRECCION / RECHAZO / ADVERTENCIA
    tabla         VARCHAR(30)  NOT NULL,
    id_registro   VARCHAR(30)  NULL,
    detalle       VARCHAR(300) NULL
);
GO

-- Limpia texto: quita tabs, saltos de linea, espacios no separables,
-- espacios al inicio/fin y espacios repetidos. Cadena vacia -> NULL
DROP FUNCTION IF EXISTS etl.fn_LimpiarTexto;
GO
CREATE FUNCTION etl.fn_LimpiarTexto (@t VARCHAR(200))
RETURNS VARCHAR(200)
AS
BEGIN
    IF @t IS NULL RETURN NULL;
    SET @t = REPLACE(REPLACE(REPLACE(@t, CHAR(9), ' '), CHAR(10), ' '), CHAR(13), ' ');
    SET @t = REPLACE(@t, CHAR(160), ' ');
    SET @t = LTRIM(RTRIM(@t));
    SET @t = REPLACE(REPLACE(REPLACE(@t, ' ', '<>'), '><', ''), '<>', ' ');
    RETURN NULLIF(@t, '');
END;
GO

-- Nombre propio: primera letra de cada palabra en mayuscula, resto minuscula
DROP FUNCTION IF EXISTS etl.fn_NombrePropio;
GO
CREATE FUNCTION etl.fn_NombrePropio (@t VARCHAR(200))
RETURNS VARCHAR(200)
AS
BEGIN
    SET @t = etl.fn_LimpiarTexto(@t);
    IF @t IS NULL RETURN NULL;

    DECLARE @r VARCHAR(200) = '', @i INT = 1, @c CHAR(1), @prev CHAR(1) = ' ';
    WHILE @i <= LEN(@t)
    BEGIN
        SET @c = SUBSTRING(@t, @i, 1);
        SET @r = @r + CASE WHEN @prev = ' ' THEN UPPER(@c) ELSE LOWER(@c) END;
        SET @prev = @c;
        SET @i += 1;
    END;
    RETURN @r;
END;
GO

-- Estandariza el estado del producto
DROP FUNCTION IF EXISTS etl.fn_Estado;
GO
CREATE FUNCTION etl.fn_Estado (@e VARCHAR(50))
RETURNS VARCHAR(13)
AS
BEGIN
    DECLARE @x VARCHAR(50) = LOWER(etl.fn_LimpiarTexto(@e));
    RETURN CASE
        WHEN @x IN ('activo', 'act', 'a', '1')       THEN 'Activo'
        WHEN @x IN ('inactivo', 'inact', 'i', '0')   THEN 'Inactivo'
        ELSE 'Sin definir'
    END;
END;
GO

-- Compara dos textos distinguiendo mayusculas y espacios (para el log)
DROP FUNCTION IF EXISTS etl.fn_Distinto;
GO
CREATE FUNCTION etl.fn_Distinto (@a VARCHAR(200), @b VARCHAR(200))
RETURNS BIT
AS
BEGIN
    RETURN CASE
        WHEN @a IS NULL AND @b IS NULL THEN 0
        WHEN @a IS NULL OR  @b IS NULL THEN 1
        WHEN DATALENGTH(@a) <> DATALENGTH(@b) THEN 1
        WHEN @a COLLATE Latin1_General_BIN2 <> @b COLLATE Latin1_General_BIN2 THEN 1
        ELSE 0
    END;
END;
GO

/* ---------------------------------------------------------------------
   0.1 REINICIAR TABLAS ESTRELLA Y LOG (para poder re-ejecutar el ETL)
   --------------------------------------------------------------------- */
DELETE FROM dbo.FactVenta;
DELETE FROM dbo.DimFecha;
DELETE FROM dbo.DimProducto;
DELETE FROM dbo.DimEmpleado;
DELETE FROM dbo.DimMetodoPago;
DELETE FROM dbo.DimHora;
DBCC CHECKIDENT ('dbo.FactVenta', RESEED, 0) WITH NO_INFOMSGS;
DELETE FROM etl.LogCalidad;
GO


/* =====================================================================
   E - EXTRACT : copia cruda de Villarica hacia el esquema stg
   Se agregan las columnas valido / motivo_rechazo a Venta y DetalleVenta
   ===================================================================== */
DROP TABLE IF EXISTS stg.DetalleVenta;
DROP TABLE IF EXISTS stg.Venta;
DROP TABLE IF EXISTS stg.Producto;
DROP TABLE IF EXISTS stg.Categoria;
DROP TABLE IF EXISTS stg.Empleado;
DROP TABLE IF EXISTS stg.MetodoPago;

SELECT * INTO stg.Categoria  FROM dbo.Categoria;
SELECT * INTO stg.Producto   FROM dbo.Producto;
SELECT * INTO stg.Empleado   FROM dbo.Empleado;
SELECT * INTO stg.MetodoPago FROM dbo.MetodoPago;

SELECT *, CAST(1 AS BIT) AS valido, CAST(NULL AS VARCHAR(100)) AS motivo_rechazo
INTO stg.Venta FROM dbo.Venta;

SELECT *, CAST(1 AS BIT) AS valido, CAST(NULL AS VARCHAR(100)) AS motivo_rechazo
INTO stg.DetalleVenta FROM dbo.DetalleVenta;
GO


/* =====================================================================
   T - TRANSFORM : limpieza y validacion sobre el staging
   ===================================================================== */

/* ---- T.1 Eliminar registros duplicados (se conserva el primero) ---- */
;WITH d AS (SELECT id_categoria, ROW_NUMBER() OVER (PARTITION BY id_categoria ORDER BY (SELECT 1)) rn FROM stg.Categoria)
DELETE FROM d
OUTPUT 'RECHAZO', 'Categoria', CAST(deleted.id_categoria AS VARCHAR(30)), 'Registro duplicado'
INTO etl.LogCalidad (tipo, tabla, id_registro, detalle)
WHERE rn > 1;

;WITH d AS (SELECT id_producto, ROW_NUMBER() OVER (PARTITION BY id_producto ORDER BY (SELECT 1)) rn FROM stg.Producto)
DELETE FROM d
OUTPUT 'RECHAZO', 'Producto', CAST(deleted.id_producto AS VARCHAR(30)), 'Registro duplicado'
INTO etl.LogCalidad (tipo, tabla, id_registro, detalle)
WHERE rn > 1;

;WITH d AS (SELECT id_empleado, ROW_NUMBER() OVER (PARTITION BY id_empleado ORDER BY (SELECT 1)) rn FROM stg.Empleado)
DELETE FROM d
OUTPUT 'RECHAZO', 'Empleado', CAST(deleted.id_empleado AS VARCHAR(30)), 'Registro duplicado'
INTO etl.LogCalidad (tipo, tabla, id_registro, detalle)
WHERE rn > 1;

;WITH d AS (SELECT id_metodo_pago, ROW_NUMBER() OVER (PARTITION BY id_metodo_pago ORDER BY (SELECT 1)) rn FROM stg.MetodoPago)
DELETE FROM d
OUTPUT 'RECHAZO', 'MetodoPago', CAST(deleted.id_metodo_pago AS VARCHAR(30)), 'Registro duplicado'
INTO etl.LogCalidad (tipo, tabla, id_registro, detalle)
WHERE rn > 1;

;WITH d AS (SELECT id_venta, ROW_NUMBER() OVER (PARTITION BY id_venta ORDER BY (SELECT 1)) rn FROM stg.Venta)
DELETE FROM d
OUTPUT 'RECHAZO', 'Venta', CAST(deleted.id_venta AS VARCHAR(30)), 'Registro duplicado'
INTO etl.LogCalidad (tipo, tabla, id_registro, detalle)
WHERE rn > 1;

;WITH d AS (SELECT id_detalle, ROW_NUMBER() OVER (PARTITION BY id_detalle ORDER BY (SELECT 1)) rn FROM stg.DetalleVenta)
DELETE FROM d
OUTPUT 'RECHAZO', 'DetalleVenta', CAST(deleted.id_detalle AS VARCHAR(30)), 'Registro duplicado'
INTO etl.LogCalidad (tipo, tabla, id_registro, detalle)
WHERE rn > 1;


/* ---- T.2 Categoria: espacios y nulos ---- */
UPDATE stg.Categoria
SET nombre_categoria = ISNULL(etl.fn_LimpiarTexto(nombre_categoria), 'Sin categoría')
OUTPUT 'CORRECCION', 'Categoria', CAST(inserted.id_categoria AS VARCHAR(30)),
       'nombre_categoria: [' + ISNULL(deleted.nombre_categoria, 'NULL') + '] -> [' + inserted.nombre_categoria + ']'
INTO etl.LogCalidad (tipo, tabla, id_registro, detalle)
WHERE etl.fn_Distinto(nombre_categoria, ISNULL(etl.fn_LimpiarTexto(nombre_categoria), 'Sin categoría')) = 1;


/* ---- T.3 Producto: nombre, estado y precio ---- */
UPDATE stg.Producto
SET nombre_producto = ISNULL(etl.fn_LimpiarTexto(nombre_producto), 'Sin nombre')
OUTPUT 'CORRECCION', 'Producto', CAST(inserted.id_producto AS VARCHAR(30)),
       'nombre_producto: [' + ISNULL(deleted.nombre_producto, 'NULL') + '] -> [' + inserted.nombre_producto + ']'
INTO etl.LogCalidad (tipo, tabla, id_registro, detalle)
WHERE etl.fn_Distinto(nombre_producto, ISNULL(etl.fn_LimpiarTexto(nombre_producto), 'Sin nombre')) = 1;

UPDATE stg.Producto
SET estado = etl.fn_Estado(estado)
OUTPUT 'CORRECCION', 'Producto', CAST(inserted.id_producto AS VARCHAR(30)),
       'estado: [' + ISNULL(deleted.estado, 'NULL') + '] -> [' + inserted.estado + ']'
INTO etl.LogCalidad (tipo, tabla, id_registro, detalle)
WHERE etl.fn_Distinto(estado, etl.fn_Estado(estado)) = 1;

UPDATE stg.Producto
SET precio = NULL
OUTPUT 'CORRECCION', 'Producto', CAST(inserted.id_producto AS VARCHAR(30)),
       'precio negativo [' + CAST(deleted.precio AS VARCHAR(20)) + '] -> NULL'
INTO etl.LogCalidad (tipo, tabla, id_registro, detalle)
WHERE precio < 0;


/* ---- T.4 Empleado: nombres propios, cargo y nulos ---- */
UPDATE stg.Empleado
SET nombre = ISNULL(etl.fn_NombrePropio(nombre), 'Sin nombre')
OUTPUT 'CORRECCION', 'Empleado', CAST(inserted.id_empleado AS VARCHAR(30)),
       'nombre: [' + ISNULL(deleted.nombre, 'NULL') + '] -> [' + inserted.nombre + ']'
INTO etl.LogCalidad (tipo, tabla, id_registro, detalle)
WHERE etl.fn_Distinto(nombre, ISNULL(etl.fn_NombrePropio(nombre), 'Sin nombre')) = 1;

UPDATE stg.Empleado
SET apellido = ISNULL(etl.fn_NombrePropio(apellido), 'Sin apellido')
OUTPUT 'CORRECCION', 'Empleado', CAST(inserted.id_empleado AS VARCHAR(30)),
       'apellido: [' + ISNULL(deleted.apellido, 'NULL') + '] -> [' + inserted.apellido + ']'
INTO etl.LogCalidad (tipo, tabla, id_registro, detalle)
WHERE etl.fn_Distinto(apellido, ISNULL(etl.fn_NombrePropio(apellido), 'Sin apellido')) = 1;

UPDATE stg.Empleado
SET cargo = ISNULL(etl.fn_LimpiarTexto(cargo), 'Sin cargo')
OUTPUT 'CORRECCION', 'Empleado', CAST(inserted.id_empleado AS VARCHAR(30)),
       'cargo: [' + ISNULL(deleted.cargo, 'NULL') + '] -> [' + inserted.cargo + ']'
INTO etl.LogCalidad (tipo, tabla, id_registro, detalle)
WHERE etl.fn_Distinto(cargo, ISNULL(etl.fn_LimpiarTexto(cargo), 'Sin cargo')) = 1;


/* ---- T.5 MetodoPago ---- */
UPDATE stg.MetodoPago
SET nombre_metodo = ISNULL(etl.fn_NombrePropio(nombre_metodo), 'No especificado')
OUTPUT 'CORRECCION', 'MetodoPago', CAST(inserted.id_metodo_pago AS VARCHAR(30)),
       'nombre_metodo: [' + ISNULL(deleted.nombre_metodo, 'NULL') + '] -> [' + inserted.nombre_metodo + ']'
INTO etl.LogCalidad (tipo, tabla, id_registro, detalle)
WHERE etl.fn_Distinto(nombre_metodo, ISNULL(etl.fn_NombrePropio(nombre_metodo), 'No especificado')) = 1;


/* ---- T.6 Venta: validar campos obligatorios y llaves ---- */
UPDATE stg.Venta
SET valido = 0, motivo_rechazo = 'id_venta nulo'
WHERE valido = 1 AND id_venta IS NULL;

UPDATE stg.Venta
SET valido = 0, motivo_rechazo = 'Fecha nula o fuera de rango'
WHERE valido = 1 AND (fecha IS NULL OR fecha NOT BETWEEN '20000101' AND '20991231');

UPDATE stg.Venta
SET valido = 0, motivo_rechazo = 'Hora nula'
WHERE valido = 1 AND hora IS NULL;

UPDATE v
SET valido = 0, motivo_rechazo = 'Empleado nulo o inexistente'
FROM stg.Venta v
WHERE v.valido = 1
  AND NOT EXISTS (SELECT 1 FROM stg.Empleado e WHERE e.id_empleado = v.id_empleado);

UPDATE v
SET valido = 0, motivo_rechazo = 'Metodo de pago nulo o inexistente'
FROM stg.Venta v
WHERE v.valido = 1
  AND NOT EXISTS (SELECT 1 FROM stg.MetodoPago m WHERE m.id_metodo_pago = v.id_metodo_pago);

INSERT INTO etl.LogCalidad (tipo, tabla, id_registro, detalle)
SELECT 'RECHAZO', 'Venta', CAST(id_venta AS VARCHAR(30)), motivo_rechazo
FROM stg.Venta
WHERE valido = 0;


/* ---- T.7 DetalleVenta: corregir precio y subtotal ---- */
-- precio_venta nulo o negativo -> precio del catalogo
UPDATE dv
SET precio_venta = p.precio
OUTPUT 'CORRECCION', 'DetalleVenta', CAST(inserted.id_detalle AS VARCHAR(30)),
       'precio_venta: [' + ISNULL(CAST(deleted.precio_venta AS VARCHAR(20)), 'NULL') + '] -> ['
       + CAST(inserted.precio_venta AS VARCHAR(20)) + '] (precio de catalogo)'
INTO etl.LogCalidad (tipo, tabla, id_registro, detalle)
FROM stg.DetalleVenta dv
INNER JOIN stg.Producto p ON p.id_producto = dv.id_producto
WHERE (dv.precio_venta IS NULL OR dv.precio_venta < 0)
  AND p.precio IS NOT NULL;

-- subtotal nulo o distinto de cantidad * precio_venta -> recalcular
UPDATE stg.DetalleVenta
SET subtotal = cantidad * precio_venta
OUTPUT 'CORRECCION', 'DetalleVenta', CAST(inserted.id_detalle AS VARCHAR(30)),
       'subtotal: [' + ISNULL(CAST(deleted.subtotal AS VARCHAR(20)), 'NULL') + '] -> ['
       + CAST(inserted.subtotal AS VARCHAR(20)) + '] (cantidad x precio_venta)'
INTO etl.LogCalidad (tipo, tabla, id_registro, detalle)
WHERE cantidad > 0 AND precio_venta >= 0
  AND (subtotal IS NULL OR ABS(subtotal - cantidad * precio_venta) > 0.001);


/* ---- T.8 DetalleVenta: validar llaves y valores ---- */
UPDATE stg.DetalleVenta
SET valido = 0, motivo_rechazo = 'id_detalle nulo'
WHERE valido = 1 AND id_detalle IS NULL;

UPDATE dv
SET valido = 0, motivo_rechazo = 'Venta nula, inexistente o rechazada'
FROM stg.DetalleVenta dv
WHERE dv.valido = 1
  AND NOT EXISTS (SELECT 1 FROM stg.Venta v WHERE v.id_venta = dv.id_venta AND v.valido = 1);

UPDATE dv
SET valido = 0, motivo_rechazo = 'Producto nulo o inexistente'
FROM stg.DetalleVenta dv
WHERE dv.valido = 1
  AND NOT EXISTS (SELECT 1 FROM stg.Producto p WHERE p.id_producto = dv.id_producto);

UPDATE stg.DetalleVenta
SET valido = 0, motivo_rechazo = 'Cantidad nula o menor/igual a cero'
WHERE valido = 1 AND (cantidad IS NULL OR cantidad <= 0);

UPDATE stg.DetalleVenta
SET valido = 0, motivo_rechazo = 'Precio de venta nulo o negativo'
WHERE valido = 1 AND (precio_venta IS NULL OR precio_venta < 0);

UPDATE stg.DetalleVenta
SET valido = 0, motivo_rechazo = 'Subtotal nulo'
WHERE valido = 1 AND subtotal IS NULL;

INSERT INTO etl.LogCalidad (tipo, tabla, id_registro, detalle)
SELECT 'RECHAZO', 'DetalleVenta', CAST(id_detalle AS VARCHAR(30)), motivo_rechazo
FROM stg.DetalleVenta
WHERE valido = 0;


/* ---- T.9 Advertencia: total de la venta distinto a la suma de sus detalles ---- */
INSERT INTO etl.LogCalidad (tipo, tabla, id_registro, detalle)
SELECT 'ADVERTENCIA', 'Venta', CAST(v.id_venta AS VARCHAR(30)),
       'total registrado [' + ISNULL(CAST(v.total AS VARCHAR(20)), 'NULL') + '] <> suma de detalles ['
       + CAST(s.suma AS VARCHAR(20)) + ']'
FROM stg.Venta v
INNER JOIN (SELECT id_venta, SUM(subtotal) AS suma
            FROM stg.DetalleVenta WHERE valido = 1
            GROUP BY id_venta) s ON s.id_venta = v.id_venta
WHERE v.valido = 1
  AND (v.total IS NULL OR ABS(v.total - s.suma) > 0.01);
GO

/* =====================================================================
   L - LOAD : carga desde los datos limpios del esquema stg
   ===================================================================== */

/* ---- Dimensiones ---- */
INSERT INTO dbo.DimProducto (id_producto, nombre_producto, categoria, precio, estado)
SELECT p.id_producto,
       p.nombre_producto,
       ISNULL(c.nombre_categoria, 'Sin categoría'),
       p.precio,
       p.estado
FROM stg.Producto p
LEFT JOIN stg.Categoria c ON c.id_categoria = p.id_categoria;

INSERT INTO dbo.DimEmpleado (id_empleado, nombre, apellido, cargo)
SELECT id_empleado, nombre, apellido, cargo
FROM stg.Empleado;

INSERT INTO dbo.DimMetodoPago (id_metodo_pago, nombre_metodo)
SELECT id_metodo_pago, nombre_metodo
FROM stg.MetodoPago;

INSERT INTO dbo.DimFecha (id_fecha, fecha, dia, mes, nombre_mes, trimestre, anio)
SELECT DISTINCT
    CONVERT(INT, CONVERT(CHAR(8), fecha, 112)),
    fecha,
    DAY(fecha),
    MONTH(fecha),
    CASE MONTH(fecha)
        WHEN 1 THEN 'Enero'    WHEN 2 THEN 'Febrero'   WHEN 3 THEN 'Marzo'
        WHEN 4 THEN 'Abril'    WHEN 5 THEN 'Mayo'      WHEN 6 THEN 'Junio'
        WHEN 7 THEN 'Julio'    WHEN 8 THEN 'Agosto'    WHEN 9 THEN 'Septiembre'
        WHEN 10 THEN 'Octubre' WHEN 11 THEN 'Noviembre' WHEN 12 THEN 'Diciembre'
    END,
    DATEPART(QUARTER, fecha),
    YEAR(fecha)
FROM stg.Venta
WHERE valido = 1;

INSERT INTO dbo.DimHora (id_hora, hora_numero, turno)
SELECT h.hora_numero,
       h.hora_numero,
       CASE
           WHEN h.hora_numero < 12 THEN 'Mañana'
           WHEN h.hora_numero < 18 THEN 'Tarde'
           ELSE 'Noche'
       END
FROM (SELECT DISTINCT DATEPART(HOUR, hora) AS hora_numero
      FROM stg.Venta
      WHERE valido = 1) h;

/* ---- Tabla de hechos ---- */
INSERT INTO dbo.FactVenta
    (id_venta, id_fecha, id_producto, id_empleado, id_metodo_pago, id_hora,
     cantidad_vendida, importe_venta)
SELECT
    v.id_venta,
    CONVERT(INT, CONVERT(CHAR(8), v.fecha, 112)),
    dv.id_producto,
    v.id_empleado,
    v.id_metodo_pago,
    DATEPART(HOUR, v.hora),
    dv.cantidad,
    dv.subtotal
FROM stg.Venta v
INNER JOIN stg.DetalleVenta dv ON dv.id_venta = v.id_venta
WHERE v.valido = 1
  AND dv.valido = 1;
GO


/* =====================================================================
   VALIDACION DEL ETL
   ===================================================================== */

-- Resumen de calidad de datos (correcciones, rechazos, advertencias)
SELECT tipo, tabla, COUNT(*) AS cantidad
FROM etl.LogCalidad
GROUP BY tipo, tabla
ORDER BY tipo, tabla;

-- Detalle del log
SELECT * FROM etl.LogCalidad ORDER BY id_log;

-- Conciliacion origen vs. DW
SELECT 'Detalles en origen (Villarica)' AS control,
       COUNT(*) AS registros, SUM(subtotal) AS importe
FROM dbo.DetalleVenta
UNION ALL
SELECT 'Detalles rechazados en la limpieza',
       COUNT(*), SUM(subtotal)
FROM stg.DetalleVenta WHERE valido = 0
UNION ALL
SELECT 'Registros cargados en FactVenta',
       COUNT(*), SUM(importe_venta)
FROM dbo.FactVenta;

-- Resumen de la tabla de hechos
SELECT COUNT(*)              AS registros_factventa,
       SUM(cantidad_vendida) AS productos_vendidos,
       SUM(importe_venta)    AS importe_total
FROM dbo.FactVenta;

-- Consulta de ejemplo sobre el modelo estrella
SELECT f.anio, f.nombre_mes, p.categoria,
       SUM(fv.cantidad_vendida) AS unidades,
       SUM(fv.importe_venta)    AS importe
FROM dbo.FactVenta fv
INNER JOIN dbo.DimFecha    f ON f.id_fecha    = fv.id_fecha
INNER JOIN dbo.DimProducto p ON p.id_producto = fv.id_producto
GROUP BY f.anio, f.nombre_mes, p.categoria
ORDER BY importe DESC;
GO
