#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/core/ui.sh"
source "$SCRIPT_DIR/lib/core/utils.sh"

info "Uninstalling ASTRA CLI..."

remove_launcher
remove_installation

success "ASTRA CLI removed successfully."