# SEDA-Lab Reference Platform 1.0

Este documento describe la version final actual de SEDA-Lab Reference Platform 1.0 antes de congelar la plataforma de referencia.

La plataforma es un entorno docente local para practicar integracion de planta, MQTT, persistencia relacional, visualizacion, publicacion web, observabilidad y analitica offline. Usa un modelo sintetico calibrado con variables reales del caso Mesa del Sol.

## Alcance

Reference Platform 1.0 incluye:

- PostgreSQL como base operacional, historico simple y soporte de analitica offline.
- Mosquitto como broker MQTT.
- Simulador Python sintetico de planta.
- Node-RED como recolector MQTT, consola de ordenes, motor de reglas sencillo y publicador HTTP.
- Grafana como visualizador de plataforma, planta, operacion, alarmas e infraestructura.
- Adminer para inspeccion SQL docente.
- Prometheus y Node Exporter para observabilidad minima de la plataforma.

No incluye:

- Replay real del dataset Mesa del Sol.
- Predictor.
- Base OLAP externa.
- Autenticacion MQTT activa.
- Exporters especificos de PostgreSQL, Mosquitto, Node-RED o simulador.
- Student Platform derivada.

## Arranque

```bash
cp .env.example .env
docker compose up -d
docker compose ps
```

Comprobacion basica:

```bash
make check
make seed-command
```

URLs principales:

- Node-RED: http://localhost:1880
- Node-RED UI: http://localhost:1880/ui
- Grafana: http://localhost:3000
- Adminer: http://localhost:8080
- Prometheus: http://localhost:9090
- Node Exporter metrics: http://localhost:9100/metrics

## Servicios

| Servicio | Rol | Puerto |
| --- | --- | --- |
| PostgreSQL | Modelo SQL, historico y analitica offline | 5432 |
| Mosquitto | Broker MQTT | 1883, 9001 |
| Node-RED | Recoleccion, consola, reglas y HTTP | 1880 |
| Grafana | Dashboards | 3000 |
| Adminer | Inspeccion SQL | 8080 |
| Simulator | Planta sintetica Mesa del Sol | sin puerto |
| Prometheus | Scraping de metricas | 9090 |
| Node Exporter | Metricas de nodo | 9100 |

Todos los servicios usan la red Docker `seda_net`.

## Modelo Mesa del Sol

La planta inicial se almacena como `PLANT1 - Mesa del Sol`.

Componentes SQL:

| Code | Name | Type |
| --- | --- | --- |
| BAT1 | Battery | Battery |
| PV1 | PVPCS | PVPCS |
| GE1 | Gas Engine | GasEngine |
| FC1 | Fuel Cell | FuelCell |
| MCCB1 | MCCB | MCCB |
| BUS1 | Main Bus | MainBus |
| PCC1 | Point of Common Coupling | PCC |
| COOL1 | Cooling System | Cooling |

Variables publicadas y persistidas:

| Variable | Unidad | Componente |
| --- | --- | --- |
| Battery_Active_Power | kW | BAT1 |
| PVPCS_Active_Power | kW | PV1 |
| GE_Active_Power | kW | GE1 |
| FC_Active_Power | kW | FC1 |
| Island_mode_MCCB_Active_Power | kW | MCCB1 |
| MG-LV-MSB_AC_Voltage | V | BUS1 |
| Receiving_Point_AC_Voltage | V | PCC1 |
| MG-LV-MSB_Frequency | Hz | BUS1 |
| Inlet_Temperature_of_Chilled_Water | degC | COOL1 |
| Outlet_Temperature | degC | COOL1 |

El `sensor_id` MQTT coincide con `variable_catalog.code`.

## Flujo de telemetria

```text
Simulator
  -> Mosquitto MQTT
  -> Node-RED MQTT telemetry
  -> PostgreSQL measurement
  -> Grafana Platform / Plant Monitoring
  -> Node-RED HTTP /seda/latest-measurements
```

Topic:

```text
seda/plants/mds/components/{component_id}/sensors/{sensor_id}/telemetry
```

Payload:

```json
{
  "plant_id": "mds",
  "component_id": "PV1",
  "sensor_id": "PVPCS_Active_Power",
  "timestamp": "2026-01-01T00:00:00+00:00",
  "value": 12.3,
  "unit": "kW",
  "quality": "good"
}
```

Node-RED valida que:

- el payload contiene los campos minimos;
- `value` es numerico;
- `timestamp` es fecha valida;
- `component_id` existe en el mapa SQL;
- `sensor_id` pertenece al catalogo Mesa del Sol.

La medida se inserta en:

```text
measurement(component_id, variable_id, ts, value, quality)
```

## Flujo de ordenes

```text
Node-RED UI
  -> Mosquitto MQTT command
  -> Simulator
  -> MQTT ACK

Mosquitto MQTT command
  -> Node-RED command flow
  -> PostgreSQL command
  -> Grafana Commands & Operation
  -> Node-RED HTTP /seda/latest-commands
```

Topic:

```text
seda/plants/mds/components/{component_id}/commands/{command_id}
```

Payload:

```json
{
  "command_id": "cmd-ui-pvpcs-start",
  "plant_id": "mds",
  "component_id": "pv",
  "command": "set_status",
  "value": "on",
  "requested_by": "nodered-console",
  "ts": "2026-01-01T00:00:00Z"
}
```

Mapeo de comandos en Node-RED:

| MQTT component_id | component.code SQL |
| --- | --- |
| battery | BAT1 |
| pv | PV1 |
| pvpcs | PV1 |
| ge | GE1 |
| fuel_cell | FC1 |
| fc | FC1 |
| grid | PCC1 |
| simulator | MCCB1 |

El simulador aplica internamente:

- `battery` / `set_status` / `on|off`
- `pv` / `set_status` / `on|off`
- `grid` / `connect|disconnect`
- `simulator` / `set_fault` / `NONE|HIGH_TEMPERATURE|LOW_FREQUENCY|HIGH_FREQUENCY|LOW_VOLTAGE|GRID_LOST|BATTERY_LOW`

El simulador publica ACK en:

```text
seda/plants/{plant_id}/components/{component_id}/commands/{command_id}/ack
```

Los ACK existen en MQTT, pero no se persisten en PostgreSQL en Reference Platform 1.0.

## Flujo de estados

```text
Simulator
  -> Mosquitto MQTT state
  -> Node-RED state flow
  -> PostgreSQL state
  -> Grafana Commands & Operation
```

Topic:

```text
seda/plants/mds/components/{component}/state
```

Payload:

```json
{
  "plant_id": "mds",
  "component_id": "battery",
  "state": "ON",
  "timestamp": "2026-01-01T00:00:00+00:00",
  "quality": "good"
}
```

Node-RED persiste en:

```text
state(component_id, ts, state)
```

Mapeo de estados:

| MQTT component_id | component.code SQL |
| --- | --- |
| battery | BAT1 |
| pv | PV1 |
| grid | PCC1 |
| simulator | MCCB1 |

## Flujo de alarmas

```text
Telemetry MQTT
  -> Node-RED alarm rules
  -> PostgreSQL alarm
  -> Mosquitto MQTT alarm
  -> Grafana Alarms
  -> Node-RED HTTP /seda/latest-alarms
```

Reglas actuales:

| Variable | Condicion | Alarma |
| --- | --- | --- |
| Outlet_Temperature | > 30 | HIGH_OUTLET_TEMPERATURE |
| MG-LV-MSB_Frequency | < 59.97 | LOW_FREQUENCY |
| MG-LV-MSB_Frequency | > 60.03 | HIGH_FREQUENCY |
| Receiving_Point_AC_Voltage | < 478 | LOW_VOLTAGE |
| Receiving_Point_AC_Voltage | > 488 | HIGH_VOLTAGE |

Topic de alarma:

```text
seda/plants/mds/alarms/{alarm_code}
```

La deduplicacion es simple: Node-RED evita insertar una alarma igual para el mismo componente si ya existe una en los ultimos 60 segundos.

## Flujo de observabilidad

```text
Prometheus
  -> scrape prometheus:9090
  -> scrape node-exporter:9100
  -> Grafana Infrastructure
```

Prometheus usa:

- `prometheus:9090`
- `node-exporter:9100`

Grafana usa el datasource `SEDA-Lab Prometheus` con `uid: seda_lab_prometheus`.

## Dashboards

| Dashboard | UID | Contenido |
| --- | --- | --- |
| SEDA Platform | seda-platform | contadores y ultimos registros |
| Plant Monitoring | plant-monitoring | medidas recientes y series temporales |
| Commands & Operation | commands-operation | comandos y estados |
| Alarms | alarms | ultimas alarmas |
| Infrastructure | infrastructure | Prometheus y Node Exporter |

## Endpoints HTTP

Node-RED publica:

- `GET /seda/status`
- `GET /seda/latest-measurements`
- `GET /seda/latest-commands`
- `GET /seda/latest-alarms`

Los endpoints devuelven JSON.

## Analitica offline

PostgreSQL se usa tambien como historico simple. Las consultas docentes estan en:

- `sql/analytics_examples.sql`
- `docs/analytics-offline.md`

No se crea base OLAP externa en Reference Platform 1.0.

## Decisiones arquitectonicas

- Docker Compose se mantiene como arquitectura unica para facilitar docencia local.
- PostgreSQL concentra base operacional, historico simple y analitica offline inicial.
- MQTT separa simulador, consola y recolector.
- Node-RED concentra integracion, reglas y publicacion HTTP para evitar una aplicacion web adicional.
- Grafana se provisiona por ficheros para que los dashboards sean reproducibles.
- Prometheus se limita a observabilidad de plataforma, no de planta.
- El simulador usa modo sintetico calibrado, no replay, para evitar incorporar datasets grandes al repositorio.

## Limitaciones conocidas

- `SIMULATOR_MODE` y `SIMULATOR_REPLAY_FILE` existen en `.env.example`, pero `docker-compose.yml` no los pasa actualmente al servicio `simulator`.
- Mosquitto esta en modo anonimo por defecto; el modo autenticado esta preparado pero no activado.
- Node-RED y Grafana provisioning usan credenciales PostgreSQL docentes fijas.
- El ACK de comandos se publica por MQTT, pero no se persiste en SQL.
- La consola Node-RED incluye comandos para GE y Fuel Cell que se registran, pero el simulador sintetico no los aplica internamente.
- La consola incluye `HIGH_VOLTAGE`; la regla de alarma existe, pero el simulador actual no acepta `HIGH_VOLTAGE` como `fault_mode`.
- No hay indices adicionales, triggers, procedimientos almacenados ni vistas.
- No hay exporters dedicados de PostgreSQL, Mosquitto, Node-RED o simulador.

## Evoluciones futuras

- Replay Mesa del Sol desde dataset historico.
- Predictor del Bloque 6 publicando topics MQTT de `predictions`.
- Student Platform derivada de Reference Platform 1.0.
- Autenticacion MQTT real y gestion de secretos.
- Exporters especificos y dashboards de infraestructura mas completos.
- Persistencia de ACKs o eventos de comando si una practica lo requiere.
- Indices SQL para historicos largos.
