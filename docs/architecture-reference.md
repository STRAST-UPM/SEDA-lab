# Architecture Reference

Este documento describe la arquitectura final actual de SEDA-Lab Reference Platform 1.0.

## Vista general

```text
                      +----------------+
                      |  Simulator     |
                      |  Python        |
                      +-------+--------+
                              |
                              | MQTT telemetry / state / ACK
                              v
+-------------+       +-------+--------+       +----------------+
| Node-RED UI | ----> |   Mosquitto    | ----> |   Node-RED     |
| /ui         | MQTT  |   MQTT broker  | MQTT  |   flows        |
+-------------+       +-------+--------+       +--------+-------+
                                                       |
                                                       | SQL
                                                       v
                                               +-------+--------+
                                               |  PostgreSQL    |
                                               +-------+--------+
                                                       |
                         +-----------------------------+------------------+
                         |                                                |
                         v                                                v
                +--------+--------+                              +--------+--------+
                |    Grafana      |                              |    Adminer      |
                +-----------------+                              +-----------------+

                +-----------------+      scrape      +-----------------+
                |   Prometheus    | <--------------  |  Node Exporter  |
                +--------+--------+                  +-----------------+
                         |
                         v
                +--------+--------+
                | Grafana Infra   |
                +-----------------+
```

## Docker Compose

`docker-compose.yml` define ocho servicios:

- `postgres`
- `mosquitto`
- `nodered`
- `grafana`
- `adminer`
- `simulator`
- `prometheus`
- `node-exporter`

Todos usan la red `seda_net`.

Volumenes persistentes:

- `postgres_data`
- `grafana_data`

Montajes relevantes:

- `./postgres/init:/docker-entrypoint-initdb.d:ro`
- `./mosquitto/config/mosquitto.conf:/mosquitto/config/mosquitto.conf:ro`
- `./nodered/data:/data`
- `./grafana/provisioning:/etc/grafana/provisioning:ro`
- `./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro`

## Responsabilidades

### PostgreSQL

Responsabilidad:

- mantener el modelo SQL de planta;
- guardar telemetria en `measurement`;
- guardar comandos en `command`;
- guardar estados en `state`;
- guardar alarmas en `alarm`;
- soportar consultas historicas y analitica offline.

No es:

- una base OLAP dedicada;
- un motor de streaming;
- un sistema de eventos avanzado.

### Mosquitto

Responsabilidad:

- transportar telemetria, comandos, ACKs, estados y alarmas MQTT.

Configuracion actual:

- MQTT en `1883`;
- WebSocket en `9001`;
- `allow_anonymous true`;
- persistencia MQTT activada.

### Simulator

Responsabilidad:

- publicar heartbeat;
- publicar telemetria Mesa del Sol sintetica;
- publicar estados;
- recibir comandos;
- aplicar estado interno minimo;
- publicar ACK MQTT.

No persiste directamente en PostgreSQL. Toda persistencia pasa por Node-RED.

### Node-RED

Responsabilidad:

- suscribirse a telemetria MQTT;
- validar payloads;
- insertar medidas en PostgreSQL;
- detectar alarmas sencillas;
- publicar alarmas MQTT;
- insertar comandos recibidos en PostgreSQL;
- insertar estados recibidos en PostgreSQL;
- ofrecer consola web `/ui`;
- publicar endpoints HTTP JSON.

### Grafana

Responsabilidad:

- provisionar datasources PostgreSQL y Prometheus;
- mostrar dashboards de plataforma, planta, operacion, alarmas e infraestructura.

### Adminer

Responsabilidad:

- inspeccion SQL manual para docencia.

### Prometheus y Node Exporter

Responsabilidad:

- observabilidad minima de plataforma;
- no monitorizan metricas especificas de planta.

## Flujos MQTT

### Heartbeat

Topic:

```text
seda/simulator/heartbeat
```

Origen: simulador.

Uso: comprobar que el simulador esta vivo.

### Telemetria

Topic:

```text
seda/plants/mds/components/{component_id}/sensors/{sensor_id}/telemetry
```

Origen: simulador.

Consumidor: Node-RED.

Persistencia: `measurement`.

### Comandos

Topic:

```text
seda/plants/mds/components/{component_id}/commands/{command_id}
```

Origen principal: Node-RED UI o `scripts/seed-command.sh`.

Consumidores:

- simulador, para aplicar comandos soportados;
- Node-RED, para persistir en `command`.

### ACK

Topic:

```text
seda/plants/{plant_id}/components/{component_id}/commands/{command_id}/ack
```

Origen: simulador.

Persistencia actual: ninguna.

### Estados

Topic:

```text
seda/plants/mds/components/{component_id}/state
```

Origen: simulador.

Consumidor: Node-RED.

Persistencia: `state`.

### Alarmas

Topic:

```text
seda/plants/mds/alarms/{alarm_code}
```

Origen: Node-RED.

Persistencia: `alarm`.

## Flujos SQL

### Measurement

Node-RED inserta:

```text
measurement(component_id, variable_id, ts, value, quality)
```

`component_id` se obtiene desde `component.code`.

`variable_id` se obtiene desde `variable_catalog.code`.

### Command

Node-RED inserta:

```text
command(component_id, ts, command, value, status)
```

`status` actual: `received`.

Los valores `on/off` se transforman a `1/0` para `command.value`.

### State

Node-RED inserta:

```text
state(component_id, ts, state)
```

### Alarm

Node-RED inserta:

```text
alarm(component_id, ts, severity, code, message)
```

`severity` actual: `warning`.

## Grafana provisioning

Datasources:

- `SEDA-Lab PostgreSQL`, uid `seda_lab_postgresql`.
- `SEDA-Lab Prometheus`, uid `seda_lab_prometheus`.

Dashboards:

- `platform.json`: SEDA Platform.
- `plant.json`: Plant Monitoring.
- `operation.json`: Commands & Operation.
- `alarms.json`: Alarms.
- `infrastructure.json`: Infrastructure.

No se usan variables `${DS...}`.

## HTTP publishing

Node-RED ofrece:

- `/seda/status`
- `/seda/latest-measurements`
- `/seda/latest-commands`
- `/seda/latest-alarms`

Estos endpoints son de lectura y devuelven JSON.

## Estructura del repositorio

```text
seda-lab/
  docker-compose.yml
  .env.example
  Makefile
  README.md
  postgres/init/00_init.sql
  mosquitto/config/mosquitto.conf
  nodered/Dockerfile
  nodered/data/flows.json
  grafana/provisioning/
  prometheus/prometheus.yml
  simulator/
  scripts/
  sql/analytics_examples.sql
  docs/
```

## Decisiones y justificacion

- **Un solo Compose:** reduce friccion docente y hace la plataforma reproducible.
- **PostgreSQL como centro:** permite usar el mismo modelo para operacion, historico y practicas SQL.
- **MQTT como contrato:** separa productor, recolector y consumidor.
- **Node-RED como integrador:** facilita explicar flujos visuales sin crear una aplicacion adicional.
- **Grafana provisionado:** evita configuracion manual repetitiva.
- **Prometheus minimo:** introduce observabilidad sin desviar el foco hacia infraestructura compleja.
- **Simulador sintetico:** evita incorporar el dataset completo y mantiene senales controlables.

## Limitaciones arquitectonicas

- No hay alta disponibilidad.
- No hay TLS ni autenticacion MQTT activa.
- No hay gestion segura de secretos.
- No hay cola persistente entre MQTT y PostgreSQL.
- No hay versionado formal de esquema SQL.
- No hay OLAP externo.
- No hay replay ni predictor implementados.
