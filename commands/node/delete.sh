#!/usr/bin/env bash

# astra node delete <id> - Elimina un nodo del workspace

set -e

if [ -z "$ASTRA_HOME" ]; then
    ASTRA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/workspace.sh"

usage() {
    cat <<EOF
astra node delete - Elimina un nodo del workspace

Uso:
    astra node delete <id>

Argumentos:
    <id>    Identificador del nodo a eliminar

Ejemplos:
    astra node delete sensor01
EOF
}

if [ -z "$1" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
    exit 0
fi

NODE_ID="$1"

workspace_require
load_workspace

NODE_DIR="$WORKSPACE/nodes/$NODE_ID"

if [ ! -d "$NODE_DIR" ]; then
    die "Nodo '$NODE_ID' no encontrado en $WORKSPACE/nodes/"
fi

# Confirmación
warn "Esto eliminará el directorio completo: $NODE_DIR"
read -rp "¿Continuar? [y/N]: " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    info "Cancelado"
    exit 0
fi

rm -rf "$NODE_DIR"
ok "Nodo '$NODE_ID' eliminado"