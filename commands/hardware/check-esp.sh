#!/usr/bin/env bash

# astra hardware check-esp [port] - Verifica conectividad con ESP

set -e

if [ -z "$ASTRA_HOME" ]; then
    ASTRA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/core/checks.sh"

PORT="${1:-}"

info "Verificando conectividad ESP..."
if check_esp_connectivity "$PORT"; then
    ok "ESP conectado y respondiendo"
else
    warn "ESP no responde (puede necesitar firmware o estar en modo boot)"
    exit 1
fi
