# Calibracion del simulador Mesa del Sol

Reference Platform 1.0 usa un simulador sintetico calibrado con variables reales del dataset Mesa del Sol. No reproduce filas historicas y no implementa replay.

El fichero `simulator/calibration.json` contiene percentiles calculados sobre el dataset:

- `p01`: limite inferior aproximado.
- `p05`: limite inferior de operacion normal.
- `p50`: centro de referencia.
- `p95`: limite superior de operacion normal.
- `p99`: limite superior aproximado.

El CSV completo de Mesa del Sol no se incluye en el repositorio.

## Variables usadas

El simulador publica solo estas variables reales:

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

El `sensor_id` MQTT coincide con `variable_catalog.code`, de forma que Node-RED puede persistir las medidas sin traducir variables docentes ficticias.

## Generacion sintetica

Los valores normales se generan de forma suave entre `p05` y `p95`, usando `p50` como centro. El simulador limita las salidas entre `p01` y `p99`, salvo en modos de fallo docentes.

El objetivo es producir senales verosimiles para integracion, consultas SQL, alarmas y dashboards. No se pretende modelar fisicamente la planta.

## Estados y coherencia

- Si PV esta `OFF`, `PVPCS_Active_Power` vale `0` y la calidad es `disabled`.
- Si bateria esta `OFF`, `Battery_Active_Power` vale `0` y la calidad es `disabled`.
- Si red esta `DISCONNECTED`, las tensiones y frecuencia valen `0` y la calidad es `disconnected`.
- Si `fault_mode` es `GRID_LOST`, las tensiones y frecuencia valen `0` y la calidad es `alarm`.

## Fallos docentes

Los fallos crean condiciones claras para practicas:

- `HIGH_TEMPERATURE`: fuerza `Outlet_Temperature >= 31` y calidad `alarm`.
- `LOW_FREQUENCY`: fuerza `MG-LV-MSB_Frequency <= 59.96` y calidad `alarm`.
- `HIGH_FREQUENCY`: fuerza `MG-LV-MSB_Frequency >= 60.04` y calidad `alarm`.
- `LOW_VOLTAGE`: fuerza `Receiving_Point_AC_Voltage <= 476` y calidad `alarm`.
- `GRID_LOST`: fuerza tensiones y frecuencia a `0` y calidad `alarm`.

`BATTERY_LOW` se conserva como alias de compatibilidad y se traduce internamente a `LOW_FREQUENCY`. No debe usarse en practicas nuevas.

## Replay Mesa del Sol

El modo replay queda reservado para Bloque 6. En el futuro, el flujo previsto sera:

```text
dataset Mesa del Sol -> replay/predictor -> MQTT telemetry/predictions -> Node-RED -> PostgreSQL -> Grafana
```

Reference Platform 1.0 no implementa lectura de CSV ni incorpora datos historicos grandes.
