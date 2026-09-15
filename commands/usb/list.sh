#!/usr/bin/env bash

# astra usb list - Lista dispositivos de almacenamiento USB

set -e

if [ -z "$ASTRA_HOME" ]; then
    ASTRA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/workspace.sh"
source "$ASTRA_HOME/lib/core/checks.sh"

info "Listando dispositivos de almacenamiento USB..."
if detect_usb_storage; then
    ok "Dispositivos USB listados"
else
    info "No hay dispositivos de almacenamiento USB conectados"
fi
