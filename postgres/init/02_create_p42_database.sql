/*
  SEDA-Lab - Bloque 4

  Este script crea la base de datos para la práctica 2 del Bloque 4.
  - seda_p42 para la segunda práctica (instancia con las tablas y valores 
  de referencia, pero sin datos operativos).
  --   * Table and column names follow the SEDA-Lab model where possible.
  --   * 'variable' is used here instead of seda_lab's 'variable_catalog'
  --     as a pedagogical simplification requested for P4.2.
  --   * Data types use those introduced in T4.1.
  --   * Reference data are preloaded; measurement and state start empty.
*/
CREATE DATABASE seda_p42 WITH OWNER = seda;
\connect seda_p42

-- ============================================================================
-- 1. Reference schema
-- ============================================================================
CREATE TABLE plant (
    id INT GENERATED ALWAYS AS IDENTITY,
    name VARCHAR(128) NOT NULL,
    CONSTRAINT pk_plant PRIMARY KEY (id)
);

CREATE TABLE component (
    id INT GENERATED ALWAYS AS IDENTITY,
    plant_id INT NOT NULL,
    code VARCHAR(5) NOT NULL,
    name VARCHAR(150) NOT NULL,
    type VARCHAR(10) NOT NULL,
    CONSTRAINT pk_component PRIMARY KEY (id),
    CONSTRAINT uq_component_code UNIQUE (code),
    CONSTRAINT fk_component_plant
        FOREIGN KEY (plant_id)
        REFERENCES plant(id)
        ON DELETE RESTRICT,
    CONSTRAINT ck_component_type
        CHECK (type IN (
            'Battery',
            'PVPCS',
            'GasEngine',
            'FuelCell',
            'MCCB',
            'MainBus',
            'PCC',
            'Cooling'
        ))
);

CREATE TABLE variable (
    id INT GENERATED ALWAYS AS IDENTITY,
    code VARCHAR(64) NOT NULL,
    name VARCHAR(150) NOT NULL,
    unit VARCHAR(20) NOT NULL,
    CONSTRAINT pk_variable PRIMARY KEY (id),
    CONSTRAINT uq_variable_code UNIQUE (code)
);

CREATE TABLE sensor (
    id INT GENERATED ALWAYS AS IDENTITY,
    component_id INT NOT NULL,
    variable_id INT NOT NULL,
    CONSTRAINT pk_sensor PRIMARY KEY (id),
    CONSTRAINT fk_sensor_component
        FOREIGN KEY (component_id)
        REFERENCES component(id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_sensor_variable
        FOREIGN KEY (variable_id)
        REFERENCES variable(id)
        ON DELETE RESTRICT
);

CREATE TABLE measurement (
    id INT GENERATED ALWAYS AS IDENTITY,
    component_id INT NOT NULL,
    variable_id INT NOT NULL,
    ts TIMESTAMP NOT NULL,
    value DECIMAL(15,4) NOT NULL,
    quality VARCHAR(4) NOT NULL,
    CONSTRAINT pk_measurement PRIMARY KEY (id),
    CONSTRAINT fk_measurement_component
        FOREIGN KEY (component_id)
        REFERENCES component(id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_measurement_variable
        FOREIGN KEY (variable_id)
        REFERENCES variable(id)
        ON DELETE RESTRICT,
    CONSTRAINT ck_measurement_quality
        CHECK (quality IN ('GOOD', 'BAD'))
);

CREATE TABLE state (
    id INT GENERATED ALWAYS AS IDENTITY,
    component_id INT NOT NULL,
    ts TIMESTAMP NOT NULL,
    state VARCHAR(5) NOT NULL,
    CONSTRAINT pk_state PRIMARY KEY (id),
    CONSTRAINT fk_state_component
        FOREIGN KEY (component_id)
        REFERENCES component(id)
        ON DELETE RESTRICT,
    CONSTRAINT ck_state_value
        CHECK (state IN ('OFF', 'ON', 'FAULT'))
);

-- ============================================================================
-- 2. Initial reference data
-- ============================================================================

-- The order is intentional so the workshop can rely on stable identifiers:
--   BAT1 -> component_id = 1
--   PV1  -> component_id = 2
--   Battery_Active_Power -> variable_id = 1

INSERT INTO plant (name)
VALUES ('PLANT1 - Mesa del Sol');

INSERT INTO component (plant_id, code, name, type)
VALUES
    (1, 'BAT1',  'Battery',                  'Battery'),
    (1, 'PV1',   'PVPCS',                    'PVPCS'),
    (1, 'GE1',   'Gas Engine',               'GasEngine'),
    (1, 'FC1',   'Fuel Cell',                'FuelCell'),
    (1, 'MCCB1', 'MCCB',                     'MCCB'),
    (1, 'BUS1',  'Main Bus',                 'MainBus'),
    (1, 'PCC1',  'Point of Common Coupling', 'PCC'),
    (1, 'COOL1', 'Cooling System',           'Cooling');

INSERT INTO variable (code, name, unit)
VALUES
    ('Battery_Active_Power',
     'Battery Active Power',
     'kW'),
    ('PVPCS_Active_Power',
     'PVPCS Active Power',
     'kW'),
    ('GE_Active_Power',
     'GE Active Power',
     'kW'),
    ('FC_Active_Power',
     'Fuel Cell Active Power',
     'kW'),
    ('Island_mode_MCCB_Active_Power',
     'MCCB Active Power',
     'kW'),
    ('MG-LV-MSB_AC_Voltage',
     'Main Bus AC Voltage',
     'V'),
    ('Receiving_Point_AC_Voltage',
     'PCC AC Voltage',
     'V'),
    ('MG-LV-MSB_Frequency',
     'Main Bus Frequency',
     'Hz'),
    ('Inlet_Temperature_of_Chilled_Water',
     'Cooling Inlet Temperature',
     'degC'),
    ('Outlet_Temperature',
     'Cooling Outlet Temperature',
     'degC');

INSERT INTO sensor (component_id, variable_id)
VALUES
    (1, 1),   -- BAT1   -> Battery_Active_Power
    (2, 2),   -- PV1    -> PVPCS_Active_Power
    (3, 3),   -- GE1    -> GE_Active_Power
    (4, 4),   -- FC1    -> FC_Active_Power
    (5, 5),   -- MCCB1  -> Island_mode_MCCB_Active_Power
    (6, 6),   -- BUS1   -> MG-LV-MSB_AC_Voltage
    (7, 7),   -- PCC1   -> Receiving_Point_AC_Voltage
    (6, 8),   -- BUS1   -> MG-LV-MSB_Frequency
    (8, 9),   -- COOL1  -> Inlet_Temperature_of_Chilled_Water
    (8, 10);  -- COOL1  -> Outlet_Temperature

-- measurement and state intentionally start empty.
