#!/usr/bin/env bash
# ESPHome Driver for ASTRA CLI
# Subcommands: render, list-sensors, validate

set -e

COMMAND="${1:-}"
NODE_ID="${2:-}"

if [ -z "$ASTRA_HOME" ]; then
    ASTRA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

DRIVER_DIR="$ASTRA_HOME/drivers/esphome"
SENSORS_DIR="$DRIVER_DIR/sensors"
TEMPLATE="$DRIVER_DIR/template.yaml"

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/workspace.sh"

usage() {
    cat <<EOF
ESPHome Driver for ASTRA CLI

Uso:
    $0 render <node_id>     Genera firmware.yaml desde node.yaml
    $0 list-sensors         Lista sensores soportados
    $0 validate <node_id>   Valida configuración con esphome config
EOF
}

require_workspace() {
    workspace_require
    load_workspace
}

load_node() {
    local node_id="$1"
    NODE_DIR="$WORKSPACE/nodes/$node_id"
    NODE_YAML="$NODE_DIR/node.yaml"

    if [ ! -f "$NODE_YAML" ]; then
        die "Node '$node_id' no encontrado en $NODE_DIR"
    fi

    NODE_FRIENDLY_NAME=$(yq '.friendly_name' "$NODE_YAML")
    BOARD=$(yq '.board' "$NODE_YAML")
    SENSORS=$(yq '.sensors // [] | join(",")' "$NODE_YAML")

    if [ -z "$NODE_FRIENDLY_NAME" ] || [ "$NODE_FRIENDLY_NAME" = "null" ]; then
        die "node.yaml inválido: falta 'friendly_name'"
    fi
    if [ -z "$BOARD" ] || [ "$BOARD" = "null" ]; then
        die "node.yaml inválido: falta 'board'"
    fi
}

render_sensors_config() {
    local sensors_csv="$1"
    local sensors_config=""

    if [ -z "$sensors_csv" ]; then
        printf "%s" ""
        return 0
    fi

    IFS=',' read -ra SENSOR_ARRAY <<< "$sensors_csv"
    for SENSOR in "${SENSOR_ARRAY[@]}"; do
        SENSOR=$(echo "$SENSOR" | xargs)  # trim whitespace
        FRAGMENT="$SENSORS_DIR/${SENSOR}.yaml"
        if [ -f "$FRAGMENT" ]; then
            FRAGMENT_CONTENT=$(cat "$FRAGMENT")
            FRAGMENT_CONTENT="${FRAGMENT_CONTENT//\{\{NODE_FRIENDLY_NAME\}\}/$NODE_FRIENDLY_NAME}"
            # Add 2 spaces indentation for each line (for YAML under sensor:)
            FRAGMENT_CONTENT=$(echo "$FRAGMENT_CONTENT" | sed 's/^/  /')
            sensors_config="${sensors_config}${FRAGMENT_CONTENT}\n"
        else
            warn "Sensor fragment no encontrado: $SENSOR"
        fi
    done
    printf "%s" "$sensors_config"
}

cmd_render() {
    if [ -z "$NODE_ID" ]; then
        die "Uso: $0 render <node_id>"
    fi

    require_workspace
    load_node "$NODE_ID"

    SENSORS_CONFIG=$(render_sensors_config "$SENSORS")

    OUTPUT="$NODE_DIR/firmware.yaml"

    cat "$TEMPLATE" | \
        sed "s/{{NODE_ID}}/$NODE_ID/g" | \
        sed "s/{{NODE_FRIENDLY_NAME}}/$NODE_FRIENDLY_NAME/g" | \
        sed "s/{{BOARD}}/$BOARD/g" | \
        sed "s|{{MQTT_HOST}}|$MQTT_HOST|g" | \
        sed "s/{{WIFI_SSID}}/$WIFI_SSID/g" | \
        sed "s/{{WIFI_PASSWORD}}/$WIFI_PASSWORD/g" | \
        awk -v sensors="$SENSORS_CONFIG" '{gsub(/\{\{SENSORS_CONFIG\}\}/, sensors)} 1' \
        > "$OUTPUT"

    ok "Firmware generado: $OUTPUT"
}

cmd_list_sensors() {
    local raw="${2:-}"
    if [ "$raw" = "--raw" ]; then
        for fragment in "$SENSORS_DIR"/*.yaml; do
            [ -f "$fragment" ] || continue
            basename "$fragment" .yaml
        done
    else
        info "Sensores soportados por driver ESPHome:"
        for fragment in "$SENSORS_DIR"/*.yaml; do
            [ -f "$fragment" ] || continue
            sensor_name=$(basename "$fragment" .yaml)
            info "  - $sensor_name"
        done
    fi
}

cmd_validate() {
    if [ -z "$NODE_ID" ]; then
        die "Uso: $0 validate <node_id>"
    fi

    require_workspace
    load_node "$NODE_ID"

    cmd_render  # regenera firmware.yaml

    info "Validando configuración ESPHome para '$NODE_ID'..."
    docker run --rm \
        -v "$NODE_DIR":/config \
        esphome/esphome \
        config firmware.yaml >/dev/null

    ok "Configuración ESPHome válida"
}

case "$COMMAND" in
    render)
        cmd_render
        ;;
    list-sensors)
        cmd_list_sensors
        ;;
    validate)
        cmd_validate
        ;;
    *)
        usage
        exit 1
        ;;
esac