#!/usr/bin/env bash

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/workspace.sh"
source "$ASTRA_HOME/lib/core/checks.sh"

if [ -n "$1" ]; then
    WORKSPACE="$PWD/$1"
else
    WORKSPACE="$PWD"
fi

if [ -f "$WORKSPACE/astra.yaml" ]; then
    error "Ya existe un Workspace ASTRA en esta ubicación."
    exit 1
fi

PROJECT_NAME="${WORKSPACE##*/}"

info "Initializing ASTRA Workspace...

Project............. ${PROJECT_NAME}"
WIFI_SSID=$(prompt "WiFi SSID..........." "")
WIFI_PASSWORD=$(prompt_secret "WiFi Password....... ")

# Detectar IP LAN por defecto para MQTT
DEFAULT_MQTT_HOST=$(get_default_mqtt_host)
MQTT_HOST=$(prompt "Broker.............." "$DEFAULT_MQTT_HOST")
echo ""

create_workspace

create_astra_yaml
create_secrets_yaml
create_git_ignore
create_directories
create_docker_compose

echo ""
success "Workspace creado."