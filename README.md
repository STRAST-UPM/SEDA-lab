# SEDA-Lab

SEDA-Lab Iteracion 1 bootstrap.

Esta version levanta una base minima con PostgreSQL, Mosquitto, Node-RED, Grafana, Adminer y un simulador Python que publica un heartbeat MQTT cada 5 segundos.

## Inicio rapido

```bash
cp .env.example .env
docker compose up -d
docker compose ps
```

## Entorno de desarrollo

Documentacion para trabajar con SEDA-Lab Reference Platform 1.0:

- [Desarrollo local](docs/development.md)
- [Reference Platform 1.0](docs/reference-platform-1.0.md)
- [Arquitectura de referencia](docs/architecture-reference.md)
- [Referencia de componentes](docs/component-reference.md)
- [Analitica offline](docs/analytics-offline.md)
- [Consultas SQL de ejemplo](sql/analytics_examples.sql)

Comandos basicos:

```bash
cp .env.example .env
make start
make check
make seed-command
```

`make seed-command` publica seed operational commands sobre PVPCS, Battery y Simulator, usando los mismos topics y payloads que la consola Node-RED.

## Analitica offline

Reference Platform 1.0 usa PostgreSQL como base operacional, historico simple y soporte para analitica offline docente.

Las consultas de ejemplo permiten trabajar con historicos, agregados, tendencias, calidad de datos, alarmas, comandos, estados y anomalias offline usando las variables reales Mesa del Sol.

- Guia: [docs/analytics-offline.md](docs/analytics-offline.md)
- SQL: [sql/analytics_examples.sql](sql/analytics_examples.sql)

## URLs

- Node-RED: http://localhost:1880
- Grafana: http://localhost:3000
- Adminer: http://localhost:8080

## Credenciales

Grafana:

- Usuario: admin
- Contrasena: admin

Adminer:

- Sistema: PostgreSQL
- Servidor: postgres
- Usuario: seda
- Contrasena: seda
- Base de datos: seda_lab

## Seguridad de Reference Platform 1.0

SEDA-Lab Reference Platform 1.0 esta disenada para ejecutarse en una red local docente.

No debe exponerse directamente a Internet. La autenticacion MQTT esta preparada en la configuracion de Mosquitto, pero permanece desactivada por defecto para facilitar el uso en aula.

Todas las credenciales configurables se centralizan en `.env`:

- PostgreSQL: `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`
- Grafana: `GF_SECURITY_ADMIN_USER`, `GF_SECURITY_ADMIN_PASSWORD`
- MQTT: `MQTT_ALLOW_ANONYMOUS`, `MQTT_USERNAME`, `MQTT_PASSWORD`
- Plataforma y simulador: `SEDA_PLATFORM_VERSION`, `SIMULATOR_MODE`, `SIMULATOR_REPLAY_FILE`

Para un uso de produccion seria necesario anadir:

- TLS
- certificados
- autenticacion fuerte
- control de acceso
- gestion segura de secretos

## Estado actual antes de Reference Platform 1.0

Actualmente funcionan:

- PostgreSQL con tablas `measurement` y `command`.
- Mosquitto como broker MQTT.
- Simulador Python publicando telemetria y recibiendo comandos.
- Node-RED persistiendo medidas en `measurement`.
- Node-RED persistiendo comandos en `command`.
- Grafana con datasource PostgreSQL estable:
  - name: SEDA-Lab PostgreSQL
  - uid: seda_lab_postgresql
- Dashboard Commands & Operation con:
  - Latest Commands
  - Latest States
- Adminer accesible para inspeccion SQL.

Checklist de comprobacion:

1. Arranque general:

```bash
docker compose up -d
docker compose ps
```

2. Comprobar PostgreSQL:

```bash
docker compose exec postgres psql -U seda -d seda_lab -c "select count(*) from measurement;"
docker compose exec postgres psql -U seda -d seda_lab -c "select count(*) from command;"
```

3. Comprobar ultimas medidas:

```bash
docker compose exec postgres psql -U seda -d seda_lab -c "select m.ts, c.code, v.code, m.value, m.quality from measurement m join component c on c.id = m.component_id join variable_catalog v on v.id = m.variable_id order by m.ts desc limit 10;"
```

4. Comprobar ultimos comandos:

```bash
docker compose exec postgres psql -U seda -d seda_lab -c "select cmd.ts, c.code, c.name, cmd.command, cmd.value, cmd.status from command cmd join component c on c.id = cmd.component_id order by cmd.ts desc limit 10;"
```

5. Publicar comando de prueba:

```bash
docker compose exec mosquitto mosquitto_pub -h localhost -t 'seda/plants/mds/components/battery/commands/cmd-r1-test' -m '{"command_id":"cmd-r1-test","plant_id":"mds","component_id":"battery","command":"set_status","value":"off","requested_by":"teacher","ts":"2026-01-01T00:00:00Z"}'
```

6. Ver mensajes MQTT:

```bash
docker compose exec mosquitto mosquitto_sub -h localhost -t 'seda/#' -v
```

7. URLs actuales:

- Node-RED: http://localhost:1880
- Grafana: http://localhost:3000
- Adminer: http://localhost:8080

Este punto se considera la base funcional previa a la ampliacion Reference Platform 1.0. Antes de continuar debe verificarse que todos los comandos anteriores funcionan.

## R2 — Servicios de Reference Platform 1.0

La plataforma incluye ahora:

- PostgreSQL
- Mosquitto
- Node-RED
- Grafana
- Adminer
- Simulador Python
- Prometheus
- Node Exporter

URLs:

- Node-RED: http://localhost:1880
- Grafana: http://localhost:3000
- Adminer: http://localhost:8080
- Prometheus: http://localhost:9090
- Node Exporter metrics: http://localhost:9100/metrics

Comandos de prueba:

```bash
docker compose up -d
docker compose ps
```

Prometheus:

1. Abrir http://localhost:9090
2. Ir a Status -> Targets
3. Comprobar que aparecen:
   - prometheus
   - node-exporter

Node Exporter:

Abrir http://localhost:9100/metrics

En esta iteracion no se anaden todavia exporters especificos para PostgreSQL, Mosquitto, Node-RED ni Grafana, ni dashboards de observabilidad.

## R4 — Consola minima de ordenes

La consola web minima de ordenes esta disponible en:

http://localhost:1880/ui

La consola incluye:

- SEDA-Lab / Commands
- Battery START / STOP
- PVPCS START / STOP
- GE START / STOP
- Fuel Cell START / STOP
- Simulator Fault:
  - NONE
  - HIGH_TEMPERATURE
  - LOW_VOLTAGE
  - HIGH_VOLTAGE
  - LOW_FREQUENCY
  - HIGH_FREQUENCY
  - GRID_LOST

Para probar:

1. Abrir http://localhost:1880/ui
2. Pulsar `Battery STOP`
3. Pulsar `Battery START`
4. Pulsar `Fault LOW_VOLTAGE`
5. Pulsar `Fault NONE`

Cada boton publica una orden MQTT hacia Mosquitto usando el broker existente `mosquitto:1883`. La orden entra por el flujo MQTT de comandos de Node-RED y queda persistida en PostgreSQL en la tabla `command`.

Comprobar ultimos comandos en PostgreSQL:

```bash
docker compose exec postgres psql -U seda -d seda_lab -c "select cmd.ts, c.code, c.name, cmd.command, cmd.value, cmd.status from command cmd join component c on c.id = cmd.component_id order by cmd.ts desc limit 10;"
```

Comprobar en Grafana:

Dashboard Commands & Operation -> Latest Commands

## R5 — Simulador docente Reference Platform 1.0

El simulador Python representa una planta docente sencilla. Mantiene las funciones anteriores:

- heartbeat MQTT en `seda/simulator/heartbeat`
- telemetria periodica de sensores
- recepcion de ordenes MQTT
- publicacion de ACKs MQTT

La calibracion sintetica del simulador se basa en percentiles Mesa del Sol y se documenta en [docs/simulator-calibration.md](docs/simulator-calibration.md). Reference Platform 1.0 no incorpora el CSV grande ni implementa replay.

Ademas incorpora estados internos basicos:

- `battery_state`: `OFF`, `ON`
- `pv_state`: `OFF`, `ON`, `FAULT`
- `grid_state`: `CONNECTED`, `DISCONNECTED`
- `fault_mode`: `NONE`, `HIGH_TEMPERATURE`, `LOW_FREQUENCY`, `HIGH_FREQUENCY`, `LOW_VOLTAGE`, `GRID_LOST`

El simulador publica variables reales del dataset Mesa del Sol, calibradas con percentiles `p01`, `p05`, `p50`, `p95` y `p99`:

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

El `sensor_id` MQTT coincide con `variable_catalog.code`.

El simulador publica tambien estados MQTT en:

```text
seda/plants/mds/components/<component>/state
```

Node-RED persiste esos estados en la tabla `state`, mapeando los identificadores MQTT operacionales a componentes SQL existentes:

- `battery` -> `BAT1`
- `pv` -> `PV1`
- `grid` -> `PCC1`
- `simulator` -> `MCCB1`

Consultar ultimos estados:

```bash
docker compose exec postgres psql -U seda -d seda_lab -c "select s.ts, c.code, c.name, s.state from state s join component c on c.id = s.component_id order by s.ts desc limit 10;"
```

Ejemplo de payload:

```json
{
  "plant_id": "mds",
  "component_id": "battery",
  "state": "CHARGING",
  "timestamp": "2026-01-01T00:00:00+00:00",
  "quality": "good"
}
```

Ordenes operacionales publicadas por MQTT y persistidas por Node-RED:

- `battery` / `set_status` / `on`
- `battery` / `set_status` / `off`
- `pv` / `set_status` / `on`
- `pv` / `set_status` / `off`
- `ge` / `START`
- `ge` / `STOP`
- `fuel_cell` / `START`
- `fuel_cell` / `STOP`
- `grid` / `connect`
- `grid` / `disconnect`
- `simulator` / `set_fault` / `NONE`
- `simulator` / `set_fault` / `HIGH_TEMPERATURE`
- `simulator` / `set_fault` / `LOW_FREQUENCY`
- `simulator` / `set_fault` / `HIGH_FREQUENCY`
- `simulator` / `set_fault` / `LOW_VOLTAGE`
- `simulator` / `set_fault` / `HIGH_VOLTAGE`
- `simulator` / `set_fault` / `GRID_LOST`

Este comportamiento no pretende ser un gemelo digital ni un modelo fisico completo. Es un simulador docente simple para comprobar telemetria, estados, ordenes, ACKs y persistencia dentro de SEDA-Lab.

### Modo replay futuro

Reference Platform 1.0 usa el modo `synthetic`:

```env
SIMULATOR_MODE=synthetic
SIMULATOR_REPLAY_FILE=
```

El modo `replay` queda reservado para el Bloque 6. Si se configura `SIMULATOR_MODE=replay`, el simulador arranca, muestra el mensaje:

```text
Replay mode is reserved for Block 6 and is not implemented in Reference Platform 1.0
```

y continua en modo `synthetic` para no romper la plataforma.

Mas adelante, el modo replay permitira publicar medidas historicas Mesa del Sol desde un dataset. El predictor del Bloque 6 podra integrarse en el futuro publicando resultados en topics MQTT de `predictions`.

## R6 — Alarmas basicas

Reference Platform 1.0 incluye reglas docentes de alarma en Node-RED basadas en variables reales Mesa del Sol:

- `HIGH_OUTLET_TEMPERATURE`: se dispara cuando `Outlet_Temperature > 30`.
- `LOW_FREQUENCY`: se dispara cuando `MG-LV-MSB_Frequency < 59.97`.
- `HIGH_FREQUENCY`: se dispara cuando `MG-LV-MSB_Frequency > 60.03`.
- `LOW_VOLTAGE`: se dispara cuando `Receiving_Point_AC_Voltage < 478`.
- `HIGH_VOLTAGE`: se dispara cuando `Receiving_Point_AC_Voltage > 488`.

Estos umbrales se mantienen sincronizados manualmente con los percentiles de `simulator/calibration.json`: `p95`/`p05` para operacion normal y valores extremos docentes para fallos.

Cuando una regla se dispara:

- Node-RED inserta un registro en la tabla `alarm`.
- Node-RED publica un mensaje MQTT en `seda/plants/mds/alarms/<alarm_code>`.

La deduplicacion es sencilla: se evita insertar la misma alarma para el mismo componente si ya existe una alarma igual en los ultimos 60 segundos. No hay deduplicacion avanzada ni ciclo completo de vida de alarmas en Reference Platform 1.0.

Probar alarma de temperatura de salida alta publicando telemetria Mesa del Sol:

```bash
docker compose exec mosquitto mosquitto_pub -h localhost -t 'seda/plants/mds/components/COOL1/sensors/Outlet_Temperature/telemetry' -m '{"plant_id":"mds","component_id":"COOL1","sensor_id":"Outlet_Temperature","timestamp":"2026-01-01T00:00:00Z","value":31,"unit":"degC","quality":"good"}'
```

Probar alarma de baja frecuencia publicando telemetria Mesa del Sol:

```bash
docker compose exec mosquitto mosquitto_pub -h localhost -t 'seda/plants/mds/components/BUS1/sensors/MG-LV-MSB_Frequency/telemetry' -m '{"plant_id":"mds","component_id":"BUS1","sensor_id":"MG-LV-MSB_Frequency","timestamp":"2026-01-01T00:01:00Z","value":59.96,"unit":"Hz","quality":"good"}'
```

Consultar la tabla `alarm`:

```bash
docker compose exec postgres psql -U seda -d seda_lab -c "select a.ts, c.code, c.name, a.severity, a.code, a.message from alarm a join component c on c.id = a.component_id order by a.ts desc limit 10;"
```

Escuchar alarmas MQTT:

```bash
docker compose exec mosquitto mosquitto_sub -h localhost -t 'seda/plants/mds/alarms/#' -v
```

Forzar temperatura alta desde el simulador:

```bash
docker compose exec mosquitto mosquitto_pub -h localhost -t 'seda/plants/mds/components/simulator/commands/cmd-high-temp' -m '{"command_id":"cmd-high-temp","plant_id":"mds","component_id":"simulator","command":"set_fault","value":"HIGH_TEMPERATURE","requested_by":"teacher"}'
```

Forzar baja tension desde el simulador:

```bash
docker compose exec mosquitto mosquitto_pub -h localhost -t 'seda/plants/mds/components/simulator/commands/cmd-low-voltage' -m '{"command_id":"cmd-low-voltage","plant_id":"mds","component_id":"simulator","command":"set_fault","value":"LOW_VOLTAGE","requested_by":"teacher"}'
```

Volver a modo normal:

```bash
docker compose exec mosquitto mosquitto_pub -h localhost -t 'seda/plants/mds/components/simulator/commands/cmd-fault-none' -m '{"command_id":"cmd-fault-none","plant_id":"mds","component_id":"simulator","command":"set_fault","value":"NONE","requested_by":"teacher"}'
```

Ver alarmas en Grafana:

Dashboard Alarms -> Latest alarms

## R7 — Publicacion web minima

Node-RED publica endpoints HTTP minimos para consultar datos de SEDA-Lab sin crear una aplicacion web externa.

URLs:

- http://localhost:1880/seda/status
- http://localhost:1880/seda/latest-measurements
- http://localhost:1880/seda/latest-commands
- http://localhost:1880/seda/latest-alarms

Comandos de prueba:

```bash
curl http://localhost:1880/seda/status
curl http://localhost:1880/seda/latest-measurements
curl http://localhost:1880/seda/latest-commands
curl http://localhost:1880/seda/latest-alarms
```

## R9 — Observabilidad minima

Reference Platform 1.0 incluye observabilidad minima con Prometheus, Node Exporter y Grafana.

URLs:

- Prometheus: http://localhost:9090
- Node Exporter metrics: http://localhost:9100/metrics

En Prometheus:

1. Abrir http://localhost:9090
2. Ir a Status -> Targets
3. Comprobar que aparecen los targets:
   - prometheus
   - node-exporter

En Grafana:

1. Abrir http://localhost:3000
2. Entrar en el dashboard Infrastructure
3. Revisar los paneles:
   - Prometheus target status
   - Node CPU load
   - Node memory available
   - Filesystem available

## Comandos de prueba

Ver logs del simulador:

```bash
docker compose logs -f simulator
```

Recrear la base desde cero para ejecutar los scripts de inicializacion:

```bash
docker compose down -v
docker compose up -d
```

Entrar en PostgreSQL:

```bash
docker compose exec postgres psql -U seda -d seda_lab
```

Dentro de `psql`, comprobar tablas y datos minimos:

```sql
\dt

select * from component;

select * from sensor;

select * from actuator;
```

Tambien se puede ejecutar una consulta directa desde terminal:

```bash
docker compose exec postgres psql -U seda -d seda_lab -c "select * from component;"
```

## Iteracion 3 — Prueba MQTT

Ver logs del simulador:

```bash
docker compose logs -f simulator
```

Suscribirse a todos los topics desde el contenedor Mosquitto:

```bash
docker compose exec mosquitto mosquitto_sub -h localhost -t 'seda/#' -v
```

Reiniciar solo el simulador:

```bash
docker compose restart simulator
```

## Iteracion 4 — Prueba de persistencia MQTT → PostgreSQL

Reconstruir Node-RED y levantar los servicios:

```bash
docker compose down
docker compose build nodered
docker compose up -d
```

Ver logs:

```bash
docker compose logs -f nodered
docker compose logs -f simulator
```

Consultar ultimas medidas en PostgreSQL:

```bash
docker compose exec postgres psql -U seda -d seda_lab -c "select id, component_id, variable_id, ts, value, quality from measurement order by ts desc limit 10;"
```

## Iteracion 5 — Prueba de Grafana

Reiniciar Grafana para cargar el dashboard provisionado:

```bash
docker compose restart grafana
```

Abrir:

http://localhost:3000

Credenciales:

- Usuario: admin
- Contrasena: admin

Entrar en:

Dashboards -> SEDA-Lab Telemetry

Comprobar:

- tabla con ultimas medidas
- grafico temporal con datos
- resumen por sensor

## Iteracion 6 — Prueba de ordenes de control

Publicar una orden desde Mosquitto usando el topic real de ordenes del Documento 3:

```bash
docker compose exec mosquitto mosquitto_pub -h localhost -t 'seda/plants/mds/components/battery/commands/cmd-001' -m '{"command_id":"cmd-001","plant_id":"mds","component_id":"battery","command":"set_status","value":"off","requested_by":"teacher","ts":"2026-01-01T00:00:00Z"}'
```

Ver logs del simulador:

```bash
docker compose logs -f simulator
```

Escuchar ACKs y otros mensajes:

```bash
docker compose exec mosquitto mosquitto_sub -h localhost -t 'seda/#' -v
```

Consultar la tabla real de ordenes en PostgreSQL:

```bash
docker compose exec postgres psql -U seda -d seda_lab -c 'select id, component_id, ts, command, value, status from "command" order by ts desc limit 10;'
```

Consultar los ACKs registrados como eventos:

```bash
docker compose exec postgres psql -U seda -d seda_lab -c "select id, component_id, ts, event from event order by ts desc limit 10;"
```

## Iteracion 7 — Prueba de visualizacion de ordenes

Reiniciar Grafana para recargar el dashboard provisionado:

```bash
docker compose restart grafana
```

Abrir http://localhost:3000 y entrar en:

Dashboards -> SEDA-Lab Telemetry

Publicar una orden off:

```bash
docker compose exec mosquitto mosquitto_pub -h localhost -t 'seda/plants/mds/components/battery/commands/cmd-001' -m '{"command_id":"cmd-001","plant_id":"mds","component_id":"battery","command":"set_status","value":"off","requested_by":"teacher","ts":"2026-01-01T00:00:00Z"}'
```

Publicar una orden on:

```bash
docker compose exec mosquitto mosquitto_pub -h localhost -t 'seda/plants/mds/components/battery/commands/cmd-002' -m '{"command_id":"cmd-002","plant_id":"mds","component_id":"battery","command":"set_status","value":"on","requested_by":"teacher","ts":"2026-01-01T00:01:00Z"}'
```

Comprobar en el dashboard:

- panel Latest Commands
- panel Latest States
- aparecen las ordenes
- aparecen los estados publicados por MQTT

Parar servicios:

```bash
docker compose down
```

Parar servicios y eliminar volumenes:

```bash
docker compose down -v
```
