#!/bin/bash
# =============================================================================
# DITTAH - Uninstall Script
# =============================================================================
# Stops all containers, removes volumes and data.
#
# Usage: ./uninstall.sh
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
echo -e "${BLUE}  DITTAH - Uninstall${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}WARNING: This will stop all Dittah containers and delete all data.${NC}"
echo ""

read -p "Are you sure you want to uninstall Dittah? (y/N) " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo -e "${BLUE}Stopping containers and removing volumes...${NC}"
docker compose down -v

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}  Uninstall complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "All containers and data volumes have been removed."
echo "Your .env file has been kept. To fully clean up, remove this directory."
