#!/usr/bin/env bash

# astra flash usb <node> [--port <port>]
# Flashea un nodo ESP32 via USB usando ESPHome

set -e

if [ -z "$ASTRA_HOME" ]; then
    ASTRA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/workspace.sh"
source "$ASTRA_HOME/lib/core/checks.sh"

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

# Requerir workspace y cargar configuración
workspace_require
load_workspace

# Si no se pasó node_id, intentar auto-seleccionar si hay solo uno
if [ -z "$NODE_ID" ]; then
    NODES=("$WORKSPACE/nodes/"*/)
    NODES=("${NODES[@]%/}")
    NODES=("${NODES[@]##*/}")
    
    if [ ${#NODES[@]} -eq 0 ]; then
        die "No hay nodos en el workspace. Use 'astra node create <id>' para crear uno."
    elif [ ${#NODES[@]} -eq 1 ]; then
        NODE_ID="${NODES[0]}"
        info "Auto-seleccionando único nodo: $NODE_ID"
    else
        die "Múltiples nodos encontrados. Especifique cuál flashear: astra flash usb <node>
Nodos disponibles: ${NODES[*]}"
    fi
fi

# Validar que el nodo existe
NODE_DIR="$WORKSPACE/nodes/$NODE_ID"
NODE_YAML="$NODE_DIR/node.yaml"
FIRMWARE_YAML="$NODE_DIR/firmware.yaml"

if [ ! -f "$NODE_YAML" ]; then
    die "Nodo '$NODE_ID' no encontrado. Use 'astra node create $NODE_ID' para crearlo."
fi

if [ ! -f "$FIRMWARE_YAML" ]; then
    die "firmware.yaml no encontrado para '$NODE_ID'. Ejecute 'astra node create $NODE_ID' para regenerarlo."
fi

info "Workspace: $(basename "$WORKSPACE")"
info "Nodo: $NODE_ID"
info "Driver: $(yq '.driver' "$NODE_YAML")"
info "Board: $(yq '.board' "$NODE_YAML")"

# Verificar dependencias
check_docker
check_esphome

# Regenerar firmware.yaml desde node.yaml (por si cambió la config)
info "Regenerando firmware..."
"$ASTRA_HOME/drivers/esphome/driver.sh" render "$NODE_ID"

# Validar configuración con esphome config
info "Validando configuración ESPHome..."
VALIDATE_OUTPUT=$("$ASTRA_HOME/drivers/esphome/driver.sh" validate "$NODE_ID" 2>&1)
VALIDATE_EXIT=$?
if [ $VALIDATE_EXIT -ne 0 ]; then
    fail "La configuración ESPHome del nodo '$NODE_ID' no es válida."
    info "Revise board, sensores y configuración del firmware."
    echo "$VALIDATE_OUTPUT"
    exit $VALIDATE_EXIT
fi
echo "$VALIDATE_OUTPUT"

# Detectar puerto USB
detect_usb_ports() {
    find /dev -maxdepth 1 \( -name 'ttyUSB*' -o -name 'ttyACM*' \) 2>/dev/null | sort
}

PORTS=()
while IFS= read -r port; do
    [ -n "$port" ] && PORTS+=("$port")
done < <(detect_usb_ports)

if [ -n "$EXPLICIT_PORT" ]; then
    if [ ! -e "$EXPLICIT_PORT" ]; then
        die "Puerto especificado '$EXPLICIT_PORT' no existe."
    fi
    if [ ! -r "$EXPLICIT_PORT" ] || [ ! -w "$EXPLICIT_PORT" ]; then
        die "Sin permisos de lectura/escritura en '$EXPLICIT_PORT'. Ejecute: sudo usermod -aG dialout \$USER y reinicie sesión."
    fi
    PORT="$EXPLICIT_PORT"
    info "Usando puerto explícito: $PORT"
elif [ ${#PORTS[@]} -eq 0 ]; then
    die "No se detectó ningún dispositivo USB serial.
Conecte el ESP32 por USB y verifique con: ls /dev/ttyUSB* /dev/ttyACM*"
elif [ ${#PORTS[@]} -eq 1 ]; then
    PORT="${PORTS[0]}"
    info "Puerto USB detectado automáticamente: $PORT"
else
    die "Múltiples puertos USB serial detectados:
${PORTS[*]}
Use --port para especificar cuál: astra flash usb $NODE_ID --port <puerto>"
fi

# Flashear con ESPHome
info "Compilando y flasheando firmware en $PORT..."
docker run --rm --privileged \
    --device="$PORT" \
    -v "$NODE_DIR":/config \
    esphome/esphome \
    run firmware.yaml

ok "Firmware flasheado correctamente en $NODE_ID"