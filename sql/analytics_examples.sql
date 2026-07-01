/*
  SEDA-Lab Reference Platform 1.0
  Analitica offline docente sobre PostgreSQL

  Este fichero contiene ejemplos de consultas historicas.
  Todas las consultas son SELECT:
  - No crean tablas.
  - No crean vistas.
  - No crean indices.
  - No usan extensiones.

  Variables reales Mesa del Sol usadas por la plataforma:
  - Battery_Active_Power
  - PVPCS_Active_Power
  - GE_Active_Power
  - FC_Active_Power
  - Island_mode_MCCB_Active_Power
  - MG-LV-MSB_AC_Voltage
  - Receiving_Point_AC_Voltage
  - MG-LV-MSB_Frequency
  - Inlet_Temperature_of_Chilled_Water
  - Outlet_Temperature
*/

/*
  1. Ultimas medidas con nombres de componente y variable.
*/
select
  m.ts,
  c.code as component_code,
  c.name as component_name,
  v.code as variable_code,
  v.name as variable_name,
  v.unit,
  m.value,
  m.quality
from measurement m
join component c on c.id = m.component_id
join variable_catalog v on v.id = m.variable_id
order by m.ts desc
limit 20;

/*
  2. Numero de muestras por variable.
*/
select
  v.code as variable_code,
  v.unit,
  count(*) as samples
from measurement m
join variable_catalog v on v.id = m.variable_id
group by v.code, v.unit
order by samples desc, v.code;

/*
  3. Numero de muestras por componente.
*/
select
  c.code as component_code,
  c.name as component_name,
  count(*) as samples
from measurement m
join component c on c.id = m.component_id
group by c.code, c.name
order by samples desc, c.code;

/*
  4. Promedio, minimo, maximo y desviacion tipica por variable.
*/
select
  v.code as variable_code,
  v.unit,
  avg(m.value) as avg_value,
  min(m.value) as min_value,
  max(m.value) as max_value,
  stddev_samp(m.value) as stddev_value
from measurement m
join variable_catalog v on v.id = m.variable_id
group by v.code, v.unit
order by v.code;

/*
  5. Promedio por hora para cada variable.
*/
select
  date_trunc('hour', m.ts) as hour_bucket,
  v.code as variable_code,
  avg(m.value) as avg_value
from measurement m
join variable_catalog v on v.id = m.variable_id
group by hour_bucket, v.code
order by hour_bucket desc, v.code;

/*
  6. Tendencia temporal de PVPCS_Active_Power.
*/
select
  m.ts,
  m.value as pvpcs_active_power_kw,
  m.quality
from measurement m
join variable_catalog v on v.id = m.variable_id
where v.code = 'PVPCS_Active_Power'
order by m.ts;

/*
  7. Comparacion temporal entre PVPCS_Active_Power,
     MG-LV-MSB_AC_Voltage y MG-LV-MSB_Frequency.
*/
select
  date_trunc('minute', m.ts) as minute_bucket,
  avg(m.value) filter (where v.code = 'PVPCS_Active_Power') as pvpcs_active_power_kw,
  avg(m.value) filter (where v.code = 'MG-LV-MSB_AC_Voltage') as bus_voltage_v,
  avg(m.value) filter (where v.code = 'MG-LV-MSB_Frequency') as bus_frequency_hz
from measurement m
join variable_catalog v on v.id = m.variable_id
where v.code in (
  'PVPCS_Active_Power',
  'MG-LV-MSB_AC_Voltage',
  'MG-LV-MSB_Frequency'
)
group by minute_bucket
order by minute_bucket;

/*
  8. Conteo de muestras por quality.
*/
select
  m.quality,
  count(*) as samples
from measurement m
group by m.quality
order by samples desc, m.quality;

/*
  9. Alarmas por tipo.
*/
select
  a.code as alarm_code,
  a.severity,
  count(*) as alarms
from alarm a
group by a.code, a.severity
order by alarms desc, a.code;

/*
  10. Alarmas por componente.
*/
select
  c.code as component_code,
  c.name as component_name,
  count(*) as alarms
from alarm a
join component c on c.id = a.component_id
group by c.code, c.name
order by alarms desc, c.code;

/*
  11. Comandos por componente.
*/
select
  c.code as component_code,
  c.name as component_name,
  cmd.command,
  cmd.status,
  count(*) as commands
from command cmd
join component c on c.id = cmd.component_id
group by c.code, c.name, cmd.command, cmd.status
order by commands desc, c.code, cmd.command;

/*
  12. Ultimo estado conocido por componente.
*/
select distinct on (c.id)
  c.code as component_code,
  c.name as component_name,
  s.ts,
  s.state
from state s
join component c on c.id = s.component_id
order by c.id, s.ts desc;

/*
  13. Ventana temporal reciente:
      ultimas medidas de los ultimos 15 minutos.
*/
select
  m.ts,
  c.code as component_code,
  v.code as variable_code,
  m.value,
  v.unit,
  m.quality
from measurement m
join component c on c.id = m.component_id
join variable_catalog v on v.id = m.variable_id
where m.ts >= now() - interval '15 minutes'
order by m.ts desc;

/*
  14. Agregacion por intervalo temporal:
      promedio por minuto para cada variable.
*/
select
  date_trunc('minute', m.ts) as minute_bucket,
  v.code as variable_code,
  avg(m.value) as avg_value,
  min(m.value) as min_value,
  max(m.value) as max_value,
  count(*) as samples
from measurement m
join variable_catalog v on v.id = m.variable_id
group by minute_bucket, v.code
order by minute_bucket desc, v.code;

/*
  15. Deteccion offline de anomalias:
      Receiving_Point_AC_Voltage fuera del rango normal p05-p95.
      Segun calibration.json: p05 = 478 V, p95 = 488 V.
*/
select
  m.ts,
  c.code as component_code,
  v.code as variable_code,
  m.value,
  case
    when m.value < 478 then 'LOW_VOLTAGE'
    when m.value > 488 then 'HIGH_VOLTAGE'
    else 'NORMAL'
  end as offline_anomaly
from measurement m
join component c on c.id = m.component_id
join variable_catalog v on v.id = m.variable_id
where v.code = 'Receiving_Point_AC_Voltage'
  and (m.value < 478 or m.value > 488)
order by m.ts desc;

/*
  16. Correlacion simple:
      PVPCS_Active_Power frente a Island_mode_MCCB_Active_Power,
      agregadas por minuto.
*/
with minute_values as (
  select
    date_trunc('minute', m.ts) as minute_bucket,
    avg(m.value) filter (where v.code = 'PVPCS_Active_Power') as pvpcs_active_power_kw,
    avg(m.value) filter (where v.code = 'Island_mode_MCCB_Active_Power') as mccb_active_power_kw
  from measurement m
  join variable_catalog v on v.id = m.variable_id
  where v.code in ('PVPCS_Active_Power', 'Island_mode_MCCB_Active_Power')
  group by minute_bucket
)
select
  corr(pvpcs_active_power_kw, mccb_active_power_kw) as pvpcs_mccb_corr,
  count(*) as minute_samples
from minute_values
where pvpcs_active_power_kw is not null
  and mccb_active_power_kw is not null;
