# hapo-ai-hub-infra

Infrastructure & deployment repository for hapo-ai-hub.

## Overview

This repo contains Docker Compose configs, Nginx setup, and deployment scripts. No source code here - Docker images are pulled from GitHub Container Registry (GHCR).

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/hapo-nghialuu/hapo-ai-hub-infra.git
cd hapo-ai-hub-infra

# 2. Setup config
cp .env.example .env
# Edit .env with your values

# 3. Deploy
chmod +x scripts/*.sh
./scripts/deploy.sh
```

## Deploy for Specific Customer

```bash
# Use customer-specific config
./scripts/deploy.sh customer-a
```

## Upgrade Version

```bash
# Upgrade all services to v1.0.5
./scripts/upgrade.sh v1.0.5
```

## Backup

```bash
# Backup databases
./scripts/backup.sh

# Backup to specific directory
./scripts/backup.sh /backups
```

## Directory Structure

```
hapo-ai-hub-infra/
├── docker-compose.yml          # Main orchestration
├── .env.example                # Config template
├── customers/                  # Per-customer configs
│   ├── staging/
│   │   ├── .env.example        # Template (git tracked)
│   │   └── .env                # Actual secrets (git ignored)
│   ├── customer-a/
│   │   ├── .env.example
│   │   └── .env
│   └── customer-b/
│       ├── .env.example
│       └── .env
├── docker/
│   ├── nginx/                  # Nginx reverse proxy
│   │   └── default.conf.template
│   ├── cliproxy/               # CLIProxyAPI config
│   │   └── config.yaml
│   └── mysql/                  # Database init
│       └── init.sql
├── scripts/
│   ├── deploy.sh               # Deploy to server
│   ├── upgrade.sh              # Upgrade versions
│   └── backup.sh               # Backup databases
└── README.md
```

## Customer Setup

Each customer has their own config in `customers/<name>/`:

```bash
# 1. Copy template
cp customers/customer-a/.env.example customers/customer-a/.env

# 2. Edit with actual secrets
vi customers/customer-a/.env

# 3. Deploy for that customer
./scripts/deploy.sh customer-a
```

**Note:** `.env` files are git-ignored (contain secrets). Only `.env.example` templates are tracked.

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
