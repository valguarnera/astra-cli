#!/usr/bin/env bash

if [ -z "$ASTRA_HOME" ]; then
    ASTRA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

source "$ASTRA_HOME/lib/core/ui.sh"

check_os() {
    if [[ "$OSTYPE" == linux* ]]; then
        ok "Linux"
        return 0
    else
        return 1
    fi
}

check_docker() {
    if command -v docker >/dev/null 2>&1; then
        ok "Docker"
        return 0
    fi
    return 1
}

check_compose() {
    if command -v docker-compose >/dev/null 2>&1 || docker compose version >/dev/null 2>&1; then
        ok "Docker Compose"
        return 0
    fi
    return 1
}

check_daemon() {
    if docker info >/dev/null 2>&1; then
        ok "Docker Daemon"
        return 0
    fi
    return 1
}

check_docker_permissions() {
    if docker ps >/dev/null 2>&1; then
        ok "Docker Permissions"
        return 0
    fi
    return 1
}

check_yq() {
    if command -v yq >/dev/null 2>&1; then
        local yq_version
        yq_version=$(yq --version 2>&1 || true)
        if [[ "$yq_version" == *"mikefarah"* ]] || [[ "$yq_version" == *"https://github.com/mikefarah/yq"* ]]; then
            ok "yq (mikefarah/yq)"
            return 0
        fi
        warn "yq encontrado pero no es la implementación requerida (mikefarah/yq)"
        warn "Versión detectada: $yq_version"
    fi
    return 1
}

check_esphome() {
    if docker image inspect esphome/esphome >/dev/null 2>&1; then
        ok "ESPHome image"
        return 0
    fi
    return 1
}

ensure_dependency() {
    local check_func="$1"
    local install_func="$2"
    local name="$3"

    if $check_func; then
        return 0
    fi

    warn "$name no encontrado. Instalando..."
    if $install_func; then
        ok "$name instalado correctamente"
        return 0
    else
        die "No se pudo instalar $name. Instálelo manualmente e intente de nuevo."
    fi
}