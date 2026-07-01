# Component Reference

Este documento resume los componentes de SEDA-Lab Reference Platform 1.0 y sus responsabilidades reales.

## Componentes de infraestructura

### PostgreSQL

Servicio Compose: `postgres`

Imagen: `postgres:16`

Puerto: `5432`

Variables:

- `POSTGRES_DB`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`

Responsabilidad:

- crear el esquema SQL desde `postgres/init/00_init.sql`;
- mantener catalogos de planta y variables;
- almacenar medidas, comandos, estados, eventos y alarmas.

Tablas principales:

- `plant`
- `component`
- `variable_catalog`
- `sensor`
- `actuator`
- `allowed_state`
- `allowed_command`
- `measurement`
- `state`
- `command`
- `event`
- `alarm`

### Mosquitto

Servicio Compose: `mosquitto`

Imagen: `eclipse-mosquitto:2`

Puertos:

- `1883`: MQTT
- `9001`: MQTT over WebSocket

Configuracion:

- `mosquitto/config/mosquitto.conf`
- `allow_anonymous true`
- `persistence true`

Responsabilidad:

- transportar mensajes MQTT de telemetria, comandos, ACKs, estados y alarmas.

### Node-RED

Servicio Compose: `nodered`

Build: `./nodered`

Puerto: `1880`

Dockerfile:

- base `nodered/node-red:latest`;
- instala `node-red-contrib-postgresql`;
- instala `node-red-dashboard`.

Responsabilidad:

- colector MQTT hacia PostgreSQL;
- consola de ordenes `/ui`;
- reglas de alarma;
- endpoints HTTP;
- publicacion de alarmas MQTT.

Flujos principales:

- `MQTT telemetry` -> `Validate telemetry` -> `Insert measurement`.
- `MQTT command` -> `Build command insert` -> `Insert command`.
- `MQTT state` -> `Build state insert` -> `Insert state`.
- `Check basic alarms` -> `Insert alarm` y `Publish alarm`.
- HTTP `/seda/*`.
- UI buttons -> `Publish Mesa del Sol UI command`.

### Grafana

Servicio Compose: `grafana`

Imagen: `grafana/grafana-oss:latest`

Puerto: `3000`

Datasources:

- `SEDA-Lab PostgreSQL`, uid `seda_lab_postgresql`.
- `SEDA-Lab Prometheus`, uid `seda_lab_prometheus`.

Dashboards:

- `SEDA Platform`
- `Plant Monitoring`
- `Commands & Operation`
- `Alarms`
- `Infrastructure`

### Adminer

Servicio Compose: `adminer`

Imagen: `adminer:latest`

Puerto: `8080`

Responsabilidad:

- inspeccion SQL manual;
- ejecucion de consultas docentes.

### Simulator

Servicio Compose: `simulator`

Build: `./simulator`

Dependencias:

- Mosquitto.

Variables desde Compose:

- `MQTT_HOST=mosquitto`
- `MQTT_PORT=1883`

El codigo tambien lee:

- `SIMULATOR_MODE`
- `SIMULATOR_REPLAY_FILE`

pero estas variables no se pasan actualmente desde `docker-compose.yml`.

Responsabilidad:

- generar telemetria Mesa del Sol sintetica;
- publicar heartbeat;
- publicar estados;
- recibir comandos;
- mantener estado interno;
- publicar ACK MQTT.

### Prometheus

Servicio Compose: `prometheus`

Imagen: `prom/prometheus:latest`

Puerto: `9090`

Scrape targets:

- `prometheus:9090`
- `node-exporter:9100`

### Node Exporter

Servicio Compose: `node-exporter`

Imagen: `prom/node-exporter:latest`

Puerto: `9100`

Responsabilidad:

- exponer metricas basicas consumidas por Prometheus.

## Componentes Mesa del Sol

| Code | Name | Type | Variables |
| --- | --- | --- | --- |
| BAT1 | Battery | Battery | Battery_Active_Power |
| PV1 | PVPCS | PVPCS | PVPCS_Active_Power |
| GE1 | Gas Engine | GasEngine | GE_Active_Power |
| FC1 | Fuel Cell | FuelCell | FC_Active_Power |
| MCCB1 | MCCB | MCCB | Island_mode_MCCB_Active_Power |
| BUS1 | Main Bus | MainBus | MG-LV-MSB_AC_Voltage, MG-LV-MSB_Frequency |
| PCC1 | Point of Common Coupling | PCC | Receiving_Point_AC_Voltage |
| COOL1 | Cooling System | Cooling | Inlet_Temperature_of_Chilled_Water, Outlet_Temperature |

## Variables

| Code | Unit |
| --- | --- |
| Battery_Active_Power | kW |
| PVPCS_Active_Power | kW |
| GE_Active_Power | kW |
| FC_Active_Power | kW |
| Island_mode_MCCB_Active_Power | kW |
| MG-LV-MSB_AC_Voltage | V |
| Receiving_Point_AC_Voltage | V |
| MG-LV-MSB_Frequency | Hz |
| Inlet_Temperature_of_Chilled_Water | degC |
| Outlet_Temperature | degC |

## Comandos

### Consola Node-RED

Botones actuales:

- Battery START
- Battery STOP
- PVPCS START
- PVPCS STOP
- GE START
- GE STOP
- Fuel Cell START
- Fuel Cell STOP
- Fault NONE
- Fault HIGH_TEMPERATURE
- Fault LOW_VOLTAGE
- Fault HIGH_VOLTAGE
- Fault LOW_FREQUENCY
- Fault HIGH_FREQUENCY
- Fault GRID_LOST

### Comandos aplicados por el simulador

| component_id MQTT | command | value |
| --- | --- | --- |
| battery | set_status | on, off |
| pv | set_status | on, off |
| grid | connect | |
| grid | disconnect | |
| simulator | set_fault | NONE |
| simulator | set_fault | HIGH_TEMPERATURE |
| simulator | set_fault | LOW_FREQUENCY |
| simulator | set_fault | HIGH_FREQUENCY |
| simulator | set_fault | LOW_VOLTAGE |
| simulator | set_fault | GRID_LOST |
| simulator | set_fault | BATTERY_LOW |

Nota: la consola publica `HIGH_VOLTAGE`, pero el simulador actual no lo acepta como `fault_mode`.

### Persistencia de comandos

Todos los comandos MQTT recibidos por Node-RED se intentan persistir en `command`.

Mapeo:

| MQTT component_id | SQL component.code |
| --- | --- |
| battery | BAT1 |
| pv | PV1 |
| pvpcs | PV1 |
| ge | GE1 |
| fuel_cell | FC1 |
| fc | FC1 |
| grid | PCC1 |
| simulator | MCCB1 |

## Estados

Estados publicados por el simulador:

- `battery`: estado interno de bateria.
- `pv`: estado interno de PV.
- `grid`: `CONNECTED` o `DISCONNECTED`.
- `simulator`: `OK` o `FAULT_{fault_mode}`.

Los estados se persisten en `state`.

## Alarmas

| Alarm code | Variable | Regla |
| --- | --- | --- |
| HIGH_OUTLET_TEMPERATURE | Outlet_Temperature | value > 30 |
| LOW_FREQUENCY | MG-LV-MSB_Frequency | value < 59.97 |
| HIGH_FREQUENCY | MG-LV-MSB_Frequency | value > 60.03 |
| LOW_VOLTAGE | Receiving_Point_AC_Voltage | value < 478 |
| HIGH_VOLTAGE | Receiving_Point_AC_Voltage | value > 488 |

## Dashboards

### SEDA Platform

Paneles:

- Measurement count.
- Command count.
- Latest measurement.
- Latest command.

### Plant Monitoring

Paneles:

- Latest measurements.
- Measurements over time.
- Power variables.
- Voltage and frequency.

### Commands & Operation

Paneles:

- Latest Commands.
- Latest States.

### Alarms

Paneles:

- Latest alarms.

### Infrastructure

Paneles:

- Prometheus targets up.
- Node memory available.
- Node filesystem available.
- Node CPU seconds.

## Scripts

### `scripts/check-platform.sh`

Comprueba:

- estado de Docker Compose;
- conteos de `measurement`, `command` y `alarm`;
- endpoints HTTP `/seda/status`, `/seda/latest-measurements`, `/seda/latest-commands`, `/seda/latest-alarms`.

### `scripts/reset-platform.sh`

Pide confirmacion `RESET` y ejecuta:

```bash
docker compose down -v
docker compose up -d
```

### `scripts/seed-command.sh`

Publica seed operational commands:

- PVPCS START.
- PVPCS STOP.
- Battery START.
- Battery STOP.
- Simulator fault HIGH_TEMPERATURE.
- Simulator fault NONE.

### `scripts/tail-logs.sh`

Sigue logs de:

- simulator;
- nodered;
- grafana.
