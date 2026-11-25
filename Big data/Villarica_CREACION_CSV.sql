/* =====================================================================
   SCRIPT 4 - EXPORTAR EL MODELO ESTRELLA A CSV (entrada para Spark)
   Requisito: haber ejecutado el ETL (03_ETL_Villarica.sql)
   En SSMS: ejecutar la consulta -> clic derecho en resultados ->
   "Guardar resultados como..." -> CSV (separador ;, sin encabezado)
   ===================================================================== */
USE Villarica;
GO

SELECT
    F.id_fact_venta AS id_detalle,   -- identifica cada linea de venta
    F.id_venta,
    D.fecha,
    P.nombre_producto AS producto,
    P.categoria,
    F.cantidad_vendida AS cantidad,
    F.importe_venta AS importe,
    M.nombre_metodo AS metodo_pago
FROM dbo.FactVenta AS F
INNER JOIN dbo.DimProducto   AS P ON F.id_producto    = P.id_producto
INNER JOIN dbo.DimFecha      AS D ON F.id_fecha       = D.id_fecha
INNER JOIN dbo.DimMetodoPago AS M ON F.id_metodo_pago = M.id_metodo_pago
ORDER BY F.id_fact_venta;
