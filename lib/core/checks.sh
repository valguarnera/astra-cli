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

# check_lan_connectivity - Verifica conectividad básica de la IP LAN
# No bloquea, solo informa. Returns 0 if OK, 1 if no LAN IP, 2 if LAN IP but no gateway
check_lan_connectivity() {
    local lan_ip
    lan_ip=$(detect_lan_ip)
    if [ -z "$lan_ip" ]; then
        warn "No se detectó IP LAN 192.168.* para verificar conectividad." >&2
        return 1
    fi
    
    info "Detectando red LAN..."
    ok "IP LAN: $lan_ip"
    
    # Try to ping the gateway (first 3 octets + .1)
    local gateway_ip
    gateway_ip=$(echo "$lan_ip" | sed 's/\.[0-9]*$/.1/')
    
    if ping -c 1 -W 1 "$gateway_ip" >/dev/null 2>&1; then
        ok "Gateway $gateway_ip alcanzable"
        return 0
    else
        warn "Gateway $gateway_ip no responde a ping (puede ser normal si ICMP bloqueado)" >&2
        return 2
    fi
}

# check_mqtt_broker_connectivity - Verifica si el broker MQTT está accesible
# No bloquea, solo informa. Returns 0 if reachable, 1 if not
check_mqtt_broker_connectivity() {
    local mqtt_host="$1"
    local mqtt_port="${2:-1883}"
    
    if [ "$mqtt_host" = "localhost" ] || [ "$mqtt_host" = "127.0.0.1" ]; then
        warn "MQTT host es localhost, no se puede verificar conectividad de red" >&2
        return 1
    fi
    
    # Try TCP connection to MQTT port
    if command -v nc >/dev/null 2>&1; then
        if nc -z -w 2 "$mqtt_host" "$mqtt_port" >/dev/null 2>&1; then
            ok "Broker MQTT en $mqtt_host:$mqtt_port accesible"
            return 0
        else
            warn "Broker MQTT en $mqtt_host:$mqtt_port no accesible (¿está levantado?)" >&2
            return 1
        fi
    elif command -v timeout >/dev/null 2>&1; then
        # Fallback using timeout and bash TCP redirection
        if timeout 2 bash -c "cat < /dev/null > /dev/tcp/$mqtt_host/$mqtt_port" >/dev/null 2>&1; then
            ok "Broker MQTT en $mqtt_host:$mqtt_port accesible"
            return 0
        else
            warn "Broker MQTT en $mqtt_host:$mqtt_port no accesible (¿está levantado?)" >&2
            return 1
        fi
    else
        warn "No se puede verificar broker MQTT (nc o timeout no disponibles)" >&2
        return 1
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

# check_lan_connectivity - Verifica conectividad básica de la IP LAN
# No bloquea, solo informa. Returns 0 if OK, 1 if no LAN IP, 2 if LAN IP but no gateway
check_lan_connectivity() {
    local lan_ip
    lan_ip=$(detect_lan_ip)
    if [ -z "$lan_ip" ]; then
        warn "No se detectó IP LAN 192.168.* para verificar conectividad." >&2
        return 1
    fi
    
    info "Detectando red LAN..."
    ok "IP LAN: $lan_ip"
    
    # Try to ping the gateway (first 3 octets + .1)
    local gateway_ip
    gateway_ip=$(echo "$lan_ip" | sed 's/\.[0-9]*$/.1/')
    
    if ping -c 1 -W 1 "$gateway_ip" >/dev/null 2>&1; then
        ok "Gateway $gateway_ip alcanzable"
        return 0
    else
        warn "Gateway $gateway_ip no responde a ping (puede ser normal si ICMP bloqueado)" >&2
        return 2
    fi
}

# check_mqtt_broker_connectivity - Verifica si el broker MQTT está accesible
# No bloquea, solo informa. Returns 0 if reachable, 1 if not
check_mqtt_broker_connectivity() {
    local mqtt_host="$1"
    local mqtt_port="${2:-1883}"
    
    if [ "$mqtt_host" = "localhost" ] || [ "$mqtt_host" = "127.0.0.1" ]; then
        warn "MQTT host es localhost, no se puede verificar conectividad de red" >&2
        return 1
    fi
    
    # Try TCP connection to MQTT port
    if command -v nc >/dev/null 2>&1; then
        if nc -z -w 2 "$mqtt_host" "$mqtt_port" >/dev/null 2>&1; then
            ok "Broker MQTT en $mqtt_host:$mqtt_port accesible"
            return 0
        else
            warn "Broker MQTT en $mqtt_host:$mqtt_port no accesible (¿está levantado?)" >&2
            return 1
        fi
    elif command -v timeout >/dev/null 2>&1; then
        # Fallback using timeout and bash TCP redirection
        if timeout 2 bash -c "cat < /dev/null > /dev/tcp/$mqtt_host/$mqtt_port" >/dev/null 2>&1; then
            ok "Broker MQTT en $mqtt_host:$mqtt_port accesible"
            return 0
        else
            warn "Broker MQTT en $mqtt_host:$mqtt_port no accesible (¿está levantado?)" >&2
            return 1
        fi
    else
        warn "No se puede verificar broker MQTT (nc o timeout no disponibles)" >&2
        return 1
    fi
}

# ===========================================
# HARDWARE DETECTION FUNCTIONS
# ===========================================

# detect_esp_serial - Detecta dispositivos ESP8266/ESP32 conectados via USB
# Returns: device paths on stdout, returns 1 if none found
detect_esp_serial() {
    local ports
    # Common ESP device patterns
    ports=$(find /dev -maxdepth 1 \( -name 'ttyUSB*' -o -name 'ttyACM*' \) 2>/dev/null | sort)
    
    if [ -z "$ports" ]; then
        return 1
    fi
    
    local found=0
    for port in $ports; do
        # Try to identify ESP device by checking USB device info
        local vendor_id=""
        local product_id=""
        local dev_path="/sys/class/tty/$(basename $port)/device"
        
        if [ -f "$dev_path/../../idVendor" ]; then
            vendor_id=$(cat "$dev_path/../../idVendor" 2>/dev/null || true)
        fi
        if [ -f "$dev_path/../../idProduct" ]; then
            product_id=$(cat "$dev_path/../../idProduct" 2>/dev/null || true)
        fi
        
        # Common ESP vendor/product IDs
        # ESP8266/ESP32 common: 10c4:ea60 (CP210x), 1a86:7523 (CH340), 0403:6001 (FTDI)
        case "$vendor_id:$product_id" in
            "10c4:ea60"|"1a86:7523"|"0403:6001"|"1a86:55d4")
                printf "%s (vendor=%s product=%s - ESP compatible)\n" "$port" "$vendor_id" "$product_id"
                found=1
                ;;
            *)
                # Try to identify via dmesg/udev if possible
                if udevadm info -q property -n "$port" 2>/dev/null | grep -q -i "esp\|cp210\|ch340\|ftdi"; then
                    printf "%s (ESP compatible via udev)\n" "$port"
                    found=1
                else
                    printf "%s (unknown)\n" "$port"
                fi
                ;;
        esac
    done
    
    if [ $found -eq 1 ]; then
        return 0
    fi
    return 1
}

# check_esp_connectivity - Verifica comunicación con dispositivo ESP
# Returns 0 if ESP responds, 1 if no device, 2 if device but no response
check_esp_connectivity() {
    local port="${1:-}"
    
    if [ -z "$port" ]; then
        local ports
        ports=$(detect_esp_serial 2>/dev/null | grep -E "ESP compatible|CP210|CH340|FTDI" | head -1 | awk '{print $1}')
        if [ -z "$ports" ]; then
            warn "No se detectó dispositivo ESP compatible" >&2
            return 1
        fi
        port="$ports"
    fi
    
    if [ ! -e "$port" ]; then
        warn "Puerto $port no existe" >&2
        return 1
    fi
    
    if [ ! -r "$port" ] || [ ! -w "$port" ]; then
        warn "Sin permisos en $port. Ejecute: sudo usermod -aG dialout \$USER" >&2
        return 1
    fi
    
    info "Verificando conectividad con ESP en $port..."
    
    # Try to communicate with ESP using esptool or simple AT commands
    # First try esptool.py to read chip info
    if command -v esptool.py >/dev/null 2>&1; then
        if esptool.py --port "$port" chip_id >/dev/null 2>&1; then
            ok "ESP detectado y respondiendo en $port"
            return 0
        fi
    fi
    
    # Fallback: try simple serial communication with timeout
    # Send a basic AT command or just check if port is responsive
    if timeout 2 bash -c "echo -e 'AT\r\n' > $port && cat $port" 2>/dev/null | grep -q -i "ok\|ready\|esp"; then
        ok "ESP respondiendo en $port"
        return 0
    fi
    
    warn "Dispositivo en $port no responde como ESP8266/ESP32" >&2
    return 2
}

# identify_esp_board - Intenta identificar el modelo de ESP
# Returns board type on stdout: esp01, esp12, esp32, etc.
identify_esp_board() {
    local port="${1:-}"
    
    if [ -z "$port" ]; then
        local ports
        ports=$(detect_esp_serial 2>/dev/null | grep -E "ESP compatible|CP210|CH340|FTDI" | head -1 | awk '{print $1}')
        if [ -z "$ports" ]; then
            return 1
        fi
        port="$ports"
    fi
    
    if [ ! -e "$port" ]; then
        return 1
    fi
    
    # Try to get chip info via esptool
    if command -v esptool.py >/dev/null 2>&1; then
        local chip_info
        chip_info=$(esptool.py --port "$port" chip_id 2>&1)
        if echo "$chip_info" | grep -q "ESP32"; then
            printf "esp32"
            return 0
        elif echo "$chip_info" | grep -q "ESP8266"; then
            # Try to determine specific ESP8266 module
            local flash_info
            flash_info=$(esptool.py --port "$port" flash_id 2>&1)
            if echo "$flash_info" | grep -q "ESP8285\|ESP01"; then
                printf "esp01"
            elif echo "$flash_info" | grep -q "4MB"; then
                printf "esp12"
            else
                printf "esp8266"
            fi
            return 0
        fi
    fi
    
    # Fallback: check USB vendor/product IDs
    local dev_path="/sys/class/tty/$(basename $port)/device"
    if [ -f "$dev_path/../../idVendor" ] && [ -f "$dev_path/../../idProduct" ]; then
        local vendor_id product_id
        vendor_id=$(cat "$dev_path/../../idVendor" 2>/dev/null)
        product_id=$(cat "$dev_path/../../idProduct" 2>/dev/null)
        
        case "$vendor_id:$product_id" in
            "10c4:ea60") printf "cp210x" ;;  # Could be ESP8266 or ESP32
            "1a86:7523") printf "ch340" ;;
            "0403:6001") printf "ftdi" ;;
            *) printf "unknown" ;;
        esac
        return 0
    fi
    
    printf "unknown"
    return 1
}

# ===========================================
# USB STORAGE FUNCTIONS
# ===========================================

# detect_usb_storage - Detecta dispositivos de almacenamiento USB
# Returns device paths on stdout (e.g., /dev/sdb1), returns 1 if none
detect_usb_storage() {
    local devices
    # Find USB block devices (exclude system disk)
    devices=$(lsblk -d -o NAME,TRAN,TYPE,SIZE -n 2>/dev/null | awk '$2=="usb" && $3=="disk" {print "/dev/"$1}')
    
    if [ -z "$devices" ]; then
        return 1
    fi
    
    for dev in $devices; do
        # Get partition info
        local parts
        parts=$(lsblk -n -o NAME,SIZE,FSTYPE,MOUNTPOINT "/dev/$(basename $dev)" 2>/dev/null | tail -n +2)
        if [ -n "$parts" ]; then
            printf "%s\n" "$dev"
        else
            printf "%s (no partitions)\n" "$dev"
        fi
    done
    return 0
}

# mount_usb_storage - Monta una partición USB
# Args: device_path, mount_point
# Returns 0 on success
mount_usb_storage() {
    local device="$1"
    local mount_point="${2:-/mnt/astra_usb}"
    
    if [ ! -b "$device" ]; then
        warn "Dispositivo $device no es un dispositivo de bloque" >&2
        return 1
    fi
    
    mkdir -p "$mount_point"
    
    if mount "$device" "$mount_point" 2>/dev/null; then
        ok "Montado $device en $mount_point"
        return 0
    else
        warn "Error montando $device en $mount_point" >&2
        return 1
    fi
}

# unmount_usb_storage - Desmonta almacenamiento USB
unmount_usb_storage() {
    local mount_point="${1:-/mnt/astra_usb}"
    
    if mountpoint -q "$mount_point" 2>/dev/null; then
        if umount "$mount_point" 2>/dev/null; then
            ok "Desmontado $mount_point"
            return 0
        else
            warn "Error desmontando $mount_point" >&2
            return 1
        fi
    fi
    return 0
}

# test_usb_storage - Prueba escritura/lectura en almacenamiento USB
# Args: mount_point
usb_storage_test() {
    local mount_point="${1:-/mnt/astra_usb}"
    local test_file="$mount_point/astra_test_$(date +%s).tmp"
    local test_data="ASTRA USB Test $(date) RANDOM=$RANDOM"
    
    if ! mountpoint -q "$mount_point" 2>/dev/null; then
        warn "$mount_point no está montado" >&2
        return 1
    fi
    
    info "Probando escritura en $mount_point..."
    if echo "$test_data" > "$test_file" 2>/dev/null; then
        ok "Escritura exitosa"
    else
        warn "Error en escritura" >&2
        return 1
    fi
    
    info "Probando lectura..."
    local read_data
    read_data=$(cat "$test_file" 2>/dev/null)
    if [ "$read_data" = "$test_data" ]; then
        ok "Lectura exitosa - datos íntegros"
    else
        warn "Error en lectura o datos corruptos" >&2
        rm -f "$test_file"
        return 1
    fi
    
    info "Limpiando archivo de prueba..."
    rm -f "$test_file"
    ok "Prueba de almacenamiento USB completada"
    return 0
}

# ===========================================
# SENSOR DETECTION (via ESPHome/ESP device)
# ===========================================

# check_bmp580_sensor - Verifica sensor BMP580 via ESPHome
# Requiere ESP conectado y firmware con sensor configurado
check_bmp580_sensor() {
    local port="${1:-}"
    local node_id="${2:-}"
    
    if [ -z "$node_id" ]; then
        warn "Se requiere node_id para verificar sensor BMP580" >&2
        return 1
    fi
    
    local node_dir
    node_dir=$(get_node_dir "$node_id") || return 1
    
    local firmware_yaml="$node_dir/firmware.yaml"
    if [ ! -f "$firmware_yaml" ]; then
        warn "firmware.yaml no encontrado para nodo $node_id" >&2
        return 1
    fi
    
    # Verify BMP580 is configured in firmware
    if ! grep -q "bmp581_i2c" "$firmware_yaml" 2>/dev/null; then
        warn "Sensor BMP580 no configurado en firmware.yaml" >&2
        return 1
    fi
    
    # Check I2C configuration
    if ! grep -q "i2c:" "$firmware_yaml" 2>/dev/null; then
        warn "I2C no configurado en firmware.yaml (requerido para BMP580)" >&2
        return 1
    fi
    
    # If port provided, try to read sensor via ESPHome
    if [ -n "$port" ] && [ -e "$port" ]; then
        info "Verificando sensor BMP580 en $port..."
        # Use ESPHome to read sensor values
        if docker run --rm --device="$1" -v "$(dirname "$firmware_yaml")":/config esphome/esphome run firmware.yaml --dump-config 2>&1 | grep -q "bmp580"; then
            ok "BMP580 configurado correctamente en firmware"
            return 0
        fi
    fi
    
    ok "BMP580 configurado en firmware.yaml"
    return 0
}

# check_ds18b20_sensor - Verifica sensor DS18B20 via ESPHome
check_ds18b20_sensor() {
    local port="${1:-}"
    local node_id="${2:-}"
    
    if [ -z "$node_id" ]; then
        warn "Se requiere node_id para verificar sensor DS18B20" >&2
        return 1
    fi
    
    local node_dir
    node_dir=$(get_node_dir "$node_id") || return 1
    
    local firmware_yaml="$node_dir/firmware.yaml"
    if [ ! -f "$firmware_yaml" ]; then
        warn "firmware.yaml no encontrado para nodo $node_id" >&2
        return 1
    fi
    
    # Verify DS18B20 is configured in firmware
    if ! grep -q "dallas_temp" "$firmware_yaml" 2>/dev/null; then
        warn "Sensor DS18B20 no configurado en firmware.yaml" >&2
        return 1
    fi
    
    # Check 1-Wire configuration
    if ! grep -q "one_wire:" "$firmware_yaml" 2>/dev/null; then
        warn "1-Wire no configurado en firmware.yaml (requerido para DS18B20)" >&2
        return 1
    fi
    
    ok "DS18B20 configurado correctamente en firmware.yaml"
    return 0
}

# get_node_dir - Helper to get node directory from node_id
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
