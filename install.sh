#!/usr/bin/env bash

set -e
DEV_MODE=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/core/ui.sh"
source "$SCRIPT_DIR/lib/core/utils.sh"
source "$SCRIPT_DIR/lib/core/checks.sh"

if [ "$1" = "--dev" ]; then
    DEV_MODE=true
    info "Modo desarrollo 💻"
fi

info "Installing ASTRA CLI..."

check_os
check_docker
check_compose
check_daemon
check_docker_permissions
check_yq

if $DEV_MODE; then
    install_cli_dev
else
    install_cli
fi

create_launcher
pull_images

success "ASTRA CLI installed successfully."