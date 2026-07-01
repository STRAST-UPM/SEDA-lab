#!/usr/bin/env bash
set -e

printf "This will remove Docker volumes and reset PostgreSQL/Grafana data. Type RESET to continue: "
read -r confirmation

if [ "$confirmation" != "RESET" ]; then
  echo "Reset aborted."
  exit 0
fi

docker compose down -v
docker compose up -d
