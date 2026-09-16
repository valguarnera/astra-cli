#!/usr/bin/env bash

if [ -z "$ASTRA_HOME" ]; then
    ASTRA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

source "$ASTRA_HOME/lib/core/ui.sh"

detect_lan_ip() {
    local ips
    ips=$(hostname -I 2>/dev/null || true)

    for ip in $ips; do
        if [[ "$ip" =~ ^127\. ]]; then
            continue
        fi
        if [[ "$ip" == *:* ]]; then
            continue
        fi
        if [[ "$ip" =~ ^192\.168\. ]]; then
            printf "%s" "$ip"
            return 0
        fi
    done

    for ip in $ips; do
        if [[ "$ip" =~ ^127\. ]]; then
            continue
        fi
        if [[ "$ip" == *:* ]]; then
            continue
        fi
        if [[ "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]]; then
            continue
        fi
        printf "%s" "$ip"
        return 0
    done

    return 1
}

get_default_mqtt_host() {
    local lan_ip
    lan_ip=$(detect_lan_ip)
    if [ -n "$lan_ip" ]; then
        printf "%s" "$lan_ip"
        return 0
    fi
    warn "No se detectó IP LAN 192.168.*. Usando 'localhost' como fallback." >&2
    warn "Para hardware físico, configure mqtt_host con IP LAN accesible desde el ESP." >&2
    printf "localhost"
    return 1
}

check_lan_connectivity() {
    local lan_ip
    lan_ip=$(detect_lan_ip)
    if [ -z "$lan_ip" ]; then
        warn "No se detectó IP LAN 192.168.* para verificar conectividad." >&2
        return 1
    fi

    info "Detectando red LAN..."
    ok "IP LAN: $lan_ip"

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

check_mqtt_broker_connectivity() {
    local mqtt_host="$1"
    local mqtt_port="${2:-1883}"

    if [ "$mqtt_host" = "localhost" ] || [ "$mqtt_host" = "127.0.0.1" ]; then
        warn "MQTT host es localhost, no se puede verificar conectividad de red" >&2
        return 1
    fi

    if command -v nc >/dev/null 2>&1; then
        if nc -z -w 2 "$mqtt_host" "$mqtt_port" >/dev/null 2>&1; then
            ok "Broker MQTT en $mqtt_host:$mqtt_port accesible"
            return 0
        else
            warn "Broker MQTT en $mqtt_host:$mqtt_port no accesible (¿está levantado?)" >&2
            return 1
        fi
    elif command -v timeout >/dev/null 2>&1; then
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