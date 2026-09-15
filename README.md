# ASTRA CLI

CLI para crear, flashear y administrar nodos ESPHome (ESP32/ESP8266) con sensores.

```
      ★ ASTRA CLI

Un CLI
Un Workspace.
Infinitos nodos.
```

## Instalación

```bash
git clone https://github.com/rody7val/astra-cli
cd astra-cli
sudo ./install.sh          # producción
sudo ./install.sh --dev    # desarrollo (symlink)
```

Verificar: `astra --version`

## Flujo rápido

```bash
# 1. Crear proyecto
astra init mi-estacion
#    → Prompts: WiFi, Password, MQTT Host (auto-detecta IP LAN)

# 2. Crear nodo con sensores
astra node create sensor01 --board esp32dev --sensors bmp580,ds18b20

# 3. Levantar broker MQTT
astra broker up

# 4. Flashear ESP32 por USB
astra flash usb sensor01
#    → Auto-detecta puerto, compila y flashea

# 5. Ver logs en tiempo real
astra logs usb sensor01
#    → Ctrl+C para salir
```

## Comandos

| Comando | Descripción |
|---------|-------------|
| `astra init <nombre>` | Crea workspace interactivo |
| `astra node create <id> --board <board> --sensors <lista>` | Crea nodo + firmware |
| `astra node list` | Lista nodos del workspace |
| `astra node delete <id>` | Elimina nodo |
| `astra broker start` | Levanta broker MQTT local |
| `astra broker stop` | Detiene broker |
| `astra broker status` | Estado del broker |
| `astra flash usb <nodo> [--port <puerto>]` | Flashea por USB |
| `astra logs usb <nodo> [--follow] [--lines N] [--port <puerto>]` | Logs seriales |
| `astra hardware check` | Diagnóstico completo (ESP, sensores, USB) |
| `astra hardware info <puerto>` | Identifica dispositivo en puerto |
| `astra usb list` | Lista almacenamiento USB |
| `astra usb test [device]` | Prueba almacenamiento (mount, write, read, verify) |

## Estructura del Workspace

```
mi-estacion/
├── astra.yaml          # Config proyecto (con !secret refs)
├── secrets.yaml        # Valores reales (gitignored)
├── nodes/
│   └── sensor01/
│       ├── node.yaml   # Declaración: id, board, sensors[]
│       └── firmware.yaml # Generado por driver (gitignored)
└── docker/
    └── docker-compose.yml # Mosquitto broker
```

## Sensores soportados (driver ESPHome)

| Sensor | Plataforma | Config por defecto |
|--------|------------|-------------------|
| `bmp580` | `bmp581_i2c` | I2C 0x47, SDA 21, SCL 22 |
| `ds18b20` | `dallas_temp` | 1-Wire GPIO 4, auto-descubre |

## Requisitos

- Linux
- Docker + Docker Compose
- Usuario en grupo `docker` y `dialout`
- yq (mikefarah/yq v4+) - se auto-instala

## Licencia

Apache 2.0