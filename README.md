# Villarica
## Proyecto de Business Intelligence y Big Data – Cafetería Villarica

Este proyecto desarrolla e implementa dos soluciones complementarias para el análisis de las ventas de la Cafetería Villarica, utilizando herramientas de Business Intelligence (BI) y Big Data.

- **Business Intelligence (BI):** implementación de una base de datos operacional en Microsoft SQL Server, procesos de extracción, transformación y carga (ETL), construcción de un Data Mart mediante un esquema estrella (tabla de hechos FactVenta y cinco dimensiones) y desarrollo de un tablero interactivo en Power BI. Esta solución permite analizar el comportamiento de las ventas y generar indicadores para apoyar la toma de decisiones.

- **Big Data:** procesamiento y análisis de datos mediante Databricks, Apache Spark y PySpark. Se desarrollan procesos de ingesta, limpieza, transformación, análisis exploratorio (EDA), agregaciones y visualizaciones, con la finalidad de evaluar el comportamiento de los datos y aplicar técnicas de procesamiento distribuido.

El objetivo principal es facilitar el análisis de ingresos, cantidades vendidas, productos, categorías, horarios y métodos de pago, además de realizar experimentaciones relacionadas con el rendimiento y la calidad de los datos.

**Alcance del proyecto:** se enfoca en el procesamiento y análisis de información comercial de la cafetería. No contempla la implementación de un sistema de punto de venta ni un sistema integral de control de inventarios. Los datos adicionales utilizados en las experimentaciones son de carácter sintético y no representan ventas reales adicionales.

## Integrantes

- Adriano Torres Villalobos
- Angelo Aponte Zambrano
- Brayan Diaz Principe

## Tecnologías utilizadas

| Componente | Tecnología | Propósito |
|---|---|---|
| Base de datos operacional y Data Mart | Microsoft SQL Server / SSMS | Gestión de tablas, consultas, modelo dimensional y procesos ETL. |
| Business Intelligence | Microsoft Power BI Desktop | Elaboración de indicadores, reportes y visualizaciones interactivas. |
| Big Data | Databricks / Apache Spark / PySpark | Ingesta, transformación, procesamiento y análisis de datos. |
| Experimentaciones | T-SQL / Python / PySpark | Evaluación de rendimiento, procesamiento y calidad de datos. |

## Estructura del repositorio

El repositorio está organizado en carpetas que contienen los recursos, scripts, archivos de trabajo y evidencias correspondientes a cada componente del proyecto.

```text
Cafeteria-Villarica-BI-BigData/
│
├── Base de datos/
│   └── Scripts SQL de la base de datos operacional y Data Mart
│
├── Big data/
│   └── Archivos y notebooks para el procesamiento y análisis de datos
│
├── Experimentaciones/
│   └── Pruebas y evaluaciones de rendimiento y calidad
│
├── Power BI/
│   └── Archivos del modelo y reportes de Power BI
│
├── capturas/
│   └── Imágenes y evidencias del desarrollo del proyecto
│
└── LÉAME.md
    └── Documentación general del proyecto
```

## Organización del proyecto

- **Base de datos:** contiene los recursos relacionados con la base de datos operacional, el modelo dimensional y los procesos ETL desarrollados en SQL Server.
- **Big data:** reúne los archivos y desarrollos realizados en Databricks mediante Apache Spark y PySpark.
- **Experimentaciones:** almacena las pruebas realizadas para evaluar el rendimiento, procesamiento y calidad de los datos.
- **Power BI:** contiene los archivos correspondientes al desarrollo del modelo analítico y los paneles de visualización.
- **capturas:** almacena las evidencias visuales de los procedimientos, resultados y avances del proyecto.

## Resultados esperados

- Implementar un Data Mart que permita analizar las ventas de la Cafetería Villarica.
- Desarrollar un tablero interactivo para visualizar los principales indicadores comerciales.
- Aplicar herramientas Big Data para procesar y analizar conjuntos de datos.
- Realizar experimentaciones para evaluar el rendimiento y la calidad de los procesos.
- Facilitar la interpretación de la información para apoyar la toma de decisiones.
