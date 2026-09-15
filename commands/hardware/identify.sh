#!/usr/bin/env bash

# astra hardware identify <port> - Identifica modelo de ESP en puerto específico

set -e

if [ -z "$ASTRA_HOME" ]; then
    ASTRA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/core/checks.sh"

if [ -z "$1" ]; then
    die "Uso: astra hardware identify <port>"
fi

PORT="$1"

info "Identificando dispositivo ESP en $PORT..."

# Get USB serial adapter info
USB_SERIAL="unknown"
if [ -e "$PORT" ]; then
    dev_path="/sys/class/tty/$(basename $PORT)/device"
    if [ -f "$dev_path/../../idVendor" ] && [ -f "$dev_path/../../idProduct" ]; then
        vendor_id=$(cat "$dev_path/../../idVendor" 2>/dev/null)
        product_id=$(cat "$dev_path/../../idProduct" 2>/dev/null)
        case "$vendor_id:$product_id" in
            "10c4:ea60") USB_SERIAL="CP210x" ;;
            "1a86:7523") USB_SERIAL="CH340" ;;
            "0403:6001") USB_SERIAL="FTDI" ;;
            *) USB_SERIAL="unknown ($vendor_id:$product_id)" ;;
        esac
    fi
fi

# Identify MCU and board
info "Identificando MCU y board..."
BOARD=$(identify_esp_board "$PORT")
MCU="unknown"
if [ "$BOARD" = "esp01" ] || [ "$BOARD" = "esp12" ] || [ "$BOARD" = "esp8266" ] || [ "$BOARD" = "d1_mini" ] || [ "$BOARD" = "nodemcu" ]; then
    MCU="ESP8266"
elif [ "$BOARD" = "esp32" ] || [ "$BOARD" = "esp32dev" ] || [ "$BOARD" = "esp32-c3-devkitm-1" ] || [ "$BOARD" = "esp32-s2-saola-1" ] || [ "$BOARD" = "esp32-s3-devkitc-1" ]; then
    MCU="ESP32"
fi

if [ $? -eq 0 ] && [ "$BOARD" != "unknown" ]; then
    info "Puerto USB: $PORT"
    info "USB-Serial: $USB_SERIAL"
    info "MCU: $MCU"
    info "Board: $BOARD"
    ok "Dispositivo identificado: $BOARD ($MCU)"
else
    warn "No se pudo identificar el dispositivo completamente"
    info "USB-Serial: $USB_SERIAL"
    info "MCU: $MCU"
    info "Board: $BOARD"
    exit 1
fi
