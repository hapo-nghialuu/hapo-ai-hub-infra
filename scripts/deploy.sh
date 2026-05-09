#!/bin/bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════
# hapo-ai-hub Deploy Script
# Usage: ./scripts/deploy.sh [customer-name]
# Example: ./scripts/deploy.sh customer-a
# ═══════════════════════════════════════════════════════════════

CUSTOMER="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# ─── Check prerequisites ──────────────────────────────────────
check_prerequisites() {
    command -v docker >/dev/null 2>&1 || error "Docker not installed. Run: curl -fsSL https://get.docker.com | sh"
    docker compose version >/dev/null 2>&1 || error "Docker Compose not available"
    log "Docker & Compose ready"
}

# ─── Setup customer config ────────────────────────────────────
setup_customer() {
    local customer_dir="$PROJECT_DIR/customers/$CUSTOMER"

    if [ -z "$CUSTOMER" ]; then
        warn "No customer specified. Using root .env"
        if [ ! -f "$PROJECT_DIR/.env" ]; then
            cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
            warn "Created .env from template. Please edit it with actual values."
            exit 0
        fi
        return
    fi

    if [ ! -d "$customer_dir" ]; then
        error "Customer directory not found: $customer_dir"
    fi

    if [ ! -f "$customer_dir/.env" ]; then
        error "Customer .env not found: $customer_dir/.env"
    fi

    # Symlink customer .env
    ln -sf "$customer_dir/.env" "$PROJECT_DIR/.env"
    log "Using config from customers/$CUSTOMER/.env"

    # Copy nginx config if exists
    if [ -f "$customer_dir/docker/nginx/default.conf.template" ]; then
        cp "$customer_dir/docker/nginx/default.conf.template" "$PROJECT_DIR/docker/nginx/default.conf.template"
        log "Using customer nginx config"
    fi
}

# ─── Login GHCR ───────────────────────────────────────────────
login_ghcr() {
    if [ -z "${GHCR_TOKEN:-}" ]; then
        warn "GHCR_TOKEN not set. Skipping GHCR login."
        warn "Set it with: export GHCR_TOKEN=your_github_token"
        return
    fi

    local owner
    owner=$(grep GHCR_OWNER "$PROJECT_DIR/.env" 2>/dev/null | cut -d= -f2 | tr -d ' "' || echo "hapo-nghialuu")
    echo "$GHCR_TOKEN" | docker login ghcr.io -u "$owner" --password-stdin
    log "Logged in to GHCR"
}

# ─── Pull images ──────────────────────────────────────────────
pull_images() {
    cd "$PROJECT_DIR"
    docker compose pull
    log "Images pulled"
}

# ─── Setup SSL ────────────────────────────────────────────────
setup_ssl() {
    local domain
    domain=$(grep DOMAIN "$PROJECT_DIR/.env" 2>/dev/null | cut -d= -f2 | tr -d ' "' || echo "")
    local email
    email=$(grep CERTBOT_EMAIL "$PROJECT_DIR/.env" 2>/dev/null | cut -d= -f2 | tr -d ' "' || echo "")

    if [ -z "$domain" ] || [ "$domain" = "partner.example.com" ]; then
        warn "DOMAIN not configured. Skipping SSL setup."
        return
    fi

    # Check if cert already exists
    if docker compose run --rm certbot certificates 2>/dev/null | grep -q "$domain"; then
        log "SSL certificate already exists for $domain"
        return
    fi

    # Start nginx for ACME challenge
    docker compose up -d nginx
    sleep 3

    # Get certificate
    docker compose run --rm certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "$email" \
        --agree-tos \
        --no-eff-email \
        -d "$domain"

    log "SSL certificate obtained for $domain"
}

# ─── Start services ───────────────────────────────────────────
start_services() {
    cd "$PROJECT_DIR"
    docker compose up -d
    log "All services started"
}

# ─── Health check ─────────────────────────────────────────────
health_check() {
    sleep 10
    echo ""
    log "Checking service health..."

    cd "$PROJECT_DIR"
    docker compose ps --format "table {{.Name}}\t{{.Status}}"

    echo ""
    local all_healthy=true
    for svc in mysql redis cliproxy gateway portal nginx; do
        if docker compose ps "$svc" 2>/dev/null | grep -q "healthy\|running"; then
            log "$svc: OK"
        else
            warn "$svc: not healthy"
            all_healthy=false
        fi
    done

    if [ "$all_healthy" = true ]; then
        echo ""
        log "All services healthy!"
    else
        echo ""
        warn "Some services not healthy. Check logs: docker compose logs"
    fi
}

# ─── Main ─────────────────────────────────────────────────────
main() {
    echo "═══════════════════════════════════════════════════════"
    echo " hapo-ai-hub Deploy"
    [ -n "$CUSTOMER" ] && echo " Customer: $CUSTOMER"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    check_prerequisites
    setup_customer
    login_ghcr
    pull_images
    setup_ssl
    start_services
    health_check

    echo ""
    log "Deploy complete!"
}

main
