#!/usr/bin/env bash
set -e

docker compose logs -f simulator nodered grafana
