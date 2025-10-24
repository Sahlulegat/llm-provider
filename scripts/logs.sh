#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}Showing Ollama logs (Ctrl+C to exit)...${NC}"
docker compose logs -f ollama
