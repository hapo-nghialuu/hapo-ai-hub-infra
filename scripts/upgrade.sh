#!/bin/bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════
# hapo-ai-hub Upgrade Script
# Usage: ./scripts/upgrade.sh [version]
# Example: ./scripts/upgrade.sh v1.0.5
# ═══════════════════════════════════════════════════════════════

VERSION="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

if [ -z "$VERSION" ]; then
    error "Usage: ./scripts/upgrade.sh <version>\nExample: ./scripts/upgrade.sh v1.0.5"
fi

cd "$PROJECT_DIR"

# ─── Backup before upgrade ────────────────────────────────────
log "Creating backup before upgrade..."
if [ -f "$SCRIPT_DIR/backup.sh" ]; then
    bash "$SCRIPT_DIR/backup.sh" || warn "Backup failed, continuing anyway"
fi

# ─── Update version in .env ───────────────────────────────────
update_version() {
    local key="$1"
    local value="$2"

    if grep -q "^${key}=" .env 2>/dev/null; then
        sed -i.bak "s|^${key}=.*|${key}=${value}|" .env
        log "Updated $key=$value"
    else
        echo "${key}=${value}" >> .env
        log "Added $key=$value"
    fi
}

update_version "GATEWAY_VERSION" "$VERSION"
update_version "PORTAL_VERSION" "$VERSION"
update_version "CLIPROXY_VERSION" "$VERSION"

# Remove backup file
rm -f .env.bak

# ─── Pull new images ──────────────────────────────────────────
log "Pulling images for $VERSION..."
docker compose pull

# ─── Rolling update ───────────────────────────────────────────
log "Performing rolling update..."

# Update cliproxy first
docker compose up -d --no-deps cliproxy
sleep 5
docker compose exec cliproxy wget -q --spider http://localhost:8317/ || warn "cliproxy health check failed"

# Update gateway
docker compose up -d --no-deps gateway
sleep 5
docker compose exec gateway wget -q --spider http://localhost:18080/health || warn "gateway health check failed"

# Update portal
docker compose up -d --no-deps portal
sleep 5
docker compose exec portal wget -q --spider http://0.0.0.0:3000 || warn "portal health check failed"

# ─── Verify ───────────────────────────────────────────────────
log "Verifying services..."
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Image}}"

echo ""
log "Upgrade to $VERSION complete!"
warn "Check logs: docker compose logs -f"
