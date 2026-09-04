#!/usr/bin/env bash
source "$SCRIPT_DIR/lib/core/ui.sh"

#check_os ✓
#check_docker ✓
#check_docker_compose ✓
#check_docker_daemon ✓
#check_docker_permissions ✓
#check_usb
#check_project
#check_node

check_os() {
    if [[ "$OSTYPE" == linux* ]]; then
        ok "Linux"
    else
        die "Linux is required."
    fi
}

check_docker() {
    if command -v docker >/dev/null 2>&1; then
        ok "Docker"
    else
        die "Docker is not installed."
    fi
}

check_compose() {
    if command -v docker-compose >/dev/null 2>&1 || docker compose version >/dev/null 2>&1; then
        ok "Docker Compose"
    else
        die "Docker Compose is not installed."
    fi
}

check_daemon() {
    if docker info >/dev/null 2>&1; then
        ok "Docker Daemon"
    else
        die "Docker daemon is not running."
    fi
}

check_docker_permissions() {
    if docker ps >/dev/null 2>&1; then
        ok "Docker Permissions"
    else
        die "Current user cannot access Docker.

Try:

sudo usermod -aG docker $USER

Then log out and log back in."
    fi
}

check_yq() {
    if command -v yq >/dev/null 2>&1; then
        ok "yq"
    else
        die "yq is not installed.

Try:
sudo apt-get install yq
or
sudo snap install yq"
    fi
}
