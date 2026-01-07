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

POSTGRES_USER ?= ayon
POSTGRES_PASSWORD ?= ayon
POSTGRES_DB ?= ayon
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
	@echo "  dump-entire      Use 'make dump-entire targetname=<targetname>' to backup the entire database, targetname is optional, no targetname uses 'backup_TIMESTAMP.sql', '_TIMESTAMP.sql' is always appended, targetname=test == test_TIMESTAMP.sql"
	@echo "  restore-entire      Use 'make restore-entire targetfilename=<targetfilename>' to restore the entire database"
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
	@docker compose exec -e PGPASSWORD=$(POSTGRES_PASSWORD) postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)

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

	docker compose exec -e PGPASSWORD=$(POSTGRES_PASSWORD) -T postgres pg_dump --table=public.projects --column-inserts -d $(POSTGRES_DB) -U $(POSTGRES_USER) | \
		grep "^INSERT INTO" | grep \'$(projectname)\' >> dump.$(projectname).sql

	@# Get all product types used in the project
	@# and insert them into the product_types table
	@# (if they don't exist yet)

	docker compose exec -e PGPASSWORD=$(POSTGRES_PASSWORD) postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -Atc "SELECT DISTINCT(product_type) from project_$(projectname).products;" | \
	while read -r product_type; do \
		echo "INSERT INTO public.product_types (name) VALUES ('$${product_type}') ON CONFLICT DO NOTHING;"; \
	done >> dump.$(projectname).sql

	@# Dump project schema (tables, views, etc.)

	docker compose exec -e PGPASSWORD=$(POSTGRES_PASSWORD) postgres pg_dump --schema=project_$(projectname) -d $(POSTGRES_DB) -U $(POSTGRES_USER) >> dump.$(projectname).sql

restore:
	@if [ -z "$(projectname)" ]; then \
  	echo "Error: Project name is required. Usage: make dump projectname=<projectname>"; \
		exit 1; \
	fi

	@if [ ! -f dump.$(projectname).sql ]; then \
		echo "Error: Dump file dump.$(projectname).sql not found"; \
		exit 1; \
	fi
	docker compose exec -e PGPASSWORD=$(POSTGRES_PASSWORD) -T postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) < dump.$(projectname).sql

dump-entire:
	$(eval TIMESTAMP := $(shell date +%y%m%d%H%M))
	$(eval TARGET := $(if $(targetname),$(targetname)_$(TIMESTAMP).sql,backup_$(TIMESTAMP).sql))
	@echo "Dumping entire database to $(TARGET)..."
	@docker compose exec -e PGPASSWORD=$(POSTGRES_PASSWORD) -T postgres pg_dump -U $(POSTGRES_USER) -d $(POSTGRES_DB) > $(TARGET)
	@echo "Done."

restore-entire:
	@if [ -z "$(targetfilename)" ]; then \
		echo "Error: targetfilename is required. Usage: make restore-entire targetfilename=<file.sql>"; \
		exit 1; \
	fi
	@if [ ! -f $(targetfilename) ]; then \
		echo "Error: File $(targetfilename) not found"; \
		exit 1; \
	fi
	@echo "Restoring entire database from $(targetfilename)..."
	@docker compose exec -e PGPASSWORD=$(POSTGRES_PASSWORD) -T postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) < $(targetfilename)
	@echo "Restore complete."
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

