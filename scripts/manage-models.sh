#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

source .env 2>/dev/null || true

show_help() {
    echo -e "${BLUE}Model Management Script${NC}"
    echo ""
    echo "Usage: $0 [command] [model_name]"
    echo ""
    echo "Commands:"
    echo "  list              - List all available models"
    echo "  pull <model>      - Pull/download a model"
    echo "  remove <model>    - Remove a model"
    echo "  show <model>      - Show model details"
    echo ""
    echo "Examples:"
    echo "  $0 list"
    echo "  $0 pull gpt-oss:120b"
    echo "  $0 show gpt-oss:120b"
    echo "  $0 remove gpt-oss:120b"
}

list_models() {
    echo -e "${GREEN}Available models:${NC}"
    docker compose exec ollama ollama list
}

pull_model() {
    if [ -z "$1" ]; then
        echo -e "${RED}Error: Model name required${NC}"
        echo "Usage: $0 pull <model_name>"
        exit 1
    fi
    echo -e "${GREEN}Pulling model: $1${NC}"
    echo -e "${YELLOW}This may take a while...${NC}"
    docker compose exec ollama ollama pull "$1"
}

remove_model() {
    if [ -z "$1" ]; then
        echo -e "${RED}Error: Model name required${NC}"
        echo "Usage: $0 remove <model_name>"
        exit 1
    fi
    echo -e "${YELLOW}Removing model: $1${NC}"
    docker compose exec ollama ollama rm "$1"
}

show_model() {
    if [ -z "$1" ]; then
        echo -e "${RED}Error: Model name required${NC}"
        echo "Usage: $0 show <model_name>"
        exit 1
    fi
    echo -e "${GREEN}Model details: $1${NC}"
    docker compose exec ollama ollama show "$1"
}

case "$1" in
    list)
        list_models
        ;;
    pull)
        pull_model "$2"
        ;;
    remove)
        remove_model "$2"
        ;;
    show)
        show_model "$2"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac
