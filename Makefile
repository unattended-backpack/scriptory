# Configuration is loaded from `.env.maintainer` and can be overridden by
# environment variables.
#
# Usage:
#   make build                    # Build using `.env.maintainer`.
#   BUILD_IMAGE=... make build    # Override specific variables.

# Load configuration from `.env.maintainer` if it exists.
-include .env.maintainer

# Load configuration from `.env` if it exists.
-include .env

# Allow environment variable overrides with defaults.
BUILD_IMAGE ?= unattended/petros:latest
HIEROPHANT_IMAGE ?= unattended/hierophant:latest
MAGISTER_IMAGE ?= unattended/magister:latest
COMPOSE_FILE ?= docker-compose.yml

# Export variables for docker-compose to use.
export BUILD_IMAGE
export HIEROPHANT_IMAGE
export MAGISTER_IMAGE

.PHONY: init
init:
	@echo "Initializing configuration files ..."
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "Created .env from .env.example."; \
	else \
		echo ".env already exists."; \
	fi
	@if [ ! -f hierophant.toml ]; then \
		cp hierophant.example.toml hierophant.toml; \
		echo "Created hierophant.toml from hierophant.example.toml."; \
	else \
		echo "hierophant.toml already exists."; \
	fi
	@if [ ! -f magister.toml ]; then \
		cp magister.example.toml magister.toml; \
		echo "Created magister.toml from magister.example.toml."; \
	else \
		echo "magister.toml already exists."; \
	fi
	@echo "Initialization complete. Review configuration before running."

.PHONY: clean
clean:
	@bash -c 'echo -e "\033[33mWARNING: This will remove volumes.\033[0m"; \
	read -p "Are you sure you want to continue? [y/N]: " confirm; \
	if [[ "$$confirm" != "y" && "$$confirm" != "Y" ]]; then \
		echo "Operation cancelled."; \
		exit 1; \
	fi'
	docker compose down -v
	@echo "Cleanup complete."

.PHONY: build
build:
	@echo "Building fibonacci Docker image ..."
	docker compose build fibonacci
	@echo "Build complete."

.PHONY: test
test:
	@echo "Running fibonacci tests ..."
	cd src/fibonacci && cargo test --release
	@echo "Tests completed."

.PHONY: docker
docker: build

.PHONY: ci
ci: build

.PHONY: run-h
run-h:
	@echo "Starting Hierophant ..."
	docker compose up hierophant

.PHONY: run-m
run-m:
	@echo "Starting Magister (and Hierophant if needed) ..."
	docker compose up magister

.PHONY: run-f
run-f:
	@echo "Starting fibonacci test (and dependencies if needed) ..."
	docker compose up fibonacci

.PHONY: run
run: scriptory

.PHONY: scriptory
scriptory:
	@echo "Starting scriptory services ..."
	docker compose up --build

.PHONY: scriptory-d
scriptory-d:
	@echo "Starting scriptory services in detached mode ..."
	docker compose up --build -d
	@echo "Services started. Use 'make logs' to view output."

.PHONY: stop
stop:
	@echo "Stopping scriptory services ..."
	docker compose down

.PHONY: restart
restart: stop scriptory

.PHONY: logs
logs:
	@echo "Following logs (Ctrl+C to exit) ..."
	docker compose logs -f

.PHONY: status
status:
	@echo "Scriptory service status:"
	@docker compose ps

.PHONY: help
help:
	@echo "Build System"
	@echo ""
	@echo "Targets:"
	@echo "  init            Initialize config from examples."
	@echo "  clean           Clean volumes."
	@echo "  build           Build the fibonacci Docker image."
	@echo "  test            Run fibonacci tests."
	@echo "  docker          Build the fibonacci Docker image."
	@echo "  ci              Build the fibonacci Docker image."
	@echo "  run             Run all Scriptory services."
	@echo "  run-h           Run just Hierophant."
	@echo "  run-m           Run Magister (starts Hierophant if needed)."
	@echo "  run-f           Run fibonacci test (starts all dependencies)."
	@echo "  scriptory       Start all services in foreground."
	@echo "  scriptory-d     Start all services in background."
	@echo "  stop            Stop all services."
	@echo "  restart         Restart all services."
	@echo "  logs            Follow logs from all services."
	@echo "  status          Show service status."
	@echo "  help            Show this help message."
	@echo ""
	@echo "Configuration:"
	@echo "  Variables are loaded from .env.maintainer."
	@echo "  Override with environment variables:"
	@echo "    COMPOSE_FILE  - Docker compose file."
	@echo ""
	@echo "Examples:"
	@echo "  make build"
	@echo "  BUILD_IMAGE=unattended/petros:latest make build"

.DEFAULT_GOAL := build

