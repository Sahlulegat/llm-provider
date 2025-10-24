#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   LLM Provider - Starting Ollama${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}No .env file found. Copying from .env.example...${NC}"
    cp .env.example .env
fi

# Source environment variables
source .env

# Create necessary directories
mkdir -p data/ollama logs config

# Start Docker Compose
echo -e "${GREEN}Starting Ollama container...${NC}"
docker compose up -d

# Wait for Ollama to be ready
echo -e "${YELLOW}Waiting for Ollama to be ready...${NC}"
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if curl -s http://localhost:${OLLAMA_PORT:-11434}/api/tags > /dev/null 2>&1; then
        echo -e "${GREEN}Ollama is ready!${NC}"
        break
    fi
    attempt=$((attempt + 1))
    echo -e "${YELLOW}Waiting... (attempt $attempt/$max_attempts)${NC}"
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo -e "${RED}Failed to connect to Ollama after $max_attempts attempts${NC}"
    exit 1
fi

# Pull model if configured
if [ "${MODEL_PULL_ON_START}" = "true" ]; then
    echo -e "${GREEN}Pulling model ${MODEL_NAME}...${NC}"
    echo -e "${YELLOW}This may take a while depending on model size...${NC}"
    docker compose exec ollama ollama pull ${MODEL_NAME}
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Services are running!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Ollama API: http://localhost:${OLLAMA_PORT:-11434}${NC}"
echo -e "${GREEN}   Open WebUI: http://localhost:${WEBUI_PORT:-3000}${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Open your browser and go to:${NC}"
echo -e "${GREEN}http://localhost:${WEBUI_PORT:-3000}${NC}"
echo ""
echo -e "First time? Create an account to get started!"
echo -e "The first user becomes the admin automatically."
echo ""
echo -e "Use ${YELLOW}./scripts/status.sh${NC} to check status"
echo -e "Use ${YELLOW}./scripts/stop.sh${NC} to stop the service"
echo -e "Use ${YELLOW}./scripts/logs.sh${NC} to view logs"
