#!/usr/bin/env bash

# astra flash usb <node> [--port <port>]
# Flashea un nodo ESP32 via USB usando ESPHome

set -e

if [ -z "$ASTRA_HOME" ]; then
    ASTRA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/core/command_base.sh"

COMMAND="flash usb"

usage() {
    cat <<EOF
astra flash usb - Flashea un nodo ESP32 por USB

Uso:
    astra flash usb <node> [--port <port>]

Argumentos:
    <node>              ID del nodo a flashear (ej: sensor01)

Opciones:
    --port <port>       Puerto serial específico (ej: /dev/ttyUSB1)
                        Si no se especifica, se auto-detecta.

Ejemplos:
    astra flash usb sensor01
    astra flash usb sensor01 --port /dev/ttyUSB1
EOF
}

# Parsear argumentos
NODE_ID=""
EXPLICIT_PORT=""

while [ $# -gt 0 ]; do
    case "$1" in
        --port)
            EXPLICIT_PORT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            die "Opción desconocida: $1"
            ;;
        *)
            if [ -z "$NODE_ID" ]; then
                NODE_ID="$1"
            else
                die "Argumento inesperado: $1"
            fi
            shift
            ;;
    esac
done

# Preflight: workspace, deps, node validation
command_preflight_node "$NODE_ID"

info "Workspace: $(basename "$WORKSPACE")"
info "Nodo: $NODE_ID"
info "Driver: $(yq '.driver' "$NODE_YAML")"
info "Board: $(yq '.board' "$NODE_YAML")"

# Regenerar firmware.yaml desde node.yaml (por si cambió la config)
regenerate_firmware "$NODE_ID"

# Validar configuración con esphome config
validate_firmware "$NODE_ID" "$NODE_DIR"

# Detectar puerto USB
PORT=$(select_serial_port "$EXPLICIT_PORT")
if [ -z "$EXPLICIT_PORT" ]; then
    info "Puerto USB detectado automáticamente: $PORT"
else
    info "Usando puerto explícito: $PORT"
fi

# Flashear con ESPHome
info "Compilando y flasheando firmware en $PORT..."
docker run --rm --privileged \
    --device="$PORT" \
    -v "$NODE_DIR":/config \
    esphome/esphome \
    run firmware.yaml

ok "Firmware flasheado correctamente en $NODE_ID"