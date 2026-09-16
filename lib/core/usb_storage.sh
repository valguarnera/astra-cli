#!/usr/bin/env bash

if [ -z "$ASTRA_HOME" ]; then
    ASTRA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

source "$ASTRA_HOME/lib/core/ui.sh"

detect_usb_storage() {
    local devices
    devices=$(lsblk -d -o NAME,TRAN,TYPE,SIZE -n 2>/dev/null | awk '$2=="usb" && $3=="disk" {print "/dev/"$1}')

    if [ -z "$devices" ]; then
        return 1
    fi

    for dev in $devices; do
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