#!/usr/bin/env bash
set -e

echo "Publishing Battery OFF command..."
docker compose exec -T mosquitto mosquitto_pub -h localhost -t 'seda/plants/mds/components/battery/commands/cmd-seed-off' -m '{"command_id":"cmd-seed-off","plant_id":"mds","component_id":"battery","command":"set_status","value":"off","requested_by":"seed-command","ts":"2026-01-01T00:00:00Z"}'

echo "Publishing Battery ON command..."
docker compose exec -T mosquitto mosquitto_pub -h localhost -t 'seda/plants/mds/components/battery/commands/cmd-seed-on' -m '{"command_id":"cmd-seed-on","plant_id":"mds","component_id":"battery","command":"set_status","value":"on","requested_by":"seed-command","ts":"2026-01-01T00:01:00Z"}'

echo "Seed commands published."
