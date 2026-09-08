#!/usr/bin/env bash

set -e

DEV_MODE=false
CHECK_ONLY=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/core/ui.sh"
source "$SCRIPT_DIR/lib/core/utils.sh"
source "$SCRIPT_DIR/lib/core/checks.sh"

while [ $# -gt 0 ]; do
    case "$1" in
        --dev)
            DEV_MODE=true
            info "Modo desarrollo 💻"
            shift
            ;;
        --check-only)
            CHECK_ONLY=true
            info "Modo verificación de dependencias"
            shift
            ;;
        --help|-h)
            cat <<EOF
Uso: $0 [OPCIONES]

Opciones:
    --dev          Instala en modo desarrollo (symlink a /opt/astra)
    --check-only   Solo verifica dependencias, no instala astra-cli
    --help, -h     Muestra esta ayuda
EOF
            exit 0
            ;;
        *)
            die "Opción desconocida: $1"
            ;;
    esac
done

info "Verificando dependencias del sistema..."

# Ensure all dependencies (with auto-install if missing)
ensure_dependency check_docker install_docker "Docker"
ensure_dependency check_compose install_docker "Docker Compose"
ensure_dependency check_daemon install_docker "Docker Daemon"
ensure_dependency check_docker_permissions install_docker "Docker Permissions"
ensure_dependency check_yq install_yq "yq"
ensure_dependency check_esphome install_esphome "ESPHome"

if [ "$CHECK_ONLY" = true ]; then
    success "Todas las dependencias verificadas"
    exit 0
fi

info "Instalando ASTRA CLI..."

if $DEV_MODE; then
    install_cli_dev
else
    install_cli
fi

create_launcher
pull_images

success "ASTRA CLI installed successfully."