#!/usr/bin/env bash

if [ -z "$ASTRA_HOME" ]; then
    ASTRA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

source "$ASTRA_HOME/lib/core/ui.sh"

# ===========================================
# CHECK FUNCTIONS (return 0 if OK, 1 if missing)
# ===========================================

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

# ===========================================
# INSTALL FUNCTIONS (for missing dependencies)
# ===========================================

install_docker() {
    info "Instalando Docker..."
    
    # Detect distro
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
    
    # Enable and start service
    sudo systemctl enable docker 2>/dev/null || true
    sudo systemctl start docker 2>/dev/null || true
    
    # Add user to docker group
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
    
    # Prefer binary install (works everywhere)
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

# ===========================================
# HIGH-LEVEL CHECK + INSTALL ORCHESTRATOR
# ===========================================

# Usage: ensure_dependency <check_func> <install_func> <name>
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

# ===========================================
# NETWORK FUNCTIONS
# ===========================================

# detect_lan_ip - Detecta la primera IP LAN 192.168.* disponible
# Returns: IP address on stdout, returns 1 if not found
detect_lan_ip() {
    local ips
    # Use hostname -I to get all IPs, then find first 192.168.*
    ips=$(hostname -I 2>/dev/null || true)
    
    for ip in $ips; do
        # Skip loopback
        if [[ "$ip" =~ ^127\. ]]; then
            continue
        fi
        # Skip IPv6
        if [[ "$ip" == *:* ]]; then
            continue
        fi
        # Prefer 192.168.*
        if [[ "$ip" =~ ^192\.168\. ]]; then
            printf "%s" "$ip"
            return 0
        fi
    done
    
    # No 192.168.* found, return first non-loopback, non-Docker, non-IPv6 IP
    for ip in $ips; do
        if [[ "$ip" =~ ^127\. ]]; then
            continue
        fi
        if [[ "$ip" == *:* ]]; then
            continue
        fi
        # Skip Docker networks (172.16-31.*)
        if [[ "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]]; then
            continue
        fi
        printf "%s" "$ip"
        return 0
    done
    
    return 1
}

# get_default_mqtt_host - Obtiene el host MQTT por defecto
# Prioriza 192.168.*, luego fallback a localhost con warning
get_default_mqtt_host() {
    local lan_ip
    lan_ip=$(detect_lan_ip)
    if [ -n "$lan_ip" ]; then
        printf "%s" "$lan_ip"
        return 0
    fi
    # Fallback a localhost con warning (a stderr)
    warn "No se detectó IP LAN 192.168.*. Usando 'localhost' como fallback." >&2
    warn "Para hardware físico, configure mqtt_host con IP LAN accesible desde el ESP." >&2
    printf "localhost"
    return 1
}

# Run all checks (for install.sh --check-only mode)
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
