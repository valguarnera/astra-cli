#!/usr/bin/env bash

# astra usb test [device] - Prueba almacenamiento USB (mount, write, read, verify, cleanup)

set -e

if [ -z "$ASTRA_HOME" ]; then
    ASTRA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/workspace.sh"
source "$ASTRA_HOME/lib/core/checks.sh"

DEVICE="${1:-}"

# Si no se especifica dispositivo, intentar auto-detectar
if [ -z "$DEVICE" ]; then
    info "Auto-detectando dispositivo USB..."
    DEVICES=$(detect_usb_storage 2>/dev/null | head -1 | awk '{print $1}')
    if [ -z "$DEVICES" ]; then
        die "No se detectó ningún dispositivo de almacenamiento USB"
    fi
    DEVICE="$DEVICES"
    info "Usando dispositivo auto-detectado: $DEVICE"
fi

if [ ! -b "$DEVICE" ]; then
    die "Dispositivo $DEVICE no existe o no es un dispositivo de bloque"
fi

info "Probando almacenamiento USB en $DEVICE..."

# Crear punto de montaje
MOUNT_POINT="/mnt/astra_usb_test_$$"

# Montar
info "Montando $DEVICE..."
if ! mount_usb_storage "$DEVICE" "/mnt/astra_usb"; then
    die "Error montando dispositivo"
fi

# Probar almacenamiento
if test_usb_storage "/mnt/astra_usb"; then
    ok "Prueba de almacenamiento USB completada con éxito"
else
    unmount_usb_storage "/mnt/astra_usb"
    die "Prueba de almacenamiento USB falló"
fi

# Desmontar
info "Desmontando..."
unmount_usb_storage "/mnt/astra_usb"

ok "Prueba de almacenamiento USB completada"
