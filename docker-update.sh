#!/usr/bin/env bash
set -Eeuo pipefail

# docker-update
# Update the Docker Compose project in the current directory.

log() {
    printf '[docker-update] %s\n' "$*"
}

die() {
    printf '[docker-update] ERROR: %s\n' "$*" >&2
    exit 1
}

# Resolve the directory from which the command was invoked.
PROJECT_DIR="$(pwd -P)"

# A project-specific update script takes precedence.
if [[ -f "$PROJECT_DIR/update.sh" ]]; then
    [[ -x "$PROJECT_DIR/update.sh" ]] \
        || die "update.sh exists but is not executable: $PROJECT_DIR/update.sh"

    log "Running project-specific update.sh"
    exec "$PROJECT_DIR/update.sh"
fi

# Find a Compose file.
COMPOSE_FILE=""

for file in \
    compose.yaml \
    compose.yml \
    docker-compose.yaml \
    docker-compose.yml
do
    if [[ -f "$PROJECT_DIR/$file" ]]; then
        COMPOSE_FILE="$PROJECT_DIR/$file"
        break
    fi
done

[[ -n "$COMPOSE_FILE" ]] \
    || die "No Compose YAML file found in $PROJECT_DIR"

command -v docker >/dev/null 2>&1 \
    || die "Docker CLI not found."

docker compose version >/dev/null 2>&1 \
    || die "Docker Compose v2 plugin is not available."

log "Project directory: $PROJECT_DIR"
log "Compose file: $(basename "$COMPOSE_FILE")"

# Validate configuration before changing anything.
log "Validating Compose configuration"
docker compose -f "$COMPOSE_FILE" config -q

# Pull images, then recreate services as required.
log "Pulling images"
docker compose -f "$COMPOSE_FILE" pull

log "Applying updates"
docker compose -f "$COMPOSE_FILE" up -d --remove-orphans

log "Update complete"
docker compose -f "$COMPOSE_FILE" ps
