#!/usr/bin/env bash
set -e

echo "== SEDA-Lab platform check =="
echo

echo "== Docker services =="
docker compose ps
echo

echo "== PostgreSQL counts =="
docker compose exec -T postgres psql -U seda -d seda_lab -c "select count(*) as measurement_count from measurement;"
docker compose exec -T postgres psql -U seda -d seda_lab -c "select count(*) as command_count from command;"
docker compose exec -T postgres psql -U seda -d seda_lab -c "select count(*) as alarm_count from alarm;"
echo

echo "== HTTP endpoints =="
echo "-- /seda/status"
curl -s --fail --retry 10 --retry-delay 2 --retry-all-errors http://localhost:1880/seda/status
echo
echo

echo "-- /seda/latest-measurements"
curl -s --fail --retry 10 --retry-delay 2 --retry-all-errors http://localhost:1880/seda/latest-measurements
echo
echo

echo "-- /seda/latest-commands"
curl -s --fail --retry 10 --retry-delay 2 --retry-all-errors http://localhost:1880/seda/latest-commands
echo
echo

echo "-- /seda/latest-alarms"
curl -s --fail --retry 10 --retry-delay 2 --retry-all-errors http://localhost:1880/seda/latest-alarms
echo
echo

echo "== Check complete =="
