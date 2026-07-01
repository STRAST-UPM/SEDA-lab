/*
  SEDA-Lab - Documento 4
  Modelo SQL

  Este script crea el esquema relacional inicial de SEDA-Lab.

  Principios de esta iteracion:
  - SQL simple y legible para uso docente.
  - PostgreSQL como base de datos relacional.
  - Sin indices adicionales todavia.
  - Sin triggers.
  - Sin procedimientos almacenados.
  - Sin vistas.

  Nota sobre claves unicas:
  El Documento 4 solo indica UNIQUE para:
  - component(code)
  - variable_catalog(code)

  Por ese motivo no se anaden restricciones UNIQUE en otros catalogos.
*/

/*
  ============================================================================
  1. Modelo de planta
  ============================================================================
*/

/*
  plant

  Representa la planta.
  En la Iteracion 1 existe una unica planta: PLANT1 / Mesa del Sol.
*/
create table if not exists plant (
  id serial primary key,
  name text not null
);

/*
  component

  Componentes de la planta.

  Relacion:
  - Una planta tiene N componentes.
  - Cada componente pertenece a una planta.

  El Documento 4 indica UNIQUE(code).
*/
create table if not exists component (
  id serial primary key,
  plant_id integer not null references plant(id),
  code text not null unique,
  name text not null,
  type text not null
);

/*
  ============================================================================
  2. Catalogo canonico de variables
  ============================================================================
*/

/*
  variable_catalog

  Catalogo canonico de variables definido en el Documento 2.
  Esta tabla permanece practicamente estatica.

  El Documento 4 indica UNIQUE(code).
*/
create table if not exists variable_catalog (
  id serial primary key,
  code text not null unique,
  name text not null,
  unit text not null
);

/*
  sensor

  Tabla docente auxiliar para declarar que variables mide cada componente.

  En el modelo logico del Documento 2, cada componente tiene variables[].
  En SQL se materializa como una relacion entre:
  - component
  - variable_catalog

  No se define UNIQUE porque el Documento 4 no lo indica.
*/
create table if not exists sensor (
  id serial primary key,
  component_id integer not null references component(id),
  variable_id integer not null references variable_catalog(id)
);

/*
  actuator

  Tabla docente auxiliar para declarar las ordenes admitidas por componente.

  En el modelo logico del Documento 2, cada componente tiene commands[].
  En SQL se materializa como una relacion entre:
  - component
  - una orden permitida

  No se define UNIQUE porque el Documento 4 no lo indica.
*/
create table if not exists actuator (
  id serial primary key,
  component_id integer not null references component(id),
  command text not null
);

/*
  allowed_state

  Catalogo minimo de estados permitidos por el contrato logico:
  - OFF
  - ON
  - FAULT

  Se mantiene como catalogo simple para docencia.
  No se define UNIQUE porque el Documento 4 no lo indica.
*/
create table if not exists allowed_state (
  id serial primary key,
  state text not null
);

/*
  allowed_command

  Catalogo minimo de ordenes permitidas.

  El Documento 2 indica que todos los componentes aceptan:
  - START
  - STOP

  Y que BAT1, GE1 y FC1 aceptan ademas:
  - SET_POWER

  No se define UNIQUE porque el Documento 4 no lo indica.
*/
create table if not exists allowed_command (
  id serial primary key,
  command text not null
);

/*
  ============================================================================
  3. Tablas historicas
  ============================================================================
*/

/*
  measurement

  Series temporales.
  Una fila representa una unica medida de una variable de un componente.

  Relaciones:
  - Un componente tiene N medidas.
  - Una variable del catalogo tiene N medidas.

  La columna quality almacena calidades como GOOD o BAD.
*/
create table if not exists measurement (
  id serial primary key,
  component_id integer not null references component(id),
  variable_id integer not null references variable_catalog(id),
  ts timestamp not null,
  value double precision not null,
  quality text not null
);

/*
  state

  Historico de estados de componentes.
  Estados esperados por contrato:
  - OFF
  - ON
  - FAULT
*/
create table if not exists state (
  id serial primary key,
  component_id integer not null references component(id),
  ts timestamp not null,
  state text not null
);

/*
  command

  Ordenes recibidas por los componentes.

  value permite almacenar consignas numericas cuando la orden lo necesite.
  Por ejemplo, SET_POWER puede tener un valor asociado.

  El Documento 4 indica que value puede ser NULL.
*/
create table if not exists command (
  id serial primary key,
  component_id integer not null references component(id),
  ts timestamp not null,
  command text not null,
  value double precision null,
  status text not null
);

/*
  event

  Eventos del sistema asociados a un componente.
*/
create table if not exists event (
  id serial primary key,
  component_id integer not null references component(id),
  ts timestamp not null,
  event text not null
);

/*
  alarm

  Alarmas asociadas a un componente.
*/
create table if not exists alarm (
  id serial primary key,
  component_id integer not null references component(id),
  ts timestamp not null,
  severity text not null,
  code text not null,
  message text not null
);

/*
  ============================================================================
  4. Datos iniciales
  ============================================================================

  Los INSERT se escriben de forma idempotente cuando es posible.
  Como no todos los catalogos tienen UNIQUE por decision del Documento 4,
  se usa where not exists para evitar duplicados si el script se reejecuta.
*/

/*
  Planta inicial:
  - PLANT1
  - Mesa del Sol

  La tabla plant no tiene columna code en el Documento 4. Por eso se almacena
  el identificador y el nombre en el campo name.
*/
insert into plant (name)
select 'PLANT1 - Mesa del Sol'
where not exists (
  select 1
  from plant
  where name = 'PLANT1 - Mesa del Sol'
);

/*
  Componentes iniciales de la planta.
*/
insert into component (plant_id, code, name, type)
select p.id, v.code, v.name, v.type
from plant p
cross join (
  values
    ('BAT1', 'Battery', 'Battery'),
    ('PV1', 'PVPCS', 'PVPCS'),
    ('GE1', 'Gas Engine', 'GasEngine'),
    ('FC1', 'Fuel Cell', 'FuelCell'),
    ('MCCB1', 'MCCB', 'MCCB'),
    ('BUS1', 'Main Bus', 'MainBus'),
    ('PCC1', 'Point of Common Coupling', 'PCC'),
    ('COOL1', 'Cooling System', 'Cooling')
) as v(code, name, type)
where p.name = 'PLANT1 - Mesa del Sol'
on conflict (code) do nothing;

/*
  Catalogo canonico de variables.

  Reference Platform 1.0 usa variables reales del dataset Mesa del Sol.
  Los nombres corresponden a las senales de referencia usadas para calibrar
  el simulador sintetico.
*/
insert into variable_catalog (code, name, unit)
values
  ('Battery_Active_Power', 'Battery_Active_Power', 'kW'),
  ('PVPCS_Active_Power', 'PVPCS_Active_Power', 'kW'),
  ('GE_Active_Power', 'GE_Active_Power', 'kW'),
  ('FC_Active_Power', 'FC_Active_Power', 'kW'),
  ('Island_mode_MCCB_Active_Power', 'Island_mode_MCCB_Active_Power', 'kW'),
  ('MG-LV-MSB_AC_Voltage', 'MG-LV-MSB_AC_Voltage', 'V'),
  ('Receiving_Point_AC_Voltage', 'Receiving_Point_AC_Voltage', 'V'),
  ('MG-LV-MSB_Frequency', 'MG-LV-MSB_Frequency', 'Hz'),
  ('Inlet_Temperature_of_Chilled_Water', 'Inlet_Temperature_of_Chilled_Water', 'degC'),
  ('Outlet_Temperature', 'Outlet_Temperature', 'degC')
on conflict (code) do nothing;

/*
  Sensores iniciales.

  Cada fila indica que un componente publica una variable concreta.
*/
insert into sensor (component_id, variable_id)
select c.id, vc.id
from (
  values
    ('BAT1', 'Battery_Active_Power'),
    ('PV1', 'PVPCS_Active_Power'),
    ('GE1', 'GE_Active_Power'),
    ('FC1', 'FC_Active_Power'),
    ('MCCB1', 'Island_mode_MCCB_Active_Power'),
    ('BUS1', 'MG-LV-MSB_AC_Voltage'),
    ('PCC1', 'Receiving_Point_AC_Voltage'),
    ('BUS1', 'MG-LV-MSB_Frequency'),
    ('COOL1', 'Inlet_Temperature_of_Chilled_Water'),
    ('COOL1', 'Outlet_Temperature')
) as v(component_code, variable_code)
join component c on c.code = v.component_code
join variable_catalog vc on vc.code = v.variable_code
where not exists (
  select 1
  from sensor s
  where s.component_id = c.id
    and s.variable_id = vc.id
);

/*
  Catalogo de estados permitidos.
*/
insert into allowed_state (state)
select v.state
from (
  values
    ('OFF'),
    ('ON'),
    ('FAULT')
) as v(state)
where not exists (
  select 1
  from allowed_state s
  where s.state = v.state
);

/*
  Catalogo de ordenes permitidas.
*/
insert into allowed_command (command)
select v.command
from (
  values
    ('START'),
    ('STOP'),
    ('SET_POWER')
) as v(command)
where not exists (
  select 1
  from allowed_command c
  where c.command = v.command
);

/*
  Actuadores iniciales.

  Todos los componentes aceptan START y STOP.
  BAT1, GE1 y FC1 aceptan tambien SET_POWER.
*/
insert into actuator (component_id, command)
select c.id, v.command
from component c
cross join (
  values
    ('START'),
    ('STOP')
) as v(command)
where not exists (
  select 1
  from actuator a
  where a.component_id = c.id
    and a.command = v.command
);

insert into actuator (component_id, command)
select c.id, 'SET_POWER'
from component c
where c.code in ('BAT1', 'GE1', 'FC1')
  and not exists (
    select 1
    from actuator a
    where a.component_id = c.id
      and a.command = 'SET_POWER'
  );
