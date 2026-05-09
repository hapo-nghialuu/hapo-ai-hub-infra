#!/bin/bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════
# Server Setup Script for hapo-ai-hub
# Run this on a fresh Ubuntu server before deploying
# Usage: curl -fsSL <raw-url> | bash
# ═══════════════════════════════════════════════════════════════

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info() { echo -e "${CYAN}[i]${NC} $1"; }

echo ""
echo "═══════════════════════════════════════════════════════"
echo " hapo-ai-hub Server Setup"
echo "═══════════════════════════════════════════════════════"
echo ""

# ─── Check OS ──────────────────────────────────────────────────
if [ -f /etc/os-release ]; then
    . /etc/os-release
    info "OS: $PRETTY_NAME"
else
    error "Cannot detect OS. This script supports Ubuntu 22.04+"
fi

# ─── Update system ─────────────────────────────────────────────
log "Updating system packages..."
sudo apt update -qq
sudo apt upgrade -y -qq

# ─── Install essentials ────────────────────────────────────────
log "Installing essentials..."
sudo apt install -y -qq \
    curl \
    wget \
    git \
    unzip \
    jq \
    openssl \
    ca-certificates \
    gnupg \
    lsb-release

# ─── Install Docker ────────────────────────────────────────────
if command -v docker &>/dev/null; then
    log "Docker already installed: $(docker --version)"
else
    log "Installing Docker..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker "$USER"
    log "Docker installed. You need to logout and login again for group changes."
fi

# ─── Install Docker Compose ────────────────────────────────────
if docker compose version &>/dev/null; then
    log "Docker Compose already available: $(docker compose version --short)"
else
    log "Docker Compose plugin should come with Docker installation"
    error "Docker Compose not found. Try: sudo apt install docker-compose-plugin"
fi

# ─── Configure Firewall ────────────────────────────────────────
if command -v ufw &>/dev/null; then
    log "Configuring firewall..."
    sudo ufw --force disable
    sudo ufw allow 22/tcp comment "SSH"
    sudo ufw allow 80/tcp comment "HTTP"
    sudo ufw allow 443/tcp comment "HTTPS"
    sudo ufw --force enable
    log "Firewall configured: ports 22, 80, 443 open"
else
    warn "UFW not found. Skipping firewall config."
fi

# ─── Setup deploy directory ────────────────────────────────────
DEPLOY_DIR="$HOME/hapo-deploy"
log "Creating deploy directory: $DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"

# ─── Clone infra repo ─────────────────────────────────────────
if [ -d "$DEPLOY_DIR/.git" ]; then
    log "Infra repo already exists, pulling latest..."
    cd "$DEPLOY_DIR"
    git pull
else
    log "Cloning infra repo..."
    git clone https://github.com/hapo-nghialuu/hapo-ai-hub-infra.git "$DEPLOY_DIR"
    cd "$DEPLOY_DIR"
fi

# ─── Setup .env ────────────────────────────────────────────────
if [ ! -f "$DEPLOY_DIR/.env" ]; then
    log "Creating .env from template..."
    cp "$DEPLOY_DIR/.env.example" "$DEPLOY_DIR/.env"
    warn "IMPORTANT: Edit $DEPLOY_DIR/.env with your actual values before deploying!"
else
    log ".env already exists"
fi

# ─── Make scripts executable ───────────────────────────────────
chmod +x "$DEPLOY_DIR"/scripts/*.sh
log "Scripts made executable"

# ─── Generate secrets ──────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
echo " Generated Secrets (copy these to .env)"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "MYSQL_ROOT_PASSWORD=$(openssl rand -base64 24)"
echo "MYSQL_PASSWORD=$(openssl rand -base64 24)"
echo "GO_GATEWAY_AUTH_JWT_SECRET=$(openssl rand -base64 32)"
echo "GO_GATEWAY_CUTOVER_ADMIN_TOKEN=$(openssl rand -base64 24)"
echo "CLIPROXY_API_KEY=$(openssl rand -base64 24)"
echo "CLIPROXY_MANAGEMENT_SECRET=$(openssl rand -base64 24)"
echo "ADMIN_PASSWORD=$(openssl rand -base64 16)"
echo ""
echo "═══════════════════════════════════════════════════════"

# ─── Summary ───────────────────────────────────────────────────
echo ""
log "Server setup complete!"
echo ""
info "Next steps:"
echo "  1. Edit .env:    vi $DEPLOY_DIR/.env"
echo "  2. Login GHCR:   echo 'YOUR_TOKEN' | docker login ghcr.io -u hapo-nghialuu --password-stdin"
echo "  3. Deploy:       cd $DEPLOY_DIR && ./scripts/deploy.sh"
echo ""
info "For customer-specific deployment:"
echo "  cd $DEPLOY_DIR && ./scripts/deploy.sh customer-a"
echo ""
