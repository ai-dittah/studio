#!/bin/bash
# =============================================================================
# DITTAH 3.0 - One-Click Deployment Script
# =============================================================================
# Usage: ./deploy.sh [--pull] [--fresh]
#   --pull    Pull latest images from registry before starting
#   --fresh   Remove volumes and start fresh (WARNING: deletes all data)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
PULL_IMAGES=false
FRESH_START=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --pull) PULL_IMAGES=true ;;
        --fresh) FRESH_START=true ;;
        -h|--help)
            echo "Usage: $0 [--pull] [--fresh]"
            echo "  --pull    Pull latest images from registry before starting"
            echo "  --fresh   Remove volumes and start fresh (WARNING: deletes all data)"
            exit 0
            ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  DITTAH 3.0 - One-Click Deployment${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check for .env file
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating .env from .env.example...${NC}"
    if [ -f .env.example ]; then
        cp .env.example .env
    else
        echo -e "${RED}ERROR: No .env or .env.example found${NC}"
        exit 1
    fi
fi

# Load environment variables
source .env

# Fresh start - remove volumes
if [ "$FRESH_START" = true ]; then
    echo -e "${YELLOW}WARNING: Fresh start requested - removing all data volumes${NC}"
    read -p "Are you sure? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Stopping containers and removing volumes...${NC}"
        docker compose down -v 2>/dev/null || true
    else
        echo "Aborted."
        exit 0
    fi
fi

# Pull images if requested
if [ "$PULL_IMAGES" = true ]; then
    echo -e "${BLUE}Pulling Docker images from registry...${NC}"
    docker compose pull
fi

# Check if images exist
REQUIRED_IMAGES=(
    "${DITTAH_IMAGE_REGISTRY:-dittah}/studio-api:${DITTAH_VERSION:-latest}"
    "${DITTAH_IMAGE_REGISTRY:-dittah}/studio-orchestrator:${DITTAH_VERSION:-latest}"
    "${DITTAH_IMAGE_REGISTRY:-dittah}/studio-ui:${DITTAH_VERSION:-latest}"
    "${DITTAH_IMAGE_REGISTRY:-dittah}/studio-intelligence:${DITTAH_VERSION:-latest}"
    "${DITTAH_IMAGE_REGISTRY:-dittah}/studio-postgres:${DITTAH_VERSION:-latest}"
)

MISSING_IMAGES=false
for img in "${REQUIRED_IMAGES[@]}"; do
    if ! docker image inspect "$img" &>/dev/null; then
        echo -e "${YELLOW}Missing image: $img${NC}"
        MISSING_IMAGES=true
    fi
done

if [ "$MISSING_IMAGES" = true ]; then
    echo -e "${YELLOW}Some images are missing. Pulling from registry...${NC}"
    docker compose pull
fi

# Start the stack
echo -e "${BLUE}Starting DITTAH stack...${NC}"
docker compose up -d

# Wait for services to be healthy
echo -e "${BLUE}Waiting for services to be healthy...${NC}"

# Function to check service health
check_health() {
    local service=$1
    local max_attempts=${2:-60}
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        status=$(docker compose ps --format json "$service" 2>/dev/null | grep -o '"Health":"[^"]*"' | cut -d'"' -f4 || echo "unknown")

        if [ "$status" = "healthy" ]; then
            echo -e "  ${GREEN}$service: healthy${NC}"
            return 0
        fi

        printf "\r  $service: waiting... (%d/%d)" $attempt $max_attempts
        sleep 2
        ((attempt++))
    done

    echo -e "\n  ${YELLOW}$service: timeout (may still be starting)${NC}"
    return 1
}

echo ""
check_health "postgres" 30 || true
check_health "artemis-mq" 30 || true
check_health "api" 60 || true
check_health "intelligence" 30 || true

# Show status
echo ""
echo -e "${BLUE}Current service status:${NC}"
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

# Check if setup is needed
echo ""
echo -e "${BLUE}Checking application status...${NC}"
sleep 5

SETUP_STATUS=$(curl -s http://localhost:${REST_SERVER_PORT:-8080}/api/setup/status 2>/dev/null || echo '{"error":"not ready"}')

if echo "$SETUP_STATUS" | grep -q '"setupComplete":false'; then
    echo -e "${YELLOW}Setup required!${NC}"
    echo -e "Open ${GREEN}http://localhost:${UI_PORT:-4200}${NC} to complete setup wizard"
elif echo "$SETUP_STATUS" | grep -q '"setupComplete":true'; then
    echo -e "${GREEN}Setup complete!${NC}"
    echo -e "Open ${GREEN}http://localhost:${UI_PORT:-4200}${NC} to access the application"
else
    echo -e "${YELLOW}Application starting...${NC}"
    echo -e "Open ${GREEN}http://localhost:${UI_PORT:-4200}${NC} once ready"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}  Deployment complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Useful commands:"
echo "  docker compose logs -f          # Follow all logs"
echo "  docker compose logs -f api          # Follow API server logs"
echo "  docker compose ps               # Show service status"
echo "  docker compose down             # Stop all services"
echo "  ./deploy.sh --fresh              # Reset and start fresh"
