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

# Export for docker-compose's variable substitution. HIEROPHANT_IMAGE
# reaches the SP1 fibonacci Dockerfile's `COPY --from=${HIEROPHANT_IMAGE}`
# step that pulls SP1 circuit artifacts out of the Hierophant image rather
# than re-vendoring them; the same value also picks the Hierophant
# container the docker-compose stack runs.
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
	@echo "Building both fibonacci Docker images ..."
	docker compose --profile all build
	@echo "Build complete."

# `make test` runs the full end-to-end fibonacci suite (both SP1 and RISC
# Zero) through docker-compose. There are no host-side unit tests to run;
# the host's rustc + SP1 / RISC Zero toolchains generally do not match the
# pinned versions petros ships, so a host `cargo test` would just trip
# rustc-version mismatches against fresh transitive deps. Run inside
# petros (via the docker-compose flow) where the toolchains are pinned.
.PHONY: test
test: scriptory

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

# `test-sp1` and `test-risc0` activate the matching docker-compose profile
# so only the selected fibonacci service runs alongside Hierophant and
# Magister. Both targets force `--build` so a stale fibonacci image doesn't
# silently mask a recent edit. Use the env-level overrides documented in
# `.env.example` (SP1_PROOF_SYSTEM, RISC0_PROOF_MODE, RISC0_WRAP_SNARK) to
# pick which proving mode each test exercises.
.PHONY: test-sp1
test-sp1:
	@echo "Starting SP1 fibonacci test ..."
	docker compose --profile sp1 up --build

.PHONY: test-risc0
test-risc0:
	@echo "Starting RISC Zero fibonacci test ..."
	docker compose --profile risc0 up --build

.PHONY: run
run: scriptory

# `make scriptory` runs both fibonacci tests in the same compose stack so a
# user with a dual-VM Contemplant pool sees both proof flows light up at
# once. Use `make test-sp1` or `make test-risc0` to drive only one VM.
.PHONY: scriptory
scriptory:
	@echo "Starting scriptory services (SP1 + RISC Zero fibonacci) ..."
	docker compose --profile all up --build

.PHONY: scriptory-d
scriptory-d:
	@echo "Starting scriptory services in detached mode ..."
	docker compose --profile all up --build -d
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
	@echo "  build           Build both fibonacci Docker images (sp1 and risc0)."
	@echo "  test            Alias for scriptory. Runs both end-to-end tests."
	@echo "  docker          Build both fibonacci Docker images."
	@echo "  ci              Build both fibonacci Docker images."
	@echo "  test-sp1        Run the SP1 fibonacci end-to-end test."
	@echo "  test-risc0      Run the RISC Zero fibonacci end-to-end test."
	@echo "  run             Alias for scriptory."
	@echo "  run-h           Run just Hierophant."
	@echo "  run-m           Run Magister (starts Hierophant if needed)."
	@echo "  scriptory       Start all services (both VM tests) in foreground."
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

