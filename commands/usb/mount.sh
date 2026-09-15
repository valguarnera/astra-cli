#!/usr/bin/env bash

# astra usb mount <device> - Monta dispositivo USB

set -e

if [ -z "$ASTRA_HOME" ]; then
    ASTRA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/workspace.sh"
source "$ASTRA_HOME/lib/core/checks.sh"

DEVICE="${1:-}"
if [ -z "$DEVICE" ]; then
    die "Uso: astra usb mount <device>"
fi

if [ ! -b "$DEVICE" ]; then
    die "Dispositivo $DEVICE no existe o no es un dispositivo de bloque"
fi

if mount_usb_storage "$DEVICE" "/mnt/astra_usb"; then
    ok "Dispositivo montado en /mnt/astra_usb"
else
    die "Error montando dispositivo"
fi
