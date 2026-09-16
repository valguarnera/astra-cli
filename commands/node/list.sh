#!/usr/bin/env bash

# astra node list - Lista los nodos del workspace

set -e

if [ -z "$ASTRA_HOME" ]; then
    ASTRA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/workspace.sh"

workspace_require
load_workspace

NODES=("$WORKSPACE/nodes/"*/)
NODES=("${NODES[@]%/}")
NODES=("${NODES[@]##*/}")

if [ ${#NODES[@]} -eq 0 ] || [ "${NODES[0]}" = "*" ]; then
    info "No hay nodos en el workspace"
    exit 0
fi

info "Nodos en el workspace:"
for node in "${NODES[@]}"; do
    NODE_DIR="$WORKSPACE/nodes/$node"
    if [ -f "$NODE_DIR/node.yaml" ]; then
        BOARD=$(yq '.board' "$NODE_DIR/node.yaml" 2>/dev/null)
        SENSORS=$(yq '.sensors | join(",")' "$NODE_DIR/node.yaml" 2>/dev/null)
        FRIENDLY=$(yq '.friendly_name' "$NODE_DIR/node.yaml" 2>/dev/null)
        printf "  • %s (board: %s, sensors: %s)\n" "$node" "${BOARD:-?}" "${SENSORS:-none}"
    else
        printf "  • %s (sin node.yaml)\n" "$node"
    fi
done