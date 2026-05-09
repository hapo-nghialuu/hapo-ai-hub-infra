#!/bin/bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════
# hapo-ai-hub Backup Script
# Usage: ./scripts/backup.sh [output-dir]
# Example: ./scripts/backup.sh /backups
# ═══════════════════════════════════════════════════════════════

OUTPUT_DIR="${1:-./backups}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

cd "$PROJECT_DIR"
mkdir -p "$OUTPUT_DIR"

# ─── Backup MySQL ─────────────────────────────────────────────
backup_mysql() {
    local backup_file="$OUTPUT_DIR/mysql_${TIMESTAMP}.sql.gz"

    log "Backing up MySQL..."

    local db_user
    db_user=$(grep MYSQL_USER .env 2>/dev/null | cut -d= -f2 | tr -d ' "' || echo "api_gateway")
    local db_password
    db_password=$(grep MYSQL_PASSWORD .env 2>/dev/null | cut -d= -f2 | tr -d ' "' || echo "")

    docker compose exec -T mysql mysqldump \
        -u "$db_user" \
        -p"$db_password" \
        --single-transaction \
        --routines \
        --triggers \
        api_gateway | gzip > "$backup_file"

    log "MySQL backup: $backup_file ($(du -h "$backup_file" | cut -f1))"
}

# ─── Backup Redis ─────────────────────────────────────────────
backup_redis() {
    local backup_file="$OUTPUT_DIR/redis_${TIMESTAMP}.rdb"

    log "Backing up Redis..."

    docker compose exec -T redis redis-cli BGSAVE >/dev/null 2>&1
    sleep 2
    docker cp "$(docker compose ps -q redis):/data/dump.rdb" "$backup_file"

    log "Redis backup: $backup_file ($(du -h "$backup_file" | cut -f1))"
}

# ─── Backup Cliproxy auth ─────────────────────────────────────
backup_cliproxy() {
    local backup_file="$OUTPUT_DIR/cliproxy_auth_${TIMESTAMP}.tar.gz"

    log "Backing up Cliproxy auth..."

    tar -czf "$backup_file" -C "$PROJECT_DIR" docker/cliproxy/auths 2>/dev/null || warn "No cliproxy auth data"

    if [ -f "$backup_file" ]; then
        log "Cliproxy backup: $backup_file ($(du -h "$backup_file" | cut -f1))"
    fi
}

# ─── Cleanup old backups ──────────────────────────────────────
cleanup_old_backups() {
    local keep_days=7

    log "Cleaning backups older than $keep_days days..."
    find "$OUTPUT_DIR" -name "*.sql.gz" -mtime +"$keep_days" -delete 2>/dev/null || true
    find "$OUTPUT_DIR" -name "*.rdb" -mtime +"$keep_days" -delete 2>/dev/null || true
    find "$OUTPUT_DIR" -name "*.tar.gz" -mtime +"$keep_days" -delete 2>/dev/null || true
}

# ─── Main ─────────────────────────────────────────────────────
main() {
    echo "═══════════════════════════════════════════════════════"
    echo " hapo-ai-hub Backup"
    echo " Timestamp: $TIMESTAMP"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    backup_mysql
    backup_redis
    backup_cliproxy
    cleanup_old_backups

    echo ""
    log "Backup complete! Files in: $OUTPUT_DIR"
}

main
