# Analitica offline en SEDA-Lab

Reference Platform 1.0 usa PostgreSQL como base operacional, historico simple y soporte para analitica offline docente.

## Conceptos

La base operacional es la base que recibe datos durante la ejecucion de la plataforma. En SEDA-Lab contiene medidas, ordenes, alarmas y estados.

El historico es el conjunto de filas acumuladas con marca temporal. En esta version se almacena en las tablas `measurement`, `command`, `alarm` y `state`.

La analitica offline consiste en consultar esos datos historicos fuera del flujo de control en tiempo real. Sirve para estudiar tendencias, agregados, calidad de datos, alarmas y relaciones sencillas entre variables.

Un sistema OLAP completo es una plataforma especializada para analisis masivo, normalmente con modelos columnares, particionado, cubos, pipelines de carga y optimizaciones especificas.

## Por que PostgreSQL

Reference Platform 1.0 no anade DuckDB, ClickHouse ni otra base OLAP porque las practicas iniciales no lo necesitan. PostgreSQL ya esta en la arquitectura, conserva el modelo relacional y permite consultas historicas suficientemente expresivas para docencia.

Una base OLAP externa tendria sentido si:

- el volumen historico creciera mucho;
- se necesitaran consultas analiticas pesadas y frecuentes;
- se quisiera separar claramente carga operacional y carga analitica;
- se incorporaran datasets historicos grandes o replay intensivo;
- se necesitaran formatos columnares o integracion con data lake.

## Ejecutar consultas con Adminer

1. Abrir http://localhost:8080
2. Entrar con:
   - Sistema: PostgreSQL
   - Servidor: postgres
   - Usuario: seda
   - Contrasena: seda
   - Base de datos: seda_lab
3. Abrir la opcion SQL command.
4. Copiar una consulta desde `sql/analytics_examples.sql`.
5. Ejecutarla y revisar el resultado.

## Ejecutar consultas con psql

Entrar en PostgreSQL:

```bash
docker compose exec postgres psql -U seda -d seda_lab
```

Desde el prompt de `psql`, pegar una consulta de `sql/analytics_examples.sql`.

Tambien se puede ejecutar una consulta corta directamente:

```bash
docker compose exec postgres psql -U seda -d seda_lab -c "select count(*) from measurement;"
```

## Usar analytics_examples.sql

El fichero [sql/analytics_examples.sql](../sql/analytics_examples.sql) contiene consultas comentadas y docentes. No crea tablas, vistas ni indices.

Formas de uso:

- Abrir el fichero y copiar una consulta concreta en Adminer.
- Copiar una consulta concreta en una sesion `psql`.
- Adaptar filtros de tiempo, variables o componentes para una practica.

## Preguntas docentes

Las consultas permiten responder preguntas como:

- Que variable tiene mas muestras?
- Que componentes generan mas datos?
- Como evoluciona `PVPCS_Active_Power`?
- Cuando se producen mas alarmas?
- Que comandos se han enviado?
- Que valores salen del rango normal?
- Hay relacion simple entre potencia PVPCS y potencia MCCB?
- Que ultimo estado se conoce de cada componente?

## Variables Mesa del Sol

Las consultas usan el catalogo real de Reference Platform 1.0:

- `Battery_Active_Power`
- `PVPCS_Active_Power`
- `GE_Active_Power`
- `FC_Active_Power`
- `Island_mode_MCCB_Active_Power`
- `MG-LV-MSB_AC_Voltage`
- `Receiving_Point_AC_Voltage`
- `MG-LV-MSB_Frequency`
- `Inlet_Temperature_of_Chilled_Water`
- `Outlet_Temperature`
