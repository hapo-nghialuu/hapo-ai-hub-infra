#!/bin/bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════
# Setup .env for hapo-ai-hub deployment
# Usage: ./scripts/setup-env.sh
#        ./scripts/setup-env.sh --non-interactive   (use defaults/env vars)
# ═══════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/.env"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NON_INTERACTIVE=false

for arg in "$@"; do
    case $arg in
        --non-interactive) NON_INTERACTIVE=true ;;
        -h|--help)
            echo "Usage: $0 [--non-interactive]"
            echo ""
            echo "Creates .env from .env.example with guided prompts."
            echo "  --non-interactive   Use environment variables or defaults (no prompts)"
            exit 0
            ;;
    esac
done

# ─── Helper functions ──────────────────────────────────────────
prompt() {
    local var_name=$1
    local prompt_text=$2
    local default=${3:-}
    local value

    if [ "$NON_INTERACTIVE" = true ]; then
        # Use env var if set, otherwise default
        eval "value=\${$var_name:-\$default}"
        echo "$value"
        return
    fi

    if [ -n "$default" ]; then
        printf "${BLUE}%s${NC} [${GREEN}%s${NC}]: " "$prompt_text" "$default"
    else
        printf "${BLUE}%s${NC}: " "$prompt_text"
    fi

    read -r value
    echo "${value:-$default}"
}

prompt_secret() {
    local var_name=$1
    local prompt_text=$2
    local default=${3:-}
    local value

    if [ "$NON_INTERACTIVE" = true ]; then
        eval "value=\${$var_name:-\$default}"
        echo "$value"
        return
    fi

    if [ -n "$default" ]; then
        printf "${BLUE}%s${NC} [${GREEN}****${NC}]: " "$prompt_text"
    else
        printf "${BLUE}%s${NC}: " "$prompt_text"
    fi

    read -rs value
    echo ""
    echo "${value:-$default}"
}

generate_secret() {
    openssl rand -base64 "$1" 2>/dev/null || head -c "$1" /dev/urandom | base64 | tr -d '\n' | head -c "$1"
}

# ─── Check existing .env ───────────────────────────────────────
if [ -f "$ENV_FILE" ] && [ "$NON_INTERACTIVE" = false ]; then
    echo -e "${YELLOW}⚠ .env already exists at $ENV_FILE${NC}"
    printf "Overwrite? (y/N): "
    read -r confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Aborted."
        exit 0
    fi
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo " hapo-ai-hub Environment Setup"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "This wizard will create your .env configuration."
echo "Press Enter to accept defaults shown in [brackets]."
echo ""

# ─── Domain & SSL ──────────────────────────────────────────────
echo -e "${YELLOW}── Domain & SSL ──────────────────────────────────────${NC}"
DOMAIN=$(prompt "DOMAIN" "Domain (e.g., partner.example.com)" "partner.example.com")
CERTBOT_EMAIL=$(prompt "CERTBOT_EMAIL" "SSL email (for Let's Encrypt)" "admin@$DOMAIN")
echo ""

# ─── MySQL ─────────────────────────────────────────────────────
echo -e "${YELLOW}── MySQL ─────────────────────────────────────────────${NC}"
MYSQL_ROOT_PASSWORD=$(prompt_secret "MYSQL_ROOT_PASSWORD" "MySQL root password" "$(generate_secret 24)")
MYSQL_USER=$(prompt "MYSQL_USER" "MySQL user" "api_gateway")
MYSQL_PASSWORD=$(prompt_secret "MYSQL_PASSWORD" "MySQL password" "$(generate_secret 24)")
echo ""

# ─── Go Gateway ────────────────────────────────────────────────
echo -e "${YELLOW}── Go Gateway ────────────────────────────────────────${NC}"
GO_GATEWAY_ENV=$(prompt "GO_GATEWAY_ENV" "Environment (production/staging)" "production")
GO_GATEWAY_PORT=$(prompt "GO_GATEWAY_PORT" "Gateway port" "18080")
GO_GATEWAY_AUTH_JWT_SECRET=$(prompt_secret "GO_GATEWAY_AUTH_JWT_SECRET" "JWT secret (min 32 chars)" "$(generate_secret 32)")
GO_GATEWAY_CUTOVER_ADMIN_TOKEN=$(prompt_secret "GO_GATEWAY_CUTOVER_ADMIN_TOKEN" "Cutover admin token" "$(generate_secret 24)")
echo ""

# ─── CLIProxyAPI ───────────────────────────────────────────────
echo -e "${YELLOW}── CLIProxyAPI ───────────────────────────────────────${NC}"
CLIPROXY_API_KEY=$(prompt_secret "CLIPROXY_API_KEY" "Cliproxy API key" "$(generate_secret 24)")
CLIPROXY_MANAGEMENT_SECRET=$(prompt_secret "CLIPROXY_MANAGEMENT_SECRET" "Cliproxy management secret" "$(generate_secret 24)")
echo ""

# ─── Google OAuth ─────────────────────────────────────────────
echo -e "${YELLOW}── Google OAuth (optional, press Enter to skip) ──────${NC}"
GOOGLE_CLIENT_ID=$(prompt "GOOGLE_CLIENT_ID" "Google Client ID" "")
echo ""

# ─── Provider API Keys ────────────────────────────────────────
echo -e "${YELLOW}── Provider API Keys (optional, press Enter to skip) ──${NC}"
OPENROUTER_API_KEY=$(prompt "OPENROUTER_API_KEY" "OpenRouter API key" "")
WEB_SEARCH_PROVIDER=$(prompt "WEB_SEARCH_PROVIDER" "Web search provider (you/brave)" "you")
YOU_API_KEY=$(prompt "YOU_API_KEY" "You.com API key" "")
BRAVE_API_KEY=$(prompt "BRAVE_API_KEY" "Brave API key" "")
echo ""

# ─── Admin Account ────────────────────────────────────────────
echo -e "${YELLOW}── Admin Account ────────────────────────────────────${NC}"
ADMIN_EMAIL=$(prompt "ADMIN_EMAIL" "Admin email" "$DOMAIN")
ADMIN_PASSWORD=$(prompt_secret "ADMIN_PASSWORD" "Admin password" "$(generate_secret 16)")
echo ""

# ─── GHCR ─────────────────────────────────────────────────────
echo -e "${YELLOW}── GitHub Container Registry ─────────────────────────${NC}"
GHCR_OWNER=$(prompt "GHCR_OWNER" "GHCR owner (GitHub username/org)" "hapo-nghialuu")
GATEWAY_VERSION=$(prompt "GATEWAY_VERSION" "Gateway image version" "latest")
PORTAL_VERSION=$(prompt "PORTAL_VERSION" "Portal image version" "latest")
CLIPROXY_VERSION=$(prompt "CLIPROXY_VERSION" "Cliproxy image version" "latest")
GHCR_TOKEN=$(prompt_secret "GHCR_TOKEN" "GitHub PAT (read:packages scope)" "")
echo ""

# ─── Write .env ───────────────────────────────────────────────
cat > "$ENV_FILE" << EOF
# ═══════════════════════════════════════════════════════════════
# hapo-ai-hub Docker Deployment Configuration
# Generated by setup-env.sh on $(date '+%Y-%m-%d %H:%M:%S')
# ═══════════════════════════════════════════════════════════════

# ─── Domain & SSL ──────────────────────────────────────────────
DOMAIN=$DOMAIN
CERTBOT_EMAIL=$CERTBOT_EMAIL

# ─── MySQL ─────────────────────────────────────────────────────
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_USER=$MYSQL_USER
MYSQL_PASSWORD=$MYSQL_PASSWORD

# ─── Go Gateway ────────────────────────────────────────────────
GO_GATEWAY_ENV=$GO_GATEWAY_ENV
GO_GATEWAY_PORT=$GO_GATEWAY_PORT
GO_GATEWAY_AUTH_JWT_SECRET=$GO_GATEWAY_AUTH_JWT_SECRET
GO_GATEWAY_CUTOVER_ADMIN_TOKEN=$GO_GATEWAY_CUTOVER_ADMIN_TOKEN
GO_GATEWAY_AUTH_ACCESS_EXPIRE_SECONDS=1800
GO_GATEWAY_READ_TIMEOUT_SECONDS=15
GO_GATEWAY_READ_HEADER_TIMEOUT_SECONDS=10
GO_GATEWAY_WRITE_TIMEOUT_SECONDS=7200
GO_GATEWAY_IDLE_TIMEOUT_SECONDS=60

# ─── CLIProxyAPI ───────────────────────────────────────────────
CLIPROXY_API_KEY=$CLIPROXY_API_KEY
CLIPROXY_MANAGEMENT_SECRET=$CLIPROXY_MANAGEMENT_SECRET
GO_GATEWAY_CLIPROXY_EXECUTION_BASE_URL=http://cliproxy:8317
GO_GATEWAY_CLIPROXY_EXECUTION_API_KEY=\${CLIPROXY_API_KEY}
GO_GATEWAY_CLIPROXY_MANAGEMENT_BASE_URL=http://cliproxy:8317
GO_GATEWAY_CLIPROXY_MANAGEMENT_AUTH=\${CLIPROXY_MANAGEMENT_SECRET}

# ─── Google OAuth ─────────────────────────────────────────────
GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID

# ─── Provider API Keys ────────────────────────────────────────
OPENROUTER_API_KEY=$OPENROUTER_API_KEY
WEB_SEARCH_PROVIDER=$WEB_SEARCH_PROVIDER
WEB_SEARCH_MAX_RESULTS=5
YOU_API_KEY=$YOU_API_KEY
BRAVE_API_KEY=$BRAVE_API_KEY
WEB_FETCH_MAX_CONTENT_TOKENS=50000

# ─── Admin Account ────────────────────────────────────────────
ADMIN_EMAIL=$ADMIN_EMAIL
ADMIN_PASSWORD=$ADMIN_PASSWORD

# ─── Image Versions ───────────────────────────────────────────
GHCR_OWNER=$GHCR_OWNER
GATEWAY_VERSION=$GATEWAY_VERSION
PORTAL_VERSION=$PORTAL_VERSION
CLIPROXY_VERSION=$CLIPROXY_VERSION

# ─── GitHub Token (for GHCR login) ────────────────────────────
GHCR_TOKEN=$GHCR_TOKEN
EOF

echo -e "${GREEN}[✓]${NC} .env created at $ENV_FILE"
echo ""

# ─── Summary ───────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════"
echo " Configuration Summary"
echo "═══════════════════════════════════════════════════════════"
echo " Domain:         $DOMAIN"
echo " MySQL User:     $MYSQL_USER"
echo " Gateway Port:   $GO_GATEWAY_PORT"
echo " Gateway Env:    $GO_GATEWAY_ENV"
echo " GHCR Owner:     $GHCR_OWNER"
echo " Gateway:        $GATEWAY_VERSION"
echo " Portal:         $PORTAL_VERSION"
echo " Cliproxy:       $CLIPROXY_VERSION"
echo " Admin Email:    $ADMIN_EMAIL"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "  1. Review .env: vi $ENV_FILE"
echo "  2. Deploy: ./scripts/deploy.sh"
echo ""
