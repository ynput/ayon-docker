#
# Settings
#

SETTINGS_FILE=settings/template.json
IMAGE_NAME=ynput/ayon
SERVER_CONTAINER=server
TAG=dev

#
# Variables
#

# Abstract the 'docker compose' / 'docker-compose' command
COMPOSE=$(shell which docker-compose || echo "docker compose")

# Shortcut for the setup command
SETUP_CMD=$(COMPOSE) exec -T $(SERVER_CONTAINER) python -m setup

# By default, just show the usage message

default:
	@echo ""
	@echo "Ayon server $(TAG)"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Runtime targets:"
	@echo "  setup     Apply settings template form the settings/template.json"
	@echo "  dbshell   Open a PostgreSQL shell"
	@echo "  reload    Reload the running server"
	@echo "  demo      Create demo projects based on settings in demo directory"
	@echo ""
	@echo "Development:"
	@echo "  backend   Download / update backend"
	@echo "  frontend  Download / update frontend"
	@echo "  build     Build docker image"
	@echo "  dist      Publish docker image to docker hub"
	

.PHONY: backend frontend build demo

# Makefile syntax, oh so bad
# Errors abound, frustration high
# Gotta love makefiles

setup:
ifneq (,"$(wildcard ./settings/template.json)")
	$(SETUP_CMD) - < $(SETTINGS_FILE)
else
	$(SETUP_CMD)
endif
	@$(COMPOSE) exec $(SERVER_CONTAINER) ./reload.sh

dbshell:
	@$(COMPOSE) exec postgres psql -U ayon ayon

reload:
	@$(COMPOSE) exec $(SERVER_CONTAINER) ./reload.sh

demo:
	$(foreach file, $(wildcard demo/*.json), $(COMPOSE) exec -T $(SERVER_CONTAINER) python -m demogen < $(file);)

links:
	$(foreach file, $(wildcard demo/*.json), $(COMPOSE) exec -T $(SERVER_CONTAINER) python -m linker < $(file);)

update:
	docker pull $(IMAGE_NAME):$(TAG)
	$(COMPOSE) up --detach --build $(SERVER_CONTAINER)
 
#
# The following targets are for development purposes only.
#

build: backend frontend
	@# Build the docker image
	docker build -t $(IMAGE_NAME):$(TAG) .

dist: build
	@# Publish the docker image to the registry
	docker push $(IMAGE_NAME):$(TAG)

backend:
	@# Clone / update the backend repository
	@[ -d $@ ] || git clone https://github.com/ynput/ayon-backend $@
	@cd $@ && git pull

frontend:
	@# Clone / update the frontend repository
	@[ -d $@ ] || git clone https://github.com/ynput/ayon-frontend $@
	@cd $@ && git pull
