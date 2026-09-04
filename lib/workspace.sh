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
            export WORKSPACE="$dir"
            return 0
        fi

        dir="$(dirname "$dir")"

    done

    return 1
}

load_workspace() {
    workspace_find

    ASTRA_NAME=$(yq '.name' "$WORKSPACE/astra.yaml")

    WIFI_SSID=$(resolve_secret_from_tag "wifi.ssid" "$WORKSPACE/astra.yaml" "$WORKSPACE/secrets.yaml")
    WIFI_PASSWORD=$(resolve_secret_from_tag "wifi.password" "$WORKSPACE/astra.yaml" "$WORKSPACE/secrets.yaml")
    MQTT_HOST=$(resolve_secret_from_tag "mqtt.host" "$WORKSPACE/astra.yaml" "$WORKSPACE/secrets.yaml")

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
    tag=$(yq ".$path | tag" "$astra_file")

    if [ "$tag" = "!secret" ]; then
        local secret_key
        secret_key=$(yq ".$path" "$astra_file")

        if [ ! -f "$secrets_file" ]; then
            die "Campo '$path' requiere secreto pero no existe $secrets_file"
        fi

        local secret_value
        secret_value=$(yq ".$secret_key" "$secrets_file" 2>/dev/null)

        if [ -z "$secret_value" ] || [ "$secret_value" = "null" ]; then
            die "Secreto '$secret_key' no encontrado en $secrets_file"
        fi

        printf "%s" "$secret_value"
    else
        yq ".$path" "$astra_file"
    fi
}