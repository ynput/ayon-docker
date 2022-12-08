SETTINGS_FILE=settings/template.json
IMAGE_NAME=ynput/ayon
SERVER_CONTAINER=server

TAG=$(shell cd backend/ && git describe --tags --always --dirty)
COMPOSE=$(shell which docker-compose || echo "docker compose")
SETUP_CMD=$(COMPOSE) exec -T $(SERVER_CONTAINER) python -m setup

.PHONY: backend frontend build demo

default:
	@echo ""
	@echo "Ayon server $(TAG)"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Runtime targets:"
	@echo "  setup     Apply settings tempate form the settings/template.json"
	@echo "  dbshell   Open a PostgreSQL shell"
	@echo "  reload    Reload the running server"
	@echo "  demo      Create demo projects based on settings in demo directory"
	@echo ""
	@echo "Development:"
	@echo "  backend   Download / update backend"
	@echo "  frontend  Download / update frontend"
	@echo "  build     Build docker image"
	@echo "  dist      Publish docker image to docker hub"
	
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
	@$(COMPOSE) exec postgres psql -U pypeusr pype

reload:
	@$(COMPOSE) exec $(SERVER_CONTAINER) ./reload.sh

demo:
	$(foreach file, $(wildcard demo/*.json), $(COMPOSE) exec -T $(SERVER_CONTAINER) python -m demogen < $(file);)
 
#
# The following targets are for development purposes only.
#

build: backend frontend
	# Build the docker image
	docker build -t $(IMAGE_NAME):$(TAG) -t $(IMAGE_NAME):latest .

dist: build
	# Publish the docker image to the registry
	docker push $(IMAGE_NAME):$(TAG) && docker push $(IMAGE_NAME):latest

backend:
	# Clone / update the backend repository
	@[ -d $@ ] || git clone https://github.com/pypeclub/openpype4-backend $@
	@cd $@ && git pull

frontend:
	# Clone / update the frontend repository
	@[ -d $@ ] || git clone https://github.com/pypeclub/openpype4-frontend $@
	@cd $@ && git pull
