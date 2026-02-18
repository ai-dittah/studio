#!/bin/bash
# =============================================================================
# DITTAH - Update Script
# =============================================================================
# Pulls the latest images and restarts the stack.
#
# Usage: ./update.sh
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

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  DITTAH - Update${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check for .env file
if [ ! -f .env ]; then
    echo -e "${RED}ERROR: .env file not found. Run ./install.sh first.${NC}"
    exit 1
fi

# Load environment variables
source .env

# Pull latest images
echo -e "${BLUE}Pulling latest images...${NC}"
docker compose pull
echo -e "  ${GREEN}Images updated${NC}"
echo ""

# Restart stack
echo -e "${BLUE}Restarting Dittah stack...${NC}"
docker compose up -d
echo ""

# Health checks
echo -e "${BLUE}Waiting for services to be healthy...${NC}"

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

# Status
echo ""
echo -e "${BLUE}Current service status:${NC}"
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}  Update complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Open ${GREEN}http://localhost:${UI_PORT:-4200}${NC} to access Dittah."
