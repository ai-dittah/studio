#!/bin/bash
# =============================================================================
# DITTAH - Password Reset / Rotation
# =============================================================================
# Rotates DB_APP_PASSWORD, DB_AUTH_PASSWORD, and ARTEMIS_PASSWORD to new
# random values. Syncs postgres roles via ALTER ROLE, then restarts the
# containers that consume these passwords.
#
# Usage: ./reset-passwords.sh [--force]
#   --force   Skip confirmation prompt
#
# Prerequisites:
#   - .env file exists in this directory
#   - dittah-postgres container is running (refuses to proceed otherwise)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Known insecure defaults (old and new)
KNOWN_DEFAULTS="cfappusr cfauthappusr artemis CHANGE_ME"

FORCE=false
[ "$1" = "--force" ] && FORCE=true

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  DITTAH - Password Reset${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# -------------------------------------------------------------------------
# Preflight
# -------------------------------------------------------------------------

if [ ! -f .env ]; then
    echo -e "${RED}ERROR: .env not found. Run ./install.sh first.${NC}"
    exit 1
fi

source .env

# Postgres must be running (we need ALTER ROLE)
if ! docker inspect dittah-postgres --format '{{.State.Running}}' 2>/dev/null | grep -q true; then
    echo -e "${RED}ERROR: dittah-postgres is not running.${NC}"
    echo "Start the stack first: docker compose up -d postgres"
    echo "Password rotation requires a running postgres to sync via ALTER ROLE."
    exit 1
fi

# -------------------------------------------------------------------------
# Show current status
# -------------------------------------------------------------------------

is_default() {
    local val="$1"
    for d in $KNOWN_DEFAULTS; do
        [ "$val" = "$d" ] && return 0
    done
    return 1
}

echo -e "${BLUE}Current password status:${NC}"
for var in DB_APP_PASSWORD DB_AUTH_PASSWORD ARTEMIS_PASSWORD; do
    val="${!var}"
    if [ -z "$val" ]; then
        echo -e "  $var: ${RED}(not set)${NC}"
    elif is_default "$val"; then
        echo -e "  $var: ${YELLOW}$val (insecure default)${NC}"
    else
        echo -e "  $var: ${GREEN}(custom)${NC}"
    fi
done
echo ""

# -------------------------------------------------------------------------
# Confirm
# -------------------------------------------------------------------------

if [ "$FORCE" != true ]; then
    echo -e "${YELLOW}This will:${NC}"
    echo "  1. Generate new random passwords for DB_APP, DB_AUTH, ARTEMIS"
    echo "  2. Update .env"
    echo "  3. ALTER ROLE in postgres to match"
    echo "  4. Restart artemis-mq, api, orchestrator, intelligence"
    echo ""
    read -p "Proceed? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

# -------------------------------------------------------------------------
# Backup .env
# -------------------------------------------------------------------------

BACKUP=".env.backup.$(date +%Y%m%d%H%M%S)"
cp .env "$BACKUP"
echo -e "${GREEN}Backed up .env to $BACKUP${NC}"

# -------------------------------------------------------------------------
# Generate new passwords
# -------------------------------------------------------------------------

NEW_DB_APP_PW=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32 || true)
NEW_DB_AUTH_PW=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32 || true)
NEW_ARTEMIS_PW=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32 || true)

# Update .env
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/^DB_APP_PASSWORD=.*/DB_APP_PASSWORD=${NEW_DB_APP_PW}/" .env
    sed -i '' "s/^DB_AUTH_PASSWORD=.*/DB_AUTH_PASSWORD=${NEW_DB_AUTH_PW}/" .env
    sed -i '' "s/^ARTEMIS_PASSWORD=.*/ARTEMIS_PASSWORD=${NEW_ARTEMIS_PW}/" .env
else
    sed -i "s/^DB_APP_PASSWORD=.*/DB_APP_PASSWORD=${NEW_DB_APP_PW}/" .env
    sed -i "s/^DB_AUTH_PASSWORD=.*/DB_AUTH_PASSWORD=${NEW_DB_AUTH_PW}/" .env
    sed -i "s/^ARTEMIS_PASSWORD=.*/ARTEMIS_PASSWORD=${NEW_ARTEMIS_PW}/" .env
fi

echo -e "${GREEN}Updated .env with new passwords${NC}"

# -------------------------------------------------------------------------
# Sync postgres roles via ALTER ROLE (superuser, no auth chicken-and-egg)
# -------------------------------------------------------------------------

echo -e "${BLUE}Syncing postgres roles...${NC}"

docker exec dittah-postgres psql -U postgres -d app -c \
    "ALTER ROLE cfappusr WITH PASSWORD '${NEW_DB_APP_PW}';" >/dev/null
echo -e "  ${GREEN}cfappusr password updated${NC}"

docker exec dittah-postgres psql -U postgres -d app -c \
    "ALTER ROLE cfauthappusr WITH PASSWORD '${NEW_DB_AUTH_PW}';" >/dev/null
echo -e "  ${GREEN}cfauthappusr password updated${NC}"

# -------------------------------------------------------------------------
# Restart containers that consume these passwords
# -------------------------------------------------------------------------

echo -e "${BLUE}Restarting services with new credentials...${NC}"

# Detect compose files in use
COMPOSE_CMD="docker compose"
if [ -f prod/docker-compose.prod.yml ] && docker compose -f docker-compose.yml -f prod/docker-compose.prod.yml ps --quiet 2>/dev/null | head -1 | grep -q .; then
    COMPOSE_CMD="docker compose -f docker-compose.yml -f prod/docker-compose.prod.yml"
fi

$COMPOSE_CMD up -d --force-recreate artemis-mq api orchestrator intelligence
echo -e "${GREEN}Services restarted${NC}"

# -------------------------------------------------------------------------
# Verify DB connectivity (TCP auth to force password check)
# -------------------------------------------------------------------------

echo ""
echo -e "${BLUE}Verifying database connectivity...${NC}"

# Wait for postgres to be ready after potential restart
sleep 3

verify_ok=true

if docker exec -e PGPASSWORD="${NEW_DB_APP_PW}" dittah-postgres \
    psql -h 127.0.0.1 -U cfappusr -d app -c "SELECT 1;" >/dev/null 2>&1; then
    echo -e "  ${GREEN}cfappusr: connected OK${NC}"
else
    echo -e "  ${RED}cfappusr: connection FAILED${NC}"
    verify_ok=false
fi

if docker exec -e PGPASSWORD="${NEW_DB_AUTH_PW}" dittah-postgres \
    psql -h 127.0.0.1 -U cfauthappusr -d app -c "SELECT 1;" >/dev/null 2>&1; then
    echo -e "  ${GREEN}cfauthappusr: connected OK${NC}"
else
    echo -e "  ${RED}cfauthappusr: connection FAILED${NC}"
    verify_ok=false
fi

if [ "$verify_ok" = false ]; then
    echo ""
    echo -e "${RED}Some verifications failed. Restore backup if needed:${NC}"
    echo "  cp $BACKUP .env"
    exit 1
fi

# -------------------------------------------------------------------------
# Done
# -------------------------------------------------------------------------

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Password reset complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Backup: $BACKUP"
echo "To verify services are healthy: docker compose ps"
