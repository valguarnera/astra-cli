#!/usr/bin/env bash

# astra hardware identify <port> - Identifica modelo de ESP en puerto específico

set -e

if [ -z "$ASTRA_HOME" ]; then
    ASTRA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/core/hardware.sh"

if [ -z "$1" ]; then
    die "Uso: astra hardware identify <port>"
fi

PORT="$1"

info "Identificando dispositivo en $PORT..."

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

# Try to identify MCU and board via esptool.py (requires bootloader mode)
info "Identificando MCU y board (requiere bootloader)..."
MCU="unknown"
BOARD="unknown"

if command -v esptool.py >/dev/null 2>&1; then
    chip_info=$(esptool.py --port "$PORT" chip_id 2>&1)
    if echo "$chip_info" | grep -q "ESP32"; then
        MCU="ESP32"
        flash_info=$(esptool.py --port "$PORT" flash_id 2>&1)
        if echo "$flash_info" | grep -q "ESP32-C3"; then
            BOARD="esp32-c3-devkitm-1"
        elif echo "$flash_info" | grep -q "ESP32-S2"; then
            BOARD="esp32-s2-saola-1"
        elif echo "$flash_info" | grep -q "ESP32-S3"; then
            BOARD="esp32-s3-devkitc-1"
        else
            BOARD="esp32dev"
        fi
    elif echo "$chip_info" | grep -q "ESP8266"; then
        MCU="ESP8266"
        flash_info=$(esptool.py --port "$PORT" flash_id 2>&1)
        if echo "$flash_info" | grep -q "ESP8285\|ESP01"; then
            BOARD="esp01"
        elif echo "$flash_info" | grep -q "4MB"; then
            BOARD="esp12"
        else
            BOARD="esp8266"
        fi
    fi
fi

# Display results
info "Puerto USB: $PORT"
info "USB-Serial: $USB_SERIAL"

if [ "$MCU" != "unknown" ]; then
    info "MCU: $MCU"
    info "Board: $BOARD"
    ok "Dispositivo identificado: $BOARD ($MCU)"
else
    warn "No se pudo identificar MCU/board (requiere bootloader: GPIO0=LOW + RESET)"
    info "MCU: unknown"
    info "Board: unknown"
    info "USB-Serial detectado: $USB_SERIAL (solo adaptador, no board ESP)"
    exit 1
fi