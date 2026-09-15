#!/usr/bin/env bash

if [ -z "$ASTRA_HOME" ]; then
    ASTRA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

source "$ASTRA_HOME/lib/core/dependencies.sh"
source "$ASTRA_HOME/lib/core/hardware.sh"
source "$ASTRA_HOME/lib/core/usb_storage.sh"
source "$ASTRA_HOME/lib/core/network.sh"
source "$ASTRA_HOME/lib/core/installer.sh"

get_node_dir() {
    local node_id="$1"
    local workspace
    workspace=$(get_workspace) || return 1
    local node_dir="$workspace/nodes/$1"
    if [ ! -d "$node_dir" ]; then
        return 1
    fi
    printf "%s" "$node_dir"
    return 0
}

get_workspace() {
    workspace_find
    if [ -z "$WORKSPACE" ]; then
        return 1
    fi
    printf "%s" "$WORKSPACE"
    return 0
}

run_all_checks() {
    local all_ok=1

    check_os || { error "Linux requerido"; all_ok=0; }
    check_docker || { error "Docker no instalado"; all_ok=0; }
    check_compose || { error "Docker Compose no instalado"; all_ok=0; }
    check_daemon || { error "Docker daemon no corriendo"; all_ok=0; }
    check_docker_permissions || { error "Sin permisos Docker"; all_ok=0; }
    check_yq || { error "yq no instalado"; all_ok=0; }
    check_esphome || { error "ESPHome image no disponible"; all_ok=0; }

    return $all_ok
}