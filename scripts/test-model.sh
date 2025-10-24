#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

source .env 2>/dev/null || true
MODEL=${MODEL_NAME:-gpt-oss:120b}
PORT=${OLLAMA_PORT:-11434}

echo -e "${GREEN}Testing model: ${MODEL}${NC}"
echo -e "${YELLOW}Sending test prompt...${NC}"

curl -s http://localhost:$PORT/api/generate -d "{
  \"model\": \"$MODEL\",
  \"prompt\": \"Hello! Please introduce yourself briefly.\",
  \"stream\": false
}" | python3 -m json.tool

echo -e "\n${GREEN}Test completed${NC}"
