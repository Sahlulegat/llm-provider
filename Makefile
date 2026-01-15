.PHONY: help start stop restart status logs test pull-model clean \
        monitor-status monitor-logs monitor-test monitor-enable monitor-disable

help:
	@echo "LLM Provider - Available Commands"
	@echo "=================================="
	@echo "Service Management:"
	@echo "  make start        - Start all services (Ollama + WebUI + Caddy)"
	@echo "  make stop         - Stop all services"
	@echo "  make restart      - Restart all services"
	@echo "  make status       - Check service status"
	@echo "  make logs         - View service logs"
	@echo "  make test         - Test the model"
	@echo "  make pull-model   - Pull the configured model"
	@echo "  make clean        - Remove all containers and volumes (WARNING: deletes data)"
	@echo ""
	@echo "Auto-Shutdown Monitoring (Cost Optimization):"
	@echo "  make monitor-status   - Check auto-shutdown monitor status"
	@echo "  make monitor-logs     - View monitoring logs (live)"
	@echo "  make monitor-test     - Test inactivity detection (dry-run)"
	@echo "  make monitor-enable   - Enable auto-shutdown monitoring"
	@echo "  make monitor-disable  - Disable auto-shutdown monitoring"
	@echo ""
	@echo "Caddy reverse proxy s'active automatiquement si DOMAIN_NAME est configuré"
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

# ============================================
# Auto-Shutdown Monitoring Commands
# ============================================

monitor-status:
	@echo "=== Auto-Shutdown Monitor Status ==="
	@echo ""
	@echo "Timer Status:"
	@systemctl status llm-monitor-inactivity.timer --no-pager || echo "Timer not found (run on server)"
	@echo ""
	@echo "Service Status:"
	@systemctl status llm-monitor-inactivity.service --no-pager || echo "Service not found (run on server)"
	@echo ""
	@echo "Next scheduled run:"
	@systemctl list-timers llm-monitor-inactivity.timer --no-pager || true

monitor-logs:
	@echo "=== Auto-Shutdown Monitor Logs (live) ==="
	@echo "Press Ctrl+C to exit"
	@echo ""
	@journalctl -u llm-monitor-inactivity.service -f || echo "Run this command on the server"

monitor-test:
	@echo "=== Testing Inactivity Detection (dry-run) ==="
	@echo "This will check inactivity but NOT shutdown the server"
	@echo ""
	@bash ./scripts/monitor-inactivity.sh || echo "Run this command on the server: sudo bash /opt/llm-provider/scripts/monitor-inactivity.sh"

monitor-enable:
	@echo "=== Enabling Auto-Shutdown Monitoring ==="
	@systemctl enable llm-monitor-inactivity.timer || echo "Run on server: sudo systemctl enable llm-monitor-inactivity.timer"
	@systemctl start llm-monitor-inactivity.timer || echo "Run on server: sudo systemctl start llm-monitor-inactivity.timer"
	@echo ""
	@echo "✅ Auto-shutdown monitoring enabled"
	@echo "   Server will shutdown after 1h of inactivity"
	@echo "   Checks run every 5 minutes"

monitor-disable:
	@echo "=== Disabling Auto-Shutdown Monitoring ==="
	@systemctl stop llm-monitor-inactivity.timer || echo "Run on server: sudo systemctl stop llm-monitor-inactivity.timer"
	@systemctl disable llm-monitor-inactivity.timer || echo "Run on server: sudo systemctl disable llm-monitor-inactivity.timer"
	@echo ""
	@echo "⏸️  Auto-shutdown monitoring disabled"
	@echo "   Server will remain online until manual shutdown"
