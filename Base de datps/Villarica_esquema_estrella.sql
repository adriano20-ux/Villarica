/* =====================================================================
   SCRIPT 2 - ESQUEMA ESTRELLA (DDL) en la base Villarica
   ---------------------------------------------------------------------
   Requisito: haber ejecutado 01_Villarica_BD.sql
   Solo define la ESTRUCTURA: dimensiones y tabla de hechos (vacias).
   La carga de datos la realiza 03_ETL_Villarica.sql

   Granularidad de FactVenta: una fila por producto vendido en cada venta
   (equivale a una fila de DetalleVenta).
   ===================================================================== */

USE Villarica;
GO

/* =====================================================================
   ESQUEMA ESTRELLA (DDL)
   ===================================================================== */

-- Eliminar tablas si existen (hechos primero por las llaves foraneas)
DROP TABLE IF EXISTS dbo.FactVenta;
DROP TABLE IF EXISTS dbo.DimFecha;
DROP TABLE IF EXISTS dbo.DimProducto;
DROP TABLE IF EXISTS dbo.DimEmpleado;
DROP TABLE IF EXISTS dbo.DimMetodoPago;
DROP TABLE IF EXISTS dbo.DimHora;
GO

-- DIMENSIONES
CREATE TABLE dbo.DimFecha (
    id_fecha    INT         NOT NULL PRIMARY KEY,   -- formato yyyyMMdd
    fecha       DATE        NOT NULL,
    dia         INT         NOT NULL,
    mes         INT         NOT NULL,
    nombre_mes  VARCHAR(20) NOT NULL,
    trimestre   INT         NOT NULL,
    anio        INT         NOT NULL
);

CREATE TABLE dbo.DimProducto (
    id_producto     INT          NOT NULL PRIMARY KEY,
    nombre_producto VARCHAR(50)  NOT NULL,
    categoria       VARCHAR(50)  NOT NULL,
    precio          DECIMAL(5,2) NULL,
    estado          VARCHAR(13)  NOT NULL
);

CREATE TABLE dbo.DimEmpleado (
    id_empleado INT         NOT NULL PRIMARY KEY,
    nombre      VARCHAR(50) NOT NULL,
    apellido    VARCHAR(50) NOT NULL,
    cargo       VARCHAR(30) NOT NULL
);

CREATE TABLE dbo.DimMetodoPago (
    id_metodo_pago INT         NOT NULL PRIMARY KEY,
    nombre_metodo  VARCHAR(30) NOT NULL
);

CREATE TABLE dbo.DimHora (
    id_hora     INT         NOT NULL PRIMARY KEY,   -- 0 a 23
    hora_numero INT         NOT NULL,
    turno       VARCHAR(20) NOT NULL
);
GO

-- TABLA DE HECHOS
CREATE TABLE dbo.FactVenta (
    id_fact_venta    INT IDENTITY(1,1) PRIMARY KEY,

    id_venta         INT NOT NULL,      -- dimension degenerada
    id_fecha         INT NOT NULL,
    id_producto      INT NOT NULL,
    id_empleado      INT NOT NULL,
    id_metodo_pago   INT NOT NULL,
    id_hora          INT NOT NULL,

    cantidad_vendida INT           NOT NULL,
    importe_venta    DECIMAL(10,2) NOT NULL,

    CONSTRAINT FK_FactVenta_Fecha      FOREIGN KEY (id_fecha)       REFERENCES dbo.DimFecha(id_fecha),
    CONSTRAINT FK_FactVenta_Producto   FOREIGN KEY (id_producto)    REFERENCES dbo.DimProducto(id_producto),
    CONSTRAINT FK_FactVenta_Empleado   FOREIGN KEY (id_empleado)    REFERENCES dbo.DimEmpleado(id_empleado),
    CONSTRAINT FK_FactVenta_MetodoPago FOREIGN KEY (id_metodo_pago) REFERENCES dbo.DimMetodoPago(id_metodo_pago),
    CONSTRAINT FK_FactVenta_Hora       FOREIGN KEY (id_hora)        REFERENCES dbo.DimHora(id_hora)
);
GO

-- Indices sobre las llaves foraneas
CREATE INDEX IX_FactVenta_Fecha      ON dbo.FactVenta(id_fecha);
CREATE INDEX IX_FactVenta_Producto   ON dbo.FactVenta(id_producto);
CREATE INDEX IX_FactVenta_Empleado   ON dbo.FactVenta(id_empleado);
CREATE INDEX IX_FactVenta_MetodoPago ON dbo.FactVenta(id_metodo_pago);
CREATE INDEX IX_FactVenta_Hora       ON dbo.FactVenta(id_hora);
GO
