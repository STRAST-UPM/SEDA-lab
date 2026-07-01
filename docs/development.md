# Desarrollo local de SEDA-Lab

## Requisitos

- Docker Desktop o Docker Engine con Docker Compose.
- `curl` para comprobar endpoints HTTP.

No hace falta instalar `psql` localmente. Las consultas PostgreSQL se ejecutan dentro del contenedor `postgres`.

## Arranque

```bash
cp .env.example .env
make start
```

## Comprobacion

```bash
make check
```

## URLs

- Node-RED: http://localhost:1880
- Node-RED UI: http://localhost:1880/ui
- Grafana: http://localhost:3000
- Adminer: http://localhost:8080
- Prometheus: http://localhost:9090

## Configuracion de credenciales

Las credenciales configurables se definen en `.env`. Para crear el fichero local:

```bash
cp .env.example .env
```

Variables principales:

- `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`: base de datos PostgreSQL usada por Node-RED, Adminer y Grafana.
- `GF_SECURITY_ADMIN_USER`, `GF_SECURITY_ADMIN_PASSWORD`: usuario administrador inicial de Grafana.
- `MQTT_ALLOW_ANONYMOUS`: mantiene Mosquitto en modo docente si vale `true`.
- `MQTT_USERNAME`, `MQTT_PASSWORD`: credenciales reservadas para activar MQTT autenticado en una iteracion posterior.
- `SEDA_PLATFORM_VERSION`: version funcional de la plataforma.
- `SIMULATOR_MODE`, `SIMULATOR_REPLAY_FILE`: configuracion del simulador; Reference Platform 1.0 usa `synthetic`.

Cambiar estas variables es necesario cuando se quiera evitar credenciales por defecto, preparar una practica con usuarios distintos o probar una configuracion mas cercana a despliegue real. Si se cambia PostgreSQL o Grafana, reiniciar los servicios afectados. Si se cambia el modo MQTT autenticado, tambien sera necesario crear un fichero de contrasenas de Mosquitto y ajustar `mosquitto/config/mosquitto.conf`.

## Flujo de trabajo recomendado

1. Arrancar plataforma con `make start`.
2. Probar endpoints con `make check`.
3. Revisar dashboards en Grafana.
4. Publicar seed operational commands con `make seed-command`.
5. Revisar PostgreSQL con `docker compose exec postgres psql`.

## Observabilidad local

Prometheus monitoriza la propia plataforma, no la planta electrica simulada.

En Reference Platform 1.0 se monitorizan:

- Prometheus
- Node Exporter

El dashboard Grafana `Infrastructure` usa el datasource `SEDA-Lab Prometheus` para mostrar estado de targets, CPU, memoria y filesystem.

Las metricas especificas de PostgreSQL, Mosquitto, Node-RED o simulador quedan para extensiones futuras. No hay exporters dedicados para esos servicios en Reference Platform 1.0.

## stop y reset

`make stop` detiene los contenedores sin borrar datos.

`make reset` borra volumenes Docker y reinicia PostgreSQL/Grafana desde cero. Usarlo solo cuando una practica lo indique.

## Normas para estudiantes

- No modificar `docker-compose.yml` salvo practica especifica.
- No borrar volumenes salvo que se indique.
- Usar scripts y `make` para pruebas repetibles.
- Documentar los cambios realizados.
- Mantener la plataforma arrancable con `docker compose up -d`.
