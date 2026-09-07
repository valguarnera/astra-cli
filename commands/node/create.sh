#!/usr/bin/env bash

# astra node create - Crea un nuevo nodo en el workspace
#
# Uso: astra node create <id> --board <board> --sensors <sensor1,sensor2> [--driver <driver>]

set -e

if [ -z "$ASTRA_HOME" ]; then
    ASTRA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/workspace.sh"
source "$ASTRA_HOME/lib/core/checks.sh"

usage() {
    cat <<EOF
astra node create - Crea un nuevo nodo

Uso:
    astra node create <id> --board <board> --sensors <sensor1,sensor2> [--driver <driver>]

Argumentos:
    <id>                Identificador único del nodo (ej: sensor01)

Opciones:
    --board <board>     Board ESPHome (ej: esp32dev, esp32-c3-devkitm-1)
    --sensors <list>    Lista de sensores separados por coma (ej: bmp580,ds18b20)
    --driver <driver>   Driver a usar (default: esphome)
    -h, --help          Muestra esta ayuda

Ejemplos:
    astra node create sensor01 --board esp32dev --sensors bmp580,ds18b20
    astra node create temp01 --board esp32dev --sensors ds18b20
EOF
}

# Parsear argumentos
NODE_ID=""
BOARD=""
SENSORS=""
DRIVER="esphome"  # default

while [ $# -gt 0 ]; do
    case "$1" in
        --board)
            BOARD="$2"
            shift 2
            ;;
        --sensors)
            SENSORS="$2"
            shift 2
            ;;
        --driver)
            DRIVER="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            die "Opción desconocida: $1"
            ;;
        *)
            if [ -z "$NODE_ID" ]; then
                NODE_ID="$1"
            else
                die "Argumento inesperado: $1"
            fi
            shift
            ;;
    esac
done

# Validaciones
if [ -z "$NODE_ID" ]; then
    die "Falta <id> del nodo. Uso: astra node create <id> --board <board> --sensors <list>"
fi

if [ -z "$BOARD" ]; then
    die "Falta --board. Ejemplo: --board esp32dev"
fi

if [ -z "$SENSORS" ]; then
    die "Falta --sensors. Ejemplo: --sensors bmp580,ds18b20"
fi

# Validar driver
if [ "$DRIVER" != "esphome" ]; then
    die "Driver '$DRIVER' no soportado. Solo 'esphome' disponible."
fi

# Verificar workspace (DEV: directorio actual)
workspace_require
load_workspace

# Verificar dependencias
check_docker
check_yq

# Verificar driver ESPHome existe
DRIVER_DIR="$ASTRA_HOME/drivers/$DRIVER"
if [ ! -d "$DRIVER_DIR" ]; then
    die "Driver '$DRIVER' no encontrado en $DRIVER_DIR"
fi

# Verificar sensores soportados
SUPPORTED_SENSORS=$("$DRIVER_DIR/driver.sh" list-sensors --raw 2>/dev/null | tr '\n' ',' | sed 's/,$//')
IFS=',' read -ra SENSOR_ARRAY <<< "$SENSORS"
for SENSOR in "${SENSOR_ARRAY[@]}"; do
    SENSOR=$(echo "$SENSOR" | xargs)
    if ! echo "$SUPPORTED_SENSORS" | grep -q "$SENSOR"; then
        die "Sensor '$SENSOR' no soportado por driver '$DRIVER'. Soportados: $SUPPORTED_SENSORS"
    fi
done

# Validar board básico (lista blanca simple)
VALID_BOARDS="esp32dev esp32-c3-devkitm-1 esp32-s2-saola-1 esp32-s3-devkitc-1"
if ! echo "$VALID_BOARDS" | grep -qw "$BOARD"; then
    # Detectar boards ESP8266 comunes que son incompatibles con template ESP32
    case "$BOARD" in
        esp01|esp01_1m|esp01_2m|esp01_4m|esp8266|d1_mini|d1_mini_lite|d1_mini_pro|nodemcu|nodemcuv2|wemos_d1_mini|wemos_d1_mini_lite|wemos_d1_mini_pro)
            die "Board '$BOARD' es un dispositivo ESP8266, pero el driver ESPHome actual usa template ESP32.
Boards ESP32 soportados: $VALID_BOARDS
Para usar ESP8266, se requiere un driver/template específico (no implementado aún)."
            ;;
        *)
            die "Board '$BOARD' no válido. Boards ESP32 soportados por ASTRA: $VALID_BOARDS"
            ;;
    esac
fi

# Crear directorio del nodo
NODE_DIR="$WORKSPACE/nodes/$NODE_ID"
if [ -d "$NODE_DIR" ]; then
    die "El nodo '$NODE_ID' ya existe en $NODE_DIR"
fi

mkdir -p "$NODE_DIR"

# Generar node.yaml
FRIENDLY_NAME=$(echo "$NODE_ID" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')

cat > "$NODE_DIR/node.yaml" <<EOF
id: $NODE_ID
friendly_name: "$FRIENDLY_NAME"
driver: $DRIVER
board: $BOARD
sensors:
EOF

IFS=',' read -ra SENSOR_ARRAY <<< "$SENSORS"
for SENSOR in "${SENSOR_ARRAY[@]}"; do
    SENSOR=$(echo "$SENSOR" | xargs)
    echo "  - $SENSOR" >> "$NODE_DIR/node.yaml"
done

ok "node.yaml creado: $NODE_DIR/node.yaml"

# Invocar driver para generar firmware.yaml
info "Generando firmware con driver ESPHome..."
"$DRIVER_DIR/driver.sh" render "$NODE_ID"

# Validar configuración con esphome config (dry-run)
info "Validando configuración ESPHome..."
docker run --rm \
    -v "$NODE_DIR":/config \
    esphome/esphome \
    config firmware.yaml >/dev/null

ok "Configuración ESPHome válida"

success "Nodo '$NODE_ID' creado exitosamente.
  node.yaml: $NODE_DIR/node.yaml
  firmware.yaml: $NODE_DIR/firmware.yaml
  driver: $DRIVER
  board: $BOARD
  sensors: $SENSORS"