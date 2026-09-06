#!/usr/bin/env bash

# astra logs usb <node> [--port <port>] [--follow] [--lines <n>]
# Muestra los logs seriales de un nodo ESP32 por USB usando ESPHome

set -e

if [ -z "$ASTRA_HOME" ]; then
    ASTRA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/workspace.sh"
source "$ASTRA_HOME/lib/core/checks.sh"

usage() {
    cat <<EOF
astra logs usb - Muestra logs seriales de un nodo ESP32 por USB

Uso:
    astra logs usb <node> [--port <port>] [--follow] [--lines <n>]

Argumentos:
    <node>              ID del nodo (ej: sensor01)

Opciones:
    --port <port>       Puerto serial específico (ej: /dev/ttyUSB1)
                        Si no se especifica, se auto-detecta.
    --follow, -f        Seguir logs continuamente (default: true)
    --lines, -n <n>     Número de líneas a mostrar (default: todas)
    --no-follow         Mostrar últimas líneas y salir

Ejemplos:
    astra logs usb sensor01
    astra logs usb sensor01 --port /dev/ttyUSB1
    astra logs usb sensor01 --follow
    astra logs usb sensor01 --lines 50
EOF
}

# Parsear argumentos
NODE_ID=""
EXPLICIT_PORT=""
FOLLOW=true
LINES=""

while [ $# -gt 0 ]; do
    case "$1" in
        --port)
            EXPLICIT_PORT="$2"
            shift 2
            ;;
        --follow|-f)
            FOLLOW=true
            shift
            ;;
        --no-follow)
            FOLLOW=false
            shift
            ;;
        --lines|-n)
            LINES="$2"
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
        die "Múltiples nodos encontrados. Especifique cuál: astra logs usb <node>
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
    die "firmware.yaml no encontrado para '$NODE_ID'. Ejecute 'astra node create $NODE_ID' para generarlo."
fi

info "Workspace: $(basename "$WORKSPACE")"
info "Nodo: $NODE_ID"

# Verificar dependencias
check_docker
check_esphome

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
Use --port para especificar cuál: astra logs usb $NODE_ID --port <puerto>"
fi

# Construir comando de logs
LOGS_CMD="logs firmware.yaml"
if [ "$FOLLOW" = true ]; then
    LOGS_CMD="$LOGS_CMD --follow"
fi
if [ -n "$LINES" ]; then
    LOGS_CMD="$LOGS_CMD --lines $LINES"
fi

info "Conectando a $PORT para ver logs de $NODE_ID..."
info "Presione Ctrl+C para salir."

# Ejecutar logs con ESPHome
docker run --rm -it \
    --device="$PORT" \
    -v "$NODE_DIR":/config \
    esphome/esphome \
    $LOGS_CMD