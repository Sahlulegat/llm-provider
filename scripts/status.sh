#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   LLM Provider Status${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if container is running
if docker compose ps | grep -q "ollama-provider.*Up"; then
    echo -e "${GREEN}Status: Running${NC}"

    # Get container stats
    echo -e "\n${YELLOW}Container Info:${NC}"
    docker compose ps

    # Check API health
    source .env 2>/dev/null || true
    PORT=${OLLAMA_PORT:-11434}

    echo -e "\n${YELLOW}API Health:${NC}"
    if curl -s http://localhost:$PORT/api/tags > /dev/null 2>&1; then
        echo -e "${GREEN}API is responding${NC}"

        # List loaded models
        echo -e "\n${YELLOW}Available Models:${NC}"
        curl -s http://localhost:$PORT/api/tags | python3 -m json.tool 2>/dev/null || echo "Unable to parse models"
    else
        echo -e "${RED}API is not responding${NC}"
    fi

else
    echo -e "${RED}Status: Stopped${NC}"
fi

echo -e "\n${BLUE}========================================${NC}"
