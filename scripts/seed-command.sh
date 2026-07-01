#!/usr/bin/env bash
set -e

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"

publish_command() {
  local label="$1"
  local component_id="$2"
  local command="$3"
  local value="$4"
  local command_id="$5"
  local ts
  local topic
  local payload

  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  topic="seda/plants/mds/components/${component_id}/commands/${command_id}"
  payload="{\"command_id\":\"${command_id}\",\"plant_id\":\"mds\",\"component_id\":\"${component_id}\",\"command\":\"${command}\",\"value\":\"${value}\",\"requested_by\":\"seed-command\",\"ts\":\"${ts}\"}"

  echo "Publishing ${label}: topic=${topic} payload=${payload}"
  docker compose exec -T mosquitto mosquitto_pub -h localhost -t "${topic}" -m "${payload}"
}

publish_command "PVPCS START" "pv" "set_status" "on" "cmd-seed-pvpcs-start-${RUN_ID}"
publish_command "PVPCS STOP" "pv" "set_status" "off" "cmd-seed-pvpcs-stop-${RUN_ID}"
publish_command "Battery START" "battery" "set_status" "on" "cmd-seed-battery-start-${RUN_ID}"
publish_command "Battery STOP" "battery" "set_status" "off" "cmd-seed-battery-stop-${RUN_ID}"
publish_command "Simulator fault HIGH_TEMPERATURE" "simulator" "set_fault" "HIGH_TEMPERATURE" "cmd-seed-fault-high-temperature-${RUN_ID}"
echo "Waiting for simulator telemetry while HIGH_TEMPERATURE is active..."
sleep 7
publish_command "Simulator fault NONE" "simulator" "set_fault" "NONE" "cmd-seed-fault-none-${RUN_ID}"

echo "Seed operational commands published."
