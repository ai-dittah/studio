#!/bin/bash
# =============================================================================
# DITTAH - Install Script
# =============================================================================
# One-command installation for Dittah Studio (Community Edition)
# Pulls pre-built images from Docker Hub and starts the stack.
#
# Usage: ./install.sh
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
echo -e "${BLUE}  DITTAH - Installation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# =============================================================================
# PREREQUISITE CHECKS
# =============================================================================

echo -e "${BLUE}Checking prerequisites...${NC}"

# Check Docker installed
if ! command -v docker &>/dev/null; then
    echo -e "${RED}ERROR: Docker is not installed.${NC}"
    echo "Install Docker from https://docs.docker.com/get-docker/"
    exit 1
fi
echo -e "  ${GREEN}Docker installed${NC}"

# Check Docker running
if ! docker info &>/dev/null; then
    echo -e "${RED}ERROR: Docker is not running.${NC}"
    echo "Please start Docker and try again."
    exit 1
fi
echo -e "  ${GREEN}Docker is running${NC}"

# Check Docker Compose v2
if ! docker compose version &>/dev/null; then
    echo -e "${RED}ERROR: Docker Compose v2 is not available.${NC}"
    echo "Docker Compose v2 is included with Docker Desktop."
    echo "See https://docs.docker.com/compose/install/"
    exit 1
fi
echo -e "  ${GREEN}Docker Compose v2 available${NC}"

echo ""

# =============================================================================
# ENVIRONMENT SETUP
# =============================================================================

if [ -f .env ]; then
    echo -e "${YELLOW}.env file already exists — keeping existing configuration.${NC}"
else
    if [ ! -f .env.example ]; then
        echo -e "${RED}ERROR: .env.example not found${NC}"
        exit 1
    fi

    echo -e "${BLUE}Creating .env from .env.example...${NC}"
    cp .env.example .env

    # Generate random passwords for all services
    GENERATED_POSTGRES_PW=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32 || true)
    GENERATED_ARTEMIS_PW=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32 || true)
    GENERATED_DB_APP_PW=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32 || true)
    GENERATED_DB_AUTH_PW=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32 || true)

    # Replace placeholder passwords in .env
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${GENERATED_POSTGRES_PW}/" .env
        sed -i '' "s/^ARTEMIS_PASSWORD=.*/ARTEMIS_PASSWORD=${GENERATED_ARTEMIS_PW}/" .env
        sed -i '' "s/^DB_APP_PASSWORD=.*/DB_APP_PASSWORD=${GENERATED_DB_APP_PW}/" .env
        sed -i '' "s/^DB_AUTH_PASSWORD=.*/DB_AUTH_PASSWORD=${GENERATED_DB_AUTH_PW}/" .env
        sed -i '' "s/^DITTAH_EDITION=.*/DITTAH_EDITION=COMMUNITY/" .env
    else
        sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${GENERATED_POSTGRES_PW}/" .env
        sed -i "s/^ARTEMIS_PASSWORD=.*/ARTEMIS_PASSWORD=${GENERATED_ARTEMIS_PW}/" .env
        sed -i "s/^DB_APP_PASSWORD=.*/DB_APP_PASSWORD=${GENERATED_DB_APP_PW}/" .env
        sed -i "s/^DB_AUTH_PASSWORD=.*/DB_AUTH_PASSWORD=${GENERATED_DB_AUTH_PW}/" .env
        sed -i "s/^DITTAH_EDITION=.*/DITTAH_EDITION=COMMUNITY/" .env
    fi

    echo -e "  ${GREEN}Generated random POSTGRES_PASSWORD${NC}"
    echo -e "  ${GREEN}Generated random ARTEMIS_PASSWORD${NC}"
    echo -e "  ${GREEN}Generated random DB_APP_PASSWORD${NC}"
    echo -e "  ${GREEN}Generated random DB_AUTH_PASSWORD${NC}"
    echo -e "  ${GREEN}Set DITTAH_EDITION=COMMUNITY${NC}"
fi

echo ""

# Load environment variables
source .env

# =============================================================================
# PULL IMAGES
# =============================================================================

echo -e "${BLUE}Pulling Dittah images from Docker Hub...${NC}"
docker compose pull
echo -e "  ${GREEN}Images pulled successfully${NC}"
echo ""

# =============================================================================
# START STACK
# =============================================================================

echo -e "${BLUE}Starting Dittah stack...${NC}"
docker compose up -d
echo ""

# =============================================================================
# HEALTH CHECKS
# =============================================================================

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

# =============================================================================
# STATUS
# =============================================================================

echo ""
echo -e "${BLUE}Current service status:${NC}"
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}  Installation complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Open ${GREEN}http://localhost:${UI_PORT:-4200}${NC} to complete the setup wizard:"
echo "  1. Select your profile (Light / Medium / Production)"
echo "  2. Create your admin account"
echo "  3. Start using Dittah!"
echo ""
echo "Useful commands:"
echo "  ./update.sh                      # Pull latest version and restart"
echo "  ./uninstall.sh                   # Remove Dittah and all data"
echo "  docker compose logs -f           # Follow all logs"
echo "  docker compose ps                # Show service status"
