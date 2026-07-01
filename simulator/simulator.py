import json
import math
import os
import random
import time
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path

import paho.mqtt.client as mqtt


MQTT_HOST = os.getenv("MQTT_HOST", "mosquitto")
MQTT_PORT = int(os.getenv("MQTT_PORT", "1883"))
SIMULATOR_MODE = os.getenv("SIMULATOR_MODE", "synthetic").strip().lower()
SIMULATOR_REPLAY_FILE = os.getenv("SIMULATOR_REPLAY_FILE", "")
HEARTBEAT_TOPIC = "seda/simulator/heartbeat"
COMMAND_TOPIC = "seda/plants/+/components/+/commands/+"
STATE_TOPIC_TEMPLATE = "seda/plants/mds/components/{component}/state"
PUBLISH_INTERVAL_SECONDS = 5
CALIBRATION_PATH = Path(__file__).with_name("calibration.json")

DEFAULT_CALIBRATION = {
    "source": "Mesa del Sol percentiles p01/p05/p50/p95/p99 / SEDA-Lab Reference Platform 1.0",
    "variables": {
        "Battery_Active_Power": {
            "unit": "kW",
            "p01": -18.8,
            "p05": -0.6,
            "p50": -0.1,
            "p95": 0.1,
            "p99": 0.2,
        },
        "PVPCS_Active_Power": {
            "unit": "kW",
            "p01": -1.0,
            "p05": -1.0,
            "p50": 0.0,
            "p95": 39.0,
            "p99": 43.0,
        },
        "GE_Active_Power": {
            "unit": "kW",
            "p01": -1.7,
            "p05": -1.5,
            "p50": -0.7,
            "p95": 137.0,
            "p99": 232.0,
        },
        "FC_Active_Power": {
            "unit": "kW",
            "p01": -6.0,
            "p05": -1.0,
            "p50": 37.0,
            "p95": 38.0,
            "p99": 42.0,
        },
        "Island_mode_MCCB_Active_Power": {
            "unit": "kW",
            "p01": -239.0,
            "p05": -159.0,
            "p50": -26.0,
            "p95": 21.0,
            "p99": 26.0,
        },
        "MG-LV-MSB_AC_Voltage": {
            "unit": "V",
            "p01": 476.0,
            "p05": 478.0,
            "p50": 484.0,
            "p95": 490.0,
            "p99": 492.0,
        },
        "Receiving_Point_AC_Voltage": {
            "unit": "V",
            "p01": 476.0,
            "p05": 478.0,
            "p50": 484.0,
            "p95": 488.0,
            "p99": 490.0,
        },
        "MG-LV-MSB_Frequency": {
            "unit": "Hz",
            "p01": 59.96,
            "p05": 59.97,
            "p50": 60.0,
            "p95": 60.03,
            "p99": 60.04,
        },
        "Inlet_Temperature_of_Chilled_Water": {
            "unit": "degC",
            "p01": 7.0,
            "p05": 7.7,
            "p50": 19.1,
            "p95": 30.6,
            "p99": 32.6,
        },
        "Outlet_Temperature": {
            "unit": "degC",
            "p01": 8.9,
            "p05": 10.1,
            "p50": 18.0,
            "p95": 28.7,
            "p99": 30.9,
        },
    },
}

FAULT_MODES = {
    "NONE",
    "HIGH_TEMPERATURE",
    "LOW_FREQUENCY",
    "HIGH_FREQUENCY",
    "LOW_VOLTAGE",
    "GRID_LOST",
    "BATTERY_LOW",
}

battery_state = "ON"
pv_state = "ON"
grid_state = "CONNECTED"
fault_mode = "NONE"

SENSORS = [
    {"plant_id": "mds", "component_id": "BAT1", "sensor_id": "Battery_Active_Power"},
    {"plant_id": "mds", "component_id": "PV1", "sensor_id": "PVPCS_Active_Power"},
    {"plant_id": "mds", "component_id": "GE1", "sensor_id": "GE_Active_Power"},
    {"plant_id": "mds", "component_id": "FC1", "sensor_id": "FC_Active_Power"},
    {"plant_id": "mds", "component_id": "MCCB1", "sensor_id": "Island_mode_MCCB_Active_Power"},
    {"plant_id": "mds", "component_id": "BUS1", "sensor_id": "MG-LV-MSB_AC_Voltage"},
    {"plant_id": "mds", "component_id": "PCC1", "sensor_id": "Receiving_Point_AC_Voltage"},
    {"plant_id": "mds", "component_id": "BUS1", "sensor_id": "MG-LV-MSB_Frequency"},
    {"plant_id": "mds", "component_id": "COOL1", "sensor_id": "Inlet_Temperature_of_Chilled_Water"},
    {"plant_id": "mds", "component_id": "COOL1", "sensor_id": "Outlet_Temperature"},
]

random_generator = random.Random(42)
calibration = None


def load_calibration() -> dict:
    try:
        with CALIBRATION_PATH.open("r", encoding="utf-8") as calibration_file:
            loaded = json.load(calibration_file)
    except (OSError, json.JSONDecodeError) as exc:
        print(
            f"WARNING: could not read {CALIBRATION_PATH}. Using built-in calibration. Error: {exc}",
            flush=True,
        )
        return deepcopy(DEFAULT_CALIBRATION)

    if not isinstance(loaded, dict) or not isinstance(loaded.get("variables"), dict):
        print(f"WARNING: invalid {CALIBRATION_PATH}. Using built-in calibration.", flush=True)
        return deepcopy(DEFAULT_CALIBRATION)

    merged = deepcopy(DEFAULT_CALIBRATION)
    for variable, defaults in DEFAULT_CALIBRATION["variables"].items():
        values = loaded["variables"].get(variable, {})
        if isinstance(values, dict):
            merged["variables"][variable] = {**defaults, **values}
    merged["source"] = loaded.get("source", DEFAULT_CALIBRATION["source"])
    print(f"Loaded simulator calibration from {CALIBRATION_PATH}", flush=True)
    return merged


def variable_config(variable: str) -> dict:
    return calibration["variables"][variable]


def clamp_percentile(value: float, variable: str) -> float:
    config = variable_config(variable)
    return min(max(value, config["p01"]), config["p99"])


def utc_timestamp() -> str:
    return datetime.now(timezone.utc).isoformat()


def effective_simulator_mode() -> str:
    if SIMULATOR_MODE == "synthetic":
        print("Simulator mode: synthetic", flush=True)
        return "synthetic"

    if SIMULATOR_MODE == "replay":
        print(
            "Replay mode is reserved for Block 6 and is not implemented in Reference Platform 1.0",
            flush=True,
        )
        print("Continuing in synthetic mode.", flush=True)
        if SIMULATOR_REPLAY_FILE:
            print(f"Configured replay file ignored for now: {SIMULATOR_REPLAY_FILE}", flush=True)
        return "synthetic"

    print(f"Unsupported SIMULATOR_MODE={SIMULATOR_MODE!r}. Continuing in synthetic mode.", flush=True)
    return "synthetic"


def daylight_factor() -> float:
    now = datetime.now(timezone.utc)
    hour = now.hour + now.minute / 60 + now.second / 3600
    if hour < 6 or hour > 18:
        return 0.0
    return max(0.0, math.sin(math.pi * (hour - 6) / 12))


def smooth_value(variable: str, factor: float = 0.5, noise_ratio: float = 0.03) -> float:
    config = variable_config(variable)
    factor = min(max(factor, 0.0), 1.0)
    if factor < 0.5:
        value = config["p05"] + (config["p50"] - config["p05"]) * (factor / 0.5)
    else:
        value = config["p50"] + (config["p95"] - config["p50"]) * ((factor - 0.5) / 0.5)

    noise_span = max(config["p95"] - config["p05"], 0.1) * noise_ratio
    value += random_generator.uniform(-noise_span, noise_span)
    return round(clamp_percentile(value, variable), 3)


def telemetry_topic(sensor: dict) -> str:
    return (
        f"seda/plants/{sensor['plant_id']}"
        f"/components/{sensor['component_id']}"
        f"/sensors/{sensor['sensor_id']}"
        "/telemetry"
    )


def command_ack_topic(payload: dict) -> str:
    return (
        f"seda/plants/{payload.get('plant_id', 'unknown')}"
        f"/components/{payload.get('component_id', 'unknown')}"
        f"/commands/{payload.get('command_id', 'unknown')}"
        "/ack"
    )


def state_topic(component: str) -> str:
    return STATE_TOPIC_TEMPLATE.format(component=component)


def on_connect(client, userdata, flags, reason_code, properties) -> None:
    print(f"Connected to MQTT broker at {MQTT_HOST}:{MQTT_PORT}", flush=True)
    client.subscribe(COMMAND_TOPIC)
    print(f"Subscribed to {COMMAND_TOPIC}", flush=True)


def on_disconnect(client, userdata, flags, reason_code, properties) -> None:
    print(f"Disconnected from MQTT broker: {reason_code}", flush=True)


def on_message(client, userdata, msg) -> None:
    try:
        payload = json.loads(msg.payload.decode("utf-8"))
    except json.JSONDecodeError as exc:
        print(f"Invalid command JSON on {msg.topic}: {exc}", flush=True)
        return

    print(f"Received command on {msg.topic}: {json.dumps(payload)}", flush=True)
    ack_payload = handle_command(payload)
    topic = command_ack_topic(payload)
    payload_json = json.dumps(ack_payload)
    client.publish(topic, payload_json)
    print(f"Published to {topic}: {payload_json}", flush=True)


def connect_with_retries() -> mqtt.Client:
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    client.on_connect = on_connect
    client.on_disconnect = on_disconnect
    client.on_message = on_message
    client.reconnect_delay_set(min_delay=1, max_delay=10)

    while True:
        try:
            client.connect(MQTT_HOST, MQTT_PORT, keepalive=60)
            client.loop_start()
            return client
        except OSError as exc:
            print(f"MQTT connection failed: {exc}. Retrying in 5 seconds...", flush=True)
            time.sleep(5)


def ensure_connected(client: mqtt.Client) -> None:
    while not client.is_connected():
        try:
            client.reconnect()
        except OSError as exc:
            print(f"MQTT reconnect failed: {exc}. Retrying in 5 seconds...", flush=True)
            time.sleep(5)


def build_heartbeat_payload() -> str:
    payload = {
        "source": "seda-lab-simulator",
        "status": "ok",
        "timestamp": utc_timestamp(),
    }
    return json.dumps(payload)


def current_values() -> dict:
    daylight = daylight_factor()
    grid_connected = grid_state == "CONNECTED" and fault_mode != "GRID_LOST"

    pvpcs_active_power = smooth_value("PVPCS_Active_Power", daylight, noise_ratio=0.02)
    if pv_state == "OFF":
        pvpcs_active_power = 0.0

    battery_power = smooth_value("Battery_Active_Power", daylight, noise_ratio=0.05)
    if battery_state == "OFF":
        battery_power = 0.0

    ge_power = smooth_value("GE_Active_Power", 0.2 + (1 - daylight) * 0.5, noise_ratio=0.02)
    fc_power = smooth_value("FC_Active_Power", 0.75, noise_ratio=0.02)
    mccb_power = smooth_value("Island_mode_MCCB_Active_Power", 0.45 + daylight * 0.15, noise_ratio=0.03)

    bus_voltage = smooth_value("MG-LV-MSB_AC_Voltage", 0.5, noise_ratio=0.08)
    receiving_voltage = smooth_value("Receiving_Point_AC_Voltage", 0.5, noise_ratio=0.08)
    frequency = smooth_value("MG-LV-MSB_Frequency", 0.5, noise_ratio=0.08)

    if not grid_connected:
        bus_voltage = 0.0
        receiving_voltage = 0.0
        frequency = 0.0

    inlet_temperature = smooth_value("Inlet_Temperature_of_Chilled_Water", 0.5 + daylight * 0.2)
    outlet_temperature = smooth_value("Outlet_Temperature", 0.5 + daylight * 0.25)

    if fault_mode == "HIGH_TEMPERATURE":
        outlet_temperature = 31.0 + random_generator.uniform(0.0, 1.0)
    elif fault_mode == "LOW_FREQUENCY":
        frequency = 59.96
    elif fault_mode == "HIGH_FREQUENCY":
        frequency = 60.04
    elif fault_mode == "LOW_VOLTAGE":
        receiving_voltage = 476.0

    return {
        "Battery_Active_Power": round(battery_power, 3),
        "PVPCS_Active_Power": round(pvpcs_active_power, 3),
        "GE_Active_Power": round(ge_power, 3),
        "FC_Active_Power": round(fc_power, 3),
        "Island_mode_MCCB_Active_Power": round(mccb_power, 3),
        "MG-LV-MSB_AC_Voltage": round(bus_voltage, 3),
        "Receiving_Point_AC_Voltage": round(receiving_voltage, 3),
        "MG-LV-MSB_Frequency": round(frequency, 3),
        "Inlet_Temperature_of_Chilled_Water": round(inlet_temperature, 3),
        "Outlet_Temperature": round(outlet_temperature, 3),
    }


def quality_for_sensor(sensor_id: str) -> str:
    if sensor_id == "PVPCS_Active_Power" and pv_state == "OFF":
        return "disabled"
    if sensor_id == "Battery_Active_Power" and battery_state == "OFF":
        return "disabled"
    if fault_mode == "GRID_LOST" and sensor_id in (
        "MG-LV-MSB_AC_Voltage",
        "Receiving_Point_AC_Voltage",
        "MG-LV-MSB_Frequency",
    ):
        return "alarm"
    if grid_state == "DISCONNECTED" and sensor_id in (
        "MG-LV-MSB_AC_Voltage",
        "Receiving_Point_AC_Voltage",
        "MG-LV-MSB_Frequency",
    ):
        return "disconnected"
    if fault_mode == "HIGH_TEMPERATURE" and sensor_id == "Outlet_Temperature":
        return "alarm"
    if fault_mode == "LOW_FREQUENCY" and sensor_id == "MG-LV-MSB_Frequency":
        return "alarm"
    if fault_mode == "HIGH_FREQUENCY" and sensor_id == "MG-LV-MSB_Frequency":
        return "alarm"
    if fault_mode == "LOW_VOLTAGE" and sensor_id == "Receiving_Point_AC_Voltage":
        return "alarm"
    if fault_mode == "BATTERY_LOW" and sensor_id == "Battery_Active_Power":
        return "alarm"
    return "good"


def build_sensor_payload(sensor: dict, values: dict) -> str:
    sensor_id = sensor["sensor_id"]
    payload = {
        "plant_id": sensor["plant_id"],
        "component_id": sensor["component_id"],
        "sensor_id": sensor_id,
        "timestamp": utc_timestamp(),
        "value": values[sensor_id],
        "unit": variable_config(sensor_id)["unit"],
        "quality": quality_for_sensor(sensor_id),
    }
    return json.dumps(payload)


def normalize_value(value) -> str:
    return str(value).strip().upper()


def handle_command(payload: dict) -> dict:
    global battery_state, pv_state, grid_state, fault_mode

    required_fields = ["command_id", "plant_id", "component_id", "command"]
    missing_fields = [
        field
        for field in required_fields
        if payload.get(field) is None or payload.get(field) == ""
    ]

    status = "rejected"
    reason = ""

    if missing_fields:
        reason = f"missing fields: {', '.join(missing_fields)}"
    elif payload["plant_id"] != "mds":
        reason = "unsupported plant_id"
    else:
        component_id = str(payload["component_id"]).strip()
        command = str(payload["command"]).strip()
        value = normalize_value(payload.get("value", ""))

        if component_id == "battery" and command == "set_status" and value in ("ON", "OFF"):
            battery_state = value
            status = "accepted"
            reason = f"battery_state set to {battery_state}"
        elif component_id == "pv" and command == "set_status" and value in ("ON", "OFF"):
            pv_state = value
            status = "accepted"
            reason = f"pv_state set to {pv_state}"
        elif component_id == "grid" and command == "connect":
            grid_state = "CONNECTED"
            status = "accepted"
            reason = "grid_state set to CONNECTED"
        elif component_id == "grid" and command == "disconnect":
            grid_state = "DISCONNECTED"
            status = "accepted"
            reason = "grid_state set to DISCONNECTED"
        elif component_id == "simulator" and command == "set_fault" and value in FAULT_MODES:
            fault_mode = "LOW_FREQUENCY" if value == "BATTERY_LOW" else value
            if fault_mode == "NONE" and grid_state == "DISCONNECTED":
                grid_state = "CONNECTED"
            status = "accepted"
            reason = f"fault_mode set to {fault_mode}"
        elif component_id in ("battery", "pv", "simulator") and not value:
            reason = "missing fields: value"
        else:
            reason = "unsupported command"

    ack = {
        "command_id": payload.get("command_id", "unknown"),
        "plant_id": payload.get("plant_id", "unknown"),
        "component_id": payload.get("component_id", "unknown"),
        "status": status,
        "reason": reason,
        "ts": utc_timestamp(),
    }
    print(f"Command ACK: {json.dumps(ack)}", flush=True)
    return ack


def publish_message(client: mqtt.Client, topic: str, payload: str) -> None:
    ensure_connected(client)
    result = client.publish(topic, payload)
    try:
        result.wait_for_publish()
    except RuntimeError as exc:
        print(f"MQTT publish failed: {exc}. Reconnecting...", flush=True)
        ensure_connected(client)
        result = client.publish(topic, payload)
        result.wait_for_publish()
    print(f"Published to {topic}: {payload}", flush=True)


def publish_heartbeat(client: mqtt.Client) -> None:
    publish_message(client, HEARTBEAT_TOPIC, build_heartbeat_payload())


def publish_sensor_telemetry(client: mqtt.Client, values: dict) -> None:
    for sensor in SENSORS:
        topic = telemetry_topic(sensor)
        payload = build_sensor_payload(sensor, values)
        publish_message(client, topic, payload)


def build_state_payload(component_id: str, state: str) -> str:
    payload = {
        "plant_id": "mds",
        "component_id": component_id,
        "state": state,
        "timestamp": utc_timestamp(),
        "quality": "good",
    }
    return json.dumps(payload)


def publish_states(client: mqtt.Client) -> None:
    states = [
        ("battery", battery_state),
        ("pv", pv_state),
        ("grid", grid_state),
        ("simulator", f"FAULT_{fault_mode}" if fault_mode != "NONE" else "OK"),
    ]
    for component_id, state in states:
        publish_message(client, state_topic(component_id), build_state_payload(component_id, state))


def main() -> None:
    global calibration

    calibration = load_calibration()
    effective_simulator_mode()
    client = connect_with_retries()

    while True:
        values = current_values()
        publish_heartbeat(client)
        publish_sensor_telemetry(client, values)
        publish_states(client)
        time.sleep(PUBLISH_INTERVAL_SECONDS)


if __name__ == "__main__":
    main()
