#!/usr/bin/env bash

if [ -z "$ASTRA_HOME" ]; then
    ASTRA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/core/dependencies.sh"

install_docker() {
    info "Instalando Docker..."

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                sudo apt-get update && sudo apt-get install -y docker.io docker-compose-plugin
                ;;
            fedora|rhel|centos)
                sudo dnf install -y docker docker-compose
                ;;
            arch|manjaro)
                sudo pacman -S --noconfirm docker docker-compose
                ;;
            *)
                warn "Distro no reconocida ($ID). Intentando instalación genérica..."
                curl -fsSL https://get.docker.com | sudo sh
                ;;
        esac
    else
        curl -fsSL https://get.docker.com | sudo sh
    fi

    sudo systemctl enable docker 2>/dev/null || true
    sudo systemctl start docker 2>/dev/null || true

    sudo usermod -aG docker "$USER" 2>/dev/null || true

    verify_docker
}

verify_docker() {
    if check_docker; then
        info "Docker instalado y verificado"
        return 0
    fi
    return 1
}

install_yq() {
    info "Instalando yq (mikefarah/yq)..."

    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64) yq_arch="linux_amd64" ;;
        aarch64) yq_arch="linux_arm64" ;;
        armv7l) yq_arch="linux_arm" ;;
        *) die "Arquitectura no soportada para yq: $arch" ;;
    esac

    sudo wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_${yq_arch}"
    sudo chmod +x /usr/local/bin/yq

    verify_yq
}

verify_yq() {
    if check_yq; then
        info "yq instalado y verificado"
        return 0
    fi
    return 1
}

install_esphome() {
    info "Descargando imagen ESPHome..."

    if docker pull esphome/esphome; then
        info "Imagen ESPHome descargada"
        return 0
    fi
    return 1
}

verify_esphome() {
    if check_esphome; then
        info "ESPHome image verificada"
        return 0
    fi
    return 1
}