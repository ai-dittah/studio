#!/bin/bash
# healthcheck.sh - Verify all services are healthy

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load port overrides from .env if present
if [ -f .env ]; then
  source .env
fi

API_PORT="${REST_SERVER_PORT:-8080}"
UI_PORT="${UI_PORT:-4200}"
ARTEMIS_PORT="${ARTEMIS_CONSOLE_PORT:-8161}"

echo "Checking Dittah services..."

# Check PostgreSQL
echo -n "PostgreSQL: "
if docker compose exec -T postgres pg_isready -U postgres > /dev/null 2>&1; then
  echo "OK"
else
  echo "FAILED"
  exit 1
fi

# Check Artemis
echo -n "Artemis MQ: "
if curl -sf "http://localhost:${ARTEMIS_PORT}/console" > /dev/null 2>&1; then
  echo "OK"
else
  echo "FAILED"
  exit 1
fi

# Check REST Server
echo -n "REST Server: "
if curl -sf "http://localhost:${API_PORT}/api/setup/status" > /dev/null 2>&1; then
  echo "OK"
else
  echo "FAILED"
  exit 1
fi

# Check UI
echo -n "UI: "
if curl -sf "http://localhost:${UI_PORT}" > /dev/null 2>&1; then
  echo "OK"
else
  echo "FAILED"
  exit 1
fi

echo ""
echo "All services healthy!"
