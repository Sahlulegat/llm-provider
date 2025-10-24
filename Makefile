.PHONY: help start stop restart status logs test pull-model clean

help:
	@echo "LLM Provider - Available Commands"
	@echo "=================================="
	@echo "  make start        - Start the Ollama service"
	@echo "  make stop         - Stop the Ollama service"
	@echo "  make restart      - Restart the Ollama service"
	@echo "  make status       - Check service status"
	@echo "  make logs         - View service logs"
	@echo "  make test         - Test the model"
	@echo "  make pull-model   - Pull the configured model"
	@echo "  make clean        - Remove all containers and volumes (WARNING: deletes data)"
	@echo ""

start:
	@./scripts/start.sh

stop:
	@./scripts/stop.sh

restart: stop start

status:
	@./scripts/status.sh

logs:
	@./scripts/logs.sh

test:
	@./scripts/test-model.sh

pull-model:
	@source .env && ./scripts/manage-models.sh pull $${MODEL_NAME}

clean:
	@echo "WARNING: This will remove all containers, volumes and data!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker compose down -v; \
		rm -rf data/ logs/; \
		echo "Clean completed"; \
	fi
