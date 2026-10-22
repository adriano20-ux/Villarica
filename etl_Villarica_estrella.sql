CREATE TABLE DimFecha (
    id_fecha INT PRIMARY KEY,
    fecha DATE,
    dia INT,
    mes INT,
    nombre_mes VARCHAR(20),
    trimestre INT,
    anio INT
)
CREATE TABLE DimProducto (
    id_producto INT PRIMARY KEY,
    nombre_producto VARCHAR(50),
    categoria VARCHAR(50),
    precio DECIMAL(5,2),
    estado VARCHAR(13)
)
CREATE TABLE DimEmpleado (
    id_empleado INT PRIMARY KEY,
    nombre VARCHAR(50),
    apellido VARCHAR(50),
    cargo VARCHAR(30)
)
CREATE TABLE DimMetodoPago (
    id_metodo_pago INT PRIMARY KEY,
    nombre_metodo VARCHAR(30)
)
CREATE TABLE DimHora (
    id_hora INT PRIMARY KEY,
    hora_numero INT,
    turno VARCHAR(20)
)
CREATE TABLE FactVenta (
    id_fact_venta INT IDENTITY(1,1) PRIMARY KEY,

    id_venta INT,
    id_fecha INT,
    id_producto INT,
    id_empleado INT,
    id_metodo_pago INT,
    id_hora INT,

    cantidad_vendida INT,
    importe_venta DECIMAL(10,2),

    FOREIGN KEY (id_fecha)
        REFERENCES DimFecha(id_fecha),

    FOREIGN KEY (id_producto)
        REFERENCES DimProducto(id_producto),

    FOREIGN KEY (id_empleado)
        REFERENCES DimEmpleado(id_empleado),

    FOREIGN KEY (id_metodo_pago)
        REFERENCES DimMetodoPago(id_metodo_pago),

    FOREIGN KEY (id_hora)
        REFERENCES DimHora(id_hora)
)
-----------CARGAR DOMENSIONES-----------
INSERT INTO DimProducto
(
    id_producto,
    nombre_producto,
    categoria,
    precio,
    estado
)
SELECT
    p.id_producto,
    p.nombre_producto,
    c.nombre_categoria,
    p.precio,
    p.estado
FROM Villarica.dbo.Producto p
INNER JOIN Villarica.dbo.Categoria c
    ON p.id_categoria = c.id_categoria
-----------------------------------------
INSERT INTO DimEmpleado
(
    id_empleado,
    nombre,
    apellido,
    cargo
)
SELECT
    id_empleado,
    nombre,
    apellido,
    cargo
FROM Villarica.dbo.Empleado
--------------------------------------
INSERT INTO DimMetodoPago
(
    id_metodo_pago,
    nombre_metodo
)
SELECT
    id_metodo_pago,
    nombre_metodo
FROM Villarica.dbo.MetodoPago
---------------------------
INSERT INTO DimFecha
(
    id_fecha,
    fecha,
    dia,
    mes,
    nombre_mes,
    trimestre,
    anio
)
SELECT DISTINCT
    CONVERT(INT, FORMAT(fecha, 'yyyyMMdd')),
    fecha,
    DAY(fecha),
    MONTH(fecha),
    DATENAME(MONTH, fecha),
    DATEPART(QUARTER, fecha),
    YEAR(fecha)
FROM Villarica.dbo.Venta
----------------------------
INSERT INTO DimHora
(
    id_hora,
    hora_numero,
    turno
)
SELECT
    h.hora_numero,
    h.hora_numero,
    CASE
        WHEN h.hora_numero < 12 THEN 'Mañana'
        WHEN h.hora_numero < 18 THEN 'Tarde'
        ELSE 'Noche'
    END
FROM
(
    SELECT DISTINCT
        DATEPART(HOUR, hora) AS hora_numero
    FROM Villarica.dbo.Venta
) h
----------------------------
INSERT INTO FactVenta
(
    id_venta,
    id_fecha,
    id_producto,
    id_empleado,
    id_metodo_pago,
    id_hora,
    cantidad_vendida,
    importe_venta
)
SELECT
    v.id_venta,

    CONVERT(INT, FORMAT(v.fecha, 'yyyyMMdd'))fecha,

    dv.id_producto,

    v.id_empleado,

    v.id_metodo_pago,

    DATEPART(HOUR, v.hora)hora,

    dv.cantidad,

    dv.subtotal

FROM Villarica.dbo.Venta v
INNER JOIN Villarica.dbo.DetalleVenta dv
    ON v.id_venta = dv.id_venta
-----------------
SELECT * FROM Producto

SELECT * FROM Venta

SELECT *FROM DetalleVenta

SELECT * FROM Categoria

SELECT * FROM MetodoPago

SELECT * FROM Empleado
-------------
SELECT
    COUNT(*) AS registros_factventa,
    SUM(cantidad_vendida) AS productos_vendidos,
    SUM(importe_venta) AS importe_total
FROM FactVenta;