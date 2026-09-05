#!/usr/bin/env bash

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/core/utils.sh"
source "$ASTRA_HOME/lib/template.sh"

create_directory() {
  local dir="$1"

  if [ ! -d "$dir" ]; then
    mkdir -p "$dir"
  else
    warn "$dir ya existe"
  fi
}

create_workspace(){
  create_directory "$WORKSPACE"
  ok "Workspace"
}

create_astra_yaml() {
    write_file "$WORKSPACE/astra.yaml" <<EOF
name: $PROJECT_NAME

version: 1

mqtt:
  host: !secret mqtt_host
  port: 1883

wifi:
  ssid: !secret wifi_ssid
  password: !secret wifi_password
EOF
}

create_secrets_yaml() {
    write_file "$WORKSPACE/secrets.yaml" <<EOF
wifi_ssid: $WIFI_SSID
wifi_password: $WIFI_PASSWORD
mqtt_host: $MQTT_HOST
EOF
}

create_git_ignore() {
    write_file "$WORKSPACE/.gitignore" <<EOF
secrets.yaml
nodes/*/firmware.yaml
docker/mosquitto/
build/
.temp/
EOF
}

create_directories() {
    create_directory "$WORKSPACE/nodes"
    create_directory "$WORKSPACE/docker"
    ok "Directories"
}

create_docker_compose() {
    write_file "$WORKSPACE/docker/docker-compose.yml" <<EOF
services:
  mosquitto:
    image: eclipse-mosquitto:2
    ports:
      - "1883:1883"
      - "9001:9001"
    volumes:
      - ./mosquitto:/mosquitto
EOF
}

require_yq() {
    if ! command -v yq >/dev/null 2>&1; then
        die "yq (mikefarah/yq) es requerido pero no está instalado.
Instalá con: sudo snap install yq  o  descargá el binary de https://github.com/mikefarah/yq"
    fi
    local yq_version
    yq_version=$(yq --version 2>&1 || true)
    if [[ "$yq_version" != *"mikefarah"* ]] && [[ "$yq_version" != *"https://github.com/mikefarah/yq"* ]]; then
        die "yq instalado es incompatible (se requiere mikefarah/yq v4.x).
Detectado: $yq_version"
    fi
}

workspace_require() {
    if ! workspace_find; then
        error "No se encontró un Workspace ASTRA."
        info "Ejecutá 'astra init <nombre>' para crear uno."
        exit 1
    fi
}

workspace_find() {
    local dir="$PWD"

    while [ "$dir" != "/" ]; do

        if [ -f "$dir/astra.yaml" ]; then
            export WORKSPACE="$(cd "$dir" && pwd)"
            return 0
        fi

        dir="$(dirname "$dir")"

    done

    return 1
}

load_workspace() {
    require_yq
    workspace_find

    if [ ! -f "$WORKSPACE/astra.yaml" ]; then
        die "astra.yaml no encontrado en $WORKSPACE"
    fi

    ASTRA_NAME=$(yq '.name' "$WORKSPACE/astra.yaml")
    if [ -z "$ASTRA_NAME" ] || [ "$ASTRA_NAME" = "null" ]; then
        die "astra.yaml inválido: falta campo 'name'"
    fi

    if ! yq '.mqtt' "$WORKSPACE/astra.yaml" >/dev/null 2>&1; then
        die "astra.yaml inválido: falta sección 'mqtt'"
    fi

    if ! yq '.wifi' "$WORKSPACE/astra.yaml" >/dev/null 2>&1; then
        die "astra.yaml inválido: falta sección 'wifi'"
    fi

    WIFI_SSID=$(resolve_secret_from_tag "wifi.ssid" "$WORKSPACE/astra.yaml" "$WORKSPACE/secrets.yaml") || die "Error resolviendo wifi.ssid"
    WIFI_PASSWORD=$(resolve_secret_from_tag "wifi.password" "$WORKSPACE/astra.yaml" "$WORKSPACE/secrets.yaml") || die "Error resolviendo wifi.password"
    MQTT_HOST=$(resolve_secret_from_tag "mqtt.host" "$WORKSPACE/astra.yaml" "$WORKSPACE/secrets.yaml") || die "Error resolviendo mqtt.host"

    if [ -z "$WIFI_SSID" ] || [ -z "$WIFI_PASSWORD" ] || [ -z "$MQTT_HOST" ]; then
        die "Error resolviendo configuración: variables vacías tras resolver secrets"
    fi

    export ASTRA_NAME
    export WIFI_SSID
    export WIFI_PASSWORD
    export MQTT_HOST
}

resolve_secret_from_tag() {
    local path="$1"
    local astra_file="$2"
    local secrets_file="$3"

    local tag
    tag=$(yq ".$path | tag" "$astra_file" 2>/dev/null) || return 1

    if [ "$tag" = "!secret" ]; then
        local secret_key
        secret_key=$(yq ".$path" "$astra_file" 2>/dev/null) || return 1

        if [ ! -f "$secrets_file" ]; then
            fail "Campo '$path' requiere secreto pero no existe $secrets_file" >&2
            return 1
        fi

        local secret_value
        secret_value=$(yq ".$secret_key" "$secrets_file" 2>/dev/null)

        if [ -z "$secret_value" ] || [ "$secret_value" = "null" ]; then
            fail "Secreto '$secret_key' no encontrado en $secrets_file" >&2
            return 1
        fi

        printf "%s" "$secret_value"
        return 0
    else
        yq ".$path" "$astra_file"
        return $?
    fi
}