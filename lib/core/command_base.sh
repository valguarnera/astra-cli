#!/usr/bin/env bash

if [ -z "$ASTRA_HOME" ]; then
    ASTRA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/workspace.sh"
source "$ASTRA_HOME/lib/core/dependencies.sh"
source "$ASTRA_HOME/lib/core/hardware.sh"

command_preflight() {
    workspace_require
    load_workspace
    check_docker
    check_yq
    check_esphome
}

command_preflight_node() {
    command_preflight
    
    local node_id="${1:-}"
    if [ -z "$node_id" ]; then
        NODES=("$WORKSPACE/nodes/"*/)
        NODES=("${NODES[@]%/}")
        NODES=("${NODES[@]##*/}")
        
        if [ ${#NODES[@]} -eq 0 ]; then
            die "No hay nodos en el workspace. Use 'astra node create <id>' para crear uno."
        elif [ ${#NODES[@]} -eq 1 ]; then
            node_id="${NODES[0]}"
            info "Auto-seleccionando único nodo: $node_id"
        else
            die "Múltiples nodos encontrados. Especifique cuál: astra $COMMAND <node>
Nodos disponibles: ${NODES[*]}"
        fi
    fi
    
    NODE_DIR="$WORKSPACE/nodes/$node_id"
    NODE_YAML="$NODE_DIR/node.yaml"
    FIRMWARE_YAML="$NODE_DIR/firmware.yaml"
    
    if [ ! -f "$NODE_YAML" ]; then
        die "Nodo '$node_id' no encontrado. Use 'astra node create $node_id' para crearlo."
    fi
    
    if [ ! -f "$FIRMWARE_YAML" ]; then
        die "firmware.yaml no encontrado para '$node_id'. Ejecute 'astra node create $node_id' para generarlo."
    fi
    
    export NODE_ID="$node_id"
    export NODE_DIR
    export NODE_YAML
    export FIRMWARE_YAML
}

detect_serial_ports() {
    find /dev -maxdepth 1 \( -name 'ttyUSB*' -o -name 'ttyACM*' \) 2>/dev/null | sort
}

select_serial_port() {
    local explicit_port="${1:-}"
    local ports=()
    
    while IFS= read -r port; do
        [ -n "$port" ] && ports+=("$port")
    done < <(detect_serial_ports)
    
    if [ -n "$explicit_port" ]; then
        if [ ! -e "$explicit_port" ]; then
            die "Puerto especificado '$explicit_port' no existe."
        fi
        if [ ! -r "$explicit_port" ] || [ ! -w "$explicit_port" ]; then
            die "Sin permisos de lectura/escritura en '$explicit_port'. Ejecute: sudo usermod -aG dialout \$USER y reinicie sesión."
        fi
        printf "%s" "$explicit_port"
        return 0
    elif [ ${#ports[@]} -eq 0 ]; then
        die "No se detectó ningún dispositivo USB serial.
Conecte el ESP32 por USB y verifique con: ls /dev/ttyUSB* /dev/ttyACM*"
    elif [ ${#ports[@]} -eq 1 ]; then
        printf "%s" "${ports[0]}"
        return 0
    else
        die "Múltiples puertos USB serial detectados:
${ports[*]}
Use --port para especificar cuál: astra $COMMAND $NODE_ID --port <puerto>"
    fi
}

regenerate_firmware() {
    local node_id="${1:-$NODE_ID}"
    info "Regenerando firmware..."
    "$ASTRA_HOME/drivers/esphome/driver.sh" render "$node_id"
}

validate_firmware() {
    local node_id="${1:-$NODE_ID}"
    local node_dir="${2:-$NODE_DIR}"
    
    info "Validando configuración ESPHome..."
    local validate_output
    validate_output=$("$ASTRA_HOME/drivers/esphome/driver.sh" validate "$node_id" 2>&1)
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        fail "La configuración ESPHome del nodo '$node_id' no es válida."
        info "Revise board, sensores y configuración del firmware."
        echo "$validate_output"
        return $exit_code
    fi
    echo "$validate_output"
}