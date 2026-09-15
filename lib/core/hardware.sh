#!/usr/bin/env bash

if [ -z "$ASTRA_HOME" ]; then
    ASTRA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

source "$ASTRA_HOME/lib/core/ui.sh"

detect_esp_serial() {
    local ports
    ports=$(find /dev -maxdepth 1 \( -name 'ttyUSB*' -o -name 'ttyACM*' \) 2>/dev/null | sort)

    if [ -z "$ports" ]; then
        return 1
    fi

    local found=0
    for port in $ports; do
        local vendor_id=""
        local product_id=""
        local dev_path="/sys/class/tty/$(basename $port)/device"

        if [ -f "$dev_path/../../idVendor" ]; then
            vendor_id=$(cat "$dev_path/../../idVendor" 2>/dev/null || true)
        fi
        if [ -f "$dev_path/../../idProduct" ]; then
            product_id=$(cat "$dev_path/../../idProduct" 2>/dev/null || true)
        fi

        case "$vendor_id:$product_id" in
            "10c4:ea60"|"1a86:7523"|"0403:6001"|"1a86:55d4")
                printf "%s (vendor=%s product=%s - ESP compatible)\n" "$port" "$vendor_id" "$product_id"
                found=1
                ;;
            *)
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

    if command -v esptool.py >/dev/null 2>&1; then
        if esptool.py --port "$port" chip_id >/dev/null 2>&1; then
            ok "ESP detectado y respondiendo en $port"
            return 0
        fi
    fi

    if timeout 2 bash -c "echo -e 'AT\r\n' > $port && cat $port" 2>/dev/null | grep -q -i "ok\|ready\|esp"; then
        ok "ESP respondiendo en $port"
        return 0
    fi

    warn "Dispositivo en $port no responde como ESP8266/ESP32" >&2
    return 2
}

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

    if command -v esptool.py >/dev/null 2>&1; then
        local chip_info
        chip_info=$(esptool.py --port "$port" chip_id 2>&1)
        if echo "$chip_info" | grep -q "ESP32"; then
            printf "esp32"
            return 0
        elif echo "$chip_info" | grep -q "ESP8266"; then
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

    local dev_path="/sys/class/tty/$(basename $port)/device"
    if [ -f "$dev_path/../../idVendor" ] && [ -f "$dev_path/../../idProduct" ]; then
        local vendor_id product_id
        vendor_id=$(cat "$dev_path/../../idVendor" 2>/dev/null)
        product_id=$(cat "$dev_path/../../idProduct" 2>/dev/null)

        case "$vendor_id:$product_id" in
            "10c4:ea60") printf "cp210x" ;;
            "1a86:7523") printf "ch340" ;;
            "0403:6001") printf "ftdi" ;;
            *) printf "unknown" ;;
        esac
        return 0
    fi

    printf "unknown"
    return 1
}