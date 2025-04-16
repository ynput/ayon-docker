#
# Settings
#

ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Use .env file to set the following configuration variables

AYON_STACK_SETTINGS_FILE ?= settings/template.json
AYON_STACK_SERVER_NAME ?= ynput/ayon
AYON_STACK_SERVER_TAG ?= latest

#
# Variables
#

SERVER_CONTAINER=server
SETUP_CMD=docker compose exec -T $(SERVER_CONTAINER) python -m setup

# By default, just show the usage message

default:
	@echo ""
	@echo "Ayon server $(AYON_STACK_SERVER_TAG)"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Runtime targets:"
	@echo "  setup     Apply settings template form the settings/template.json"
	@echo "  dbshell   Open a PostgreSQL shell"
	@echo "  reload    Reload the running server"
	@echo "  demo      Create demo projects based on settings in demo directory"
	@echo "  dump      Use 'make dump projectname=<projectname>' to backup a project"
	@echo "  restore   Use 'make restore projectname=<projectname>' to restore a project from previous dump"
	@echo ""
	@echo "Development:"
	@echo "  backend   Download / update backend"
	@echo "  frontend  Download / update frontend"
	@echo "  build     Build docker image"
	@echo "  relinfo   Create RELEASE file with version info (debugging)"


.PHONY: backend frontend build demo

# Makefile syntax, oh so bad
# Errors abound, frustration high
# Gotta love makefiles

setup:
ifneq (,"$(wildcard ./settings/template.json)")
	$(SETUP_CMD) - < $(AYON_STACK_SETTINGS_FILE)
else
	$(SETUP_CMD)
endif
	@docker compose exec $(SERVER_CONTAINER) ./reload.sh

dbshell:
	@docker compose exec postgres psql -U ayon ayon

reload:
	@docker compose exec $(SERVER_CONTAINER) ./reload.sh

demo:
	$(foreach file, $(wildcard demo/*.json), docker compose exec -T $(SERVER_CONTAINER) python -m demogen < $(file);)

links:
	$(foreach file, $(wildcard demo/*.json), docker compose exec -T $(SERVER_CONTAINER) python -m linker < $(file);)

update:
	docker pull $(AYON_STACK_SERVER_NAME):$(AYON_STACK_SERVER_TAG)
	docker compose up --detach --build $(SERVER_CONTAINER)

dump:
	@if [ -z "$(projectname)" ]; then \
		echo "Error: Project name is required. Usage: make dump projectname=<projectname>"; \
		exit 1; \
  	fi

	@# Create a statement to remove project if already exists

	echo "DROP SCHEMA IF EXISTS project_$(projectname) CASCADE;" > dump.$(projectname).sql
	echo "DELETE FROM public.projects WHERE name = '$(projectname)';" >> dump.$(projectname).sql

	@# Dump project data from public.projects table

	docker compose exec -t postgres pg_dump --table=public.projects --column-inserts ayon -U ayon | \
		grep "^INSERT INTO" | grep \'$(projectname)\' >> dump.$(projectname).sql

	@# Get all product types used in the project
	@# and insert them into the product_types table
	@# (if they don't exist yet)

	docker compose exec postgres psql -U ayon ayon -Atc "SELECT DISTINCT(product_type) from project_$(projectname).products;" | \
	while read -r product_type; do \
		echo "INSERT INTO public.product_types (name) VALUES ('$${product_type}') ON CONFLICT DO NOTHING;"; \
	done >> dump.$(projectname).sql

	@# Dump project schema (tables, views, etc.)

	docker compose exec postgres pg_dump --schema=project_$(projectname) ayon -U ayon >> dump.$(projectname).sql



restore:
	@if [ -z "$(projectname)" ]; then \
  	echo "Error: Project name is required. Usage: make dump projectname=<projectname>"; \
		exit 1; \
	fi

	@if [ ! -f dump.$(projectname).sql ]; then \
		echo "Error: Dump file dump.$(projectname).sql not found"; \
		exit 1; \
	fi
	docker compose exec -T postgres psql -U ayon ayon < dump.$(projectname).sql

#
# The following targets are for development purposes only.
#

backend:
	@# Clone / update the backend repository
	@[ -d $@ ] || git clone https://github.com/ynput/ayon-backend $@
	@cd $@ && git pull

frontend:
	@# Clone / update the frontend repository
	@[ -d $@ ] || git clone https://github.com/ynput/ayon-frontend $@
	@cd $@ && git pull

relinfo:
	echo version=$(shell cd backend && python -c "from ayon_server import __version__; print(__version__)") > RELEASE
	echo build_date=$(shell date +%Y%m%d) >> RELEASE
	echo build_time=$(shell date +%H%M) >> RELEASE
	echo frontend_branch=$(shell cd frontend && git branch --show-current) >> RELEASE
	echo backend_branch=$(shell cd backend && git branch --show-current) >> RELEASE
	echo frontend_commit=$(shell cd frontend && git rev-parse --short HEAD) >> RELEASE
	echo backend_commit=$(shell cd backend && git rev-parse --short HEAD) >> RELEASE

build: backend frontend relinfo
	@# Build the docker image
	docker build -t $(AYON_STACK_SERVER_NAME):$(AYON_STACK_SERVER_TAG) .

