# hapo-ai-hub-infra

Infrastructure & deployment repository for hapo-ai-hub.

## Overview

This repo contains Docker Compose configs, Nginx setup, and deployment scripts. No source code here - Docker images are pulled from GitHub Container Registry (GHCR).

**Each partner/customer clones this repo once and configures their own .env.**

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/hapo-nghialuu/hapo-ai-hub-infra.git
cd hapo-ai-hub-infra

# 2. Setup config (interactive wizard)
./scripts/setup-env.sh

# Or manually:
cp .env.example .env
vi .env  # Fill in your values

# 3. Login GHCR
export GHCR_TOKEN=your_github_token
echo "$GHCR_TOKEN" | docker login ghcr.io -u hapo-nghialuu --password-stdin

# 4. Deploy
chmod +x scripts/*.sh
./scripts/deploy.sh
```

## New Server Setup

On a fresh Ubuntu server:

```bash
curl -fsSL https://raw.githubusercontent.com/hapo-nghialuu/hapo-ai-hub-infra/main/scripts/setup-server.sh | bash
```

This will:
- Install Docker & Docker Compose
- Configure firewall (ports 22, 80, 443)
- Clone this repo
- Generate random secrets for .env

## Upgrade Version

```bash
./scripts/upgrade.sh v1.0.5
```

## Backup

```bash
./scripts/backup.sh
```

## Directory Structure

```
hapo-ai-hub-infra/
├── docker-compose.yml          # Main orchestration
├── .env.example                # Config template (copy to .env)
├── docker/
│   ├── nginx/
│   │   └── default.conf.template
│   ├── cliproxy/
│   │   └── config.yaml
│   └── mysql/
│       └── init.sql
├── scripts/
│   ├── setup-server.sh         # Prepare fresh server
│   ├── setup-env.sh            # Interactive .env wizard
│   ├── deploy.sh               # Deploy services
│   ├── upgrade.sh              # Upgrade versions
│   └── backup.sh               # Backup databases
└── README.md
```

## Services

| Service | Port | Description |
|---------|------|-------------|
| mysql | 3306 | MySQL 8 database |
| redis | 6379 | Redis cache |
| cliproxy | 8317 | CLIProxyAPI proxy |
| gateway | 18080 | Go API gateway |
| portal | 3000 | Next.js admin dashboard |
| nginx | 80, 443 | Reverse proxy + SSL |
| certbot | - | Auto-renew SSL |

## Environment Variables

See `.env.example` for all available options.

## SSL Setup

1. Configure `DOMAIN` and `CERTBOT_EMAIL` in `.env`
2. Run `./scripts/deploy.sh` (auto-configures SSL)
3. SSL auto-renews via certbot

## Troubleshooting

```bash
# Check service status
docker compose ps

# View logs
docker compose logs -f

# Restart specific service
docker compose restart gateway

# Check health
curl http://localhost:18080/health
```
