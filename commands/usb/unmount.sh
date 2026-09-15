#!/usr/bin/env bash

# astra usb unmount - Desmonta almacenamiento USB

set -e

if [ -z "$ASTRA_HOME" ]; then
    ASTRA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/workspace.sh"
source "$ASTRA_HOME/lib/core/checks.sh"

info "Desmontando almacenamiento USB..."
unmount_usb_storage "/mnt/astra_usb"
ok "Desmontado"
