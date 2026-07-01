.PHONY: help start stop restart ps logs check reset seed-command grafana nodered adminer prometheus

help:
	@echo "SEDA-Lab Reference Platform 1.0"
	@echo ""
	@echo "Targets:"
	@echo "  start         Start all services"
	@echo "  stop          Stop all services"
	@echo "  restart       Restart all services"
	@echo "  ps            Show service status"
	@echo "  logs          Follow all service logs"
	@echo "  check         Run platform checks"
	@echo "  reset         Reset volumes and restart"
	@echo "  seed-command  Publish sample ON/OFF commands"
	@echo "  grafana       Print Grafana URL"
	@echo "  nodered       Print Node-RED URL"
	@echo "  adminer       Print Adminer URL"
	@echo "  prometheus    Print Prometheus URL"

start:
	docker compose up -d

stop:
	docker compose stop

restart:
	docker compose restart

ps:
	docker compose ps

logs:
	docker compose logs -f

check:
	bash scripts/check-platform.sh

reset:
	bash scripts/reset-platform.sh

seed-command:
	bash scripts/seed-command.sh

grafana:
	@echo "http://localhost:3000"

nodered:
	@echo "http://localhost:1880"

adminer:
	@echo "http://localhost:8080"

prometheus:
	@echo "http://localhost:9090"
