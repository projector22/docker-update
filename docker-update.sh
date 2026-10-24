#!/usr/bin/env bash
set -Eeuo pipefail

# docker-update
# Update the Docker Compose project in the current directory.
#
# Usage:
#   docker-update
#   docker-update --logs

log() {
    printf '[docker-update] %s\n' "$*"
}

die() {
    printf '[docker-update] ERROR: %s\n' "$*" >&2
    exit 1
}

FOLLOW_LOGS=false

while (($#)); do
    case "$1" in
        --logs|-l)
            FOLLOW_LOGS=true
            ;;
        --help|-h)
            printf 'Usage: docker-update [--logs|-l]\n'
            exit 0
            ;;
        *)
            die "Unknown argument: $1"
            ;;
    esac
    shift
done

PROJECT_DIR="$(pwd -P)"

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

# Prefer a project-specific update script when present.
if [[ -f "$PROJECT_DIR/update.sh" ]]; then
    [[ -x "$PROJECT_DIR/update.sh" ]] \
        || die "update.sh exists but is not executable."

    log "Running project-specific update.sh"
    "$PROJECT_DIR/update.sh" \
        || die "Project-specific update.sh failed."
else
    [[ -n "$COMPOSE_FILE" ]] \
        || die "No Compose YAML file found in $PROJECT_DIR"

    command -v docker >/dev/null 2>&1 \
        || die "Docker CLI not found."

    docker compose version >/dev/null 2>&1 \
        || die "Docker Compose v2 plugin is not available."

    log "Project directory: $PROJECT_DIR"
    log "Compose file: $(basename "$COMPOSE_FILE")"

    log "Validating Compose configuration"
    docker compose -f "$COMPOSE_FILE" config -q

    log "Pulling images"
    docker compose -f "$COMPOSE_FILE" pull

    log "Applying updates"
    docker compose -f "$COMPOSE_FILE" up -d --remove-orphans

    log "Update complete"
    docker compose -f "$COMPOSE_FILE" ps
fi

# Follow logs only after the update has completed successfully.
if [[ "$FOLLOW_LOGS" == true ]]; then
    log "Following container logs (Ctrl+C to exit)"

    if [[ -n "$COMPOSE_FILE" ]]; then
        exec docker compose -f "$COMPOSE_FILE" logs -f
    else
        # For a custom update script, resolve the Compose file now.
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
            || die "Cannot follow logs: no Compose YAML file found."

        exec docker compose -f "$COMPOSE_FILE" logs -f
    fi
fi
