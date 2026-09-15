#!/usr/bin/env bash

# astra hardware detect - Detecta dispositivos ESP8266/ESP32 conectados

set -e

if [ -z "$ASTRA_HOME" ]; then
    ASTRA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/core/checks.sh"

info "Detectando dispositivos ESP8266/ESP32..."
if detect_esp_serial; then
    ok "Dispositivos ESP detectados"
else
    warn "No se detectaron dispositivos ESP8266/ESP32"
    info "Conecte el dispositivo y verifique: ls /dev/ttyUSB* /dev/ttyACM*"
    exit 1
fi
