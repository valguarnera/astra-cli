# ASTRA CLI

ASTRA CLI es el punto de entrada al ecosistema ASTRA.

Desde una única herramienta es posible instalar, crear, administrar y desplegar proyectos y nodos, manteniendo una separación clara entre la herramienta (CLI), el proyecto (Workspace) y la infraestructura (Nodos).

```
      ★ ASTRA CLI

Un CLI
Un Workspace.
Infinitos nodos.
```

---

## Instalación

Primero clonamos el repositorio y nos posicionamos dentro

```bash
git clone https://github.com/rody7val/astra-cli

cd astra-cli
```

Ejecutamos el instalador

```bash
sudo ./install.sh
```

O en modo desarrollo (symlink al repo actual):

```bash
sudo ./install.sh --dev
```

Verificamos la instalación

```bash
astra --version
```

Verificamos solo dependencias (sin instalar ASTRA):

```bash
./install.sh --check-only
```

## Desinstalar correctamente

```bash
sudo ./uninstall.sh
```

---

## Estado del proyecto

**ASTRA CLI 0.1.0**

| Componente | Estado | Detalle |
|------------|--------|---------|
| `astra init` | ✅ | Crea workspace completo con configuración, secrets, docker-compose, mosquitto.conf |
| Workspace discovery | ✅ | DEV: implícito por directorio actual; PROD: explícito por nombre/ruta (planeado) |
| Secrets (`!secret`) | ✅ | Resolución automática desde `secrets.yaml` |
| Docker Compose | ✅ | Generado y gestionado por workspace |
| Mosquitto config | ✅ | Incluido en `docker/mosquitto/config/mosquitto.conf` |
| `astra broker up` | ✅ | Levanta broker MQTT en Docker |
| `astra broker state` | ✅ | Muestra estado del contenedor |
| `astra broker down` | ✅ | Detiene y limpia broker |
| `astra node list` | ✅ | Stub funcional |
| `astra node create` | ✅ | Crea nodo con driver ESPHome, genera firmware.yaml, valida con `esphome config` |
| `astra node delete` | ✅ | Stub funcional |
| `astra flash usb` | ✅ | Flashea ESP32 por USB: regenera firmware, valida, auto-detecta puerto, `esphome run` |
| `astra logs usb` | ✅ | Logs seriales por USB: auto-detecta puerto, `esphome logs --follow` |
| Help / Version | ✅ | `astra --help`, `astra --version` |
| Tests | 46/46 ✅ | Workspace, router, secrets, install, node create, driver, flash, logs |

**En desarrollo (próximos vertical slices):**
- OTA flash, múltiples drivers, ADP, Discovery, SDK

---

## ¿Cómo usar ASTRA CLI?

El comando `astra --help` muestra los casos de uso. Devuelve una estructura clara:

```bash
ASTRA CLI

Uso:

    astra init

    astra broker up
    astra broker down
    astra broker state

    astra node create
    astra node list
    astra node delete

    astra flash usb <node>
    astra flash ota <node>

    astra logs usb <node>
    astra logs ota <node>

Opciones

    -h, --help
    -v, --version
```

---

## Flujo de trabajo típico (Vertical Slice actual)

```bash
# 1. Crear workspace
astra init mi-estacion
#   → Prompts: WiFi SSID, Password, MQTT Host
#   → Crea: astra.yaml, secrets.yaml, .gitignore, nodes/, docker/, docker-compose.yml

# 2. Crear nodo con driver ESPHome
astra node create sensor01 --board esp32dev --sensors bmp580,ds18b20
#   → Valida dependencias (Docker, yq, ESPHome image)
#   → Crea: nodes/sensor01/node.yaml + firmware.yaml
#   → Valida firmware con `esphome config` (dry-run)

# 3. Levantar broker MQTT
astra broker up

# 4. Flashear ESP32 por USB
astra flash usb sensor01
#   → Regenera firmware.yaml desde node.yaml
#   → Valida configuración con esphome config
#   → Auto-detecta puerto USB (/dev/ttyUSB*, /dev/ttyACM*)
#   → Compila y flashea con esphome run

# 5. Ver logs en tiempo real
astra logs usb sensor01
#   → Auto-detecta puerto USB
#   → Conecta con esphome logs --follow
#   → Ctrl+C para salir
```

---

## Estructura del Workspace

```
~/apps/mi-estacion/              ← workspace root
├── astra.yaml                   ← configuración del proyecto (name, mqtt, wifi con !secret)
├── secrets.yaml                 ← valores reales (gitignored)
├── .gitignore                   ← ignora secrets.yaml, firmware.yaml, build/, .temp/
├── nodes/                       ← directorio de nodos
│   └── sensor01/                ← un directorio por nodo
│       ├── node.yaml            ← declaración del nodo (source of truth)
│       └── firmware.yaml        ← generado por driver (build artifact, gitignored)
└── docker/                      ← infraestructura local del proyecto
    ├── docker-compose.yml       ← mosquitto
    └── mosquitto/
        ├── config/
        │   └── mosquitto.conf   ← configuración Mosquitto
        ├── data/
        └── log/
```

### Qué representa cada parte

| Archivo/Directorio | Propósito |
|--------------------|-----------|
| `astra.yaml` | Configuración del proyecto: nombre, MQTT host, WiFi (referencian secrets) |
| `secrets.yaml` | Valores reales de secrets (WiFi SSID/password, MQTT host) — **no commitear** |
| `nodes/<id>/node.yaml` | Declaración del nodo: id, friendly_name, driver, board, sensors[] |
| `nodes/<id>/firmware.yaml` | Generado por el driver; YAML completo de ESPHome listo para compilar/flashear |
| `docker/docker-compose.yml` | Define servicios locales (broker MQTT) |
| `docker/mosquitto/config/mosquitto.conf` | Configuración del broker (puertos 1883/9001, websockets, anonymous) |

---

## Workspace: DEV vs PROD

### DEV (modo desarrollo)
- Workspace **implícito** mediante el directorio actual
- Se detecta automáticamente buscando `astra.yaml` hacia arriba desde `$PWD`
- Útil durante desarrollo de ASTRA CLI mismo (`install.sh --dev`)

```bash
~/apps/nodo02
    └── astra broker up          # funciona: encuentra workspace en ~/apps/nodo02

~/apps
    └── astra broker up          # falla: no hay workspace en ~/apps
```

### PROD (modo producción)
- Workspace **explícito** mediante nombre/ruta registrada
- Arquitectura prevista: registro de workspaces en `~/.config/astra/workspaces.yaml`
- Por ahora: mismo comportamiento DEV (workspace por directorio actual)

---

## Driver ESPHome

El primer driver implementado, ubicado en `$ASTRA_HOME/drivers/esphome/`:

```
drivers/esphome/
├── template.yaml          # Template base ESPHome (placeholders: {{NODE_ID}}, {{BOARD}}, etc.)
├── sensors/
│   ├── bmp580.yaml        # Fragmento I2C: bmp581_i2c (addr 0x47, pines 21/22)
│   └── ds18b20.yaml       # Fragmento 1-Wire: dallas_temp (GPIO 4, auto-descubre address)
└── driver.sh              # Subcomandos: render, list-sensors, validate
```

### Subcomandos del driver

```bash
# Lista sensores soportados
$ASTRA_HOME/drivers/esphome/driver.sh list-sensors [--raw]

# Genera firmware.yaml desde node.yaml + astra.yaml + secrets.yaml
$ASTRA_HOME/drivers/esphome/driver.sh render <node_id>

# Valida configuración con esphome config (dry-run)
$ASTRA_HOME/drivers/esphome/driver.sh validate <node_id>
```

### Sensores soportados

| Sensor | Plataforma ESPHome | Configuración por defecto |
|--------|-------------------|---------------------------|
| `bmp580` | `bmp581_i2c` | I2C addr 0x47, SDA 21, SCL 22, oversampling 16x, IIR 4x |
| `ds18b20` | `dallas_temp` | 1-Wire GPIO 4, resolution 12, auto-descubre address |

---

## Flash USB

Comando para flashear un nodo ESP32 conectado por USB:

```bash
astra flash usb <node> [--port <port>]
```

### Flujo

1. **Workspace & Node**: Valida workspace y que el nodo existe
2. **Regenera firmware**: `driver.sh render` desde `node.yaml` + `astra.yaml` + `secrets.yaml`
3. **Valida config**: `esphome config` (dry-run)
4. **Detecta puerto**: Busca `/dev/ttyUSB*` y `/dev/ttyACM*`
5. **Flashea**: `docker run --privileged --device=<port> esphome/esphome run firmware.yaml`

### Opciones

| Opción | Descripción |
|--------|-------------|
| `<node>` | ID del nodo (ej: `sensor01`) |
| `--port <port>` | Puerto serial explícito (ej: `/dev/ttyUSB1`) |

### Comportamiento de detección USB

| Puertos detectados | Comportamiento |
|-------------------|----------------|
| 0 | Error: "Conecte el ESP32 por USB" |
| 1 | Auto-selecciona e informa |
| Múltiples | Error: "Use --port para especificar" |

### Override manual

```bash
astra flash usb sensor01 --port /dev/ttyUSB1
```

El puerto explícito tiene prioridad sobre la autodetección.

### Permisos

Si el puerto existe pero no hay permisos:

```text
✗ Sin permisos para acceder a /dev/ttyUSB0
Ejecute: sudo usermod -aG dialout $USER y reinicie sesión.
```

---

## Logs USB

Comando para ver logs seriales de un nodo ESP32:

```bash
astra logs usb <node> [--port <port>] [--follow] [--lines <n>] [--no-follow]
```

### Flujo

1. **Workspace & Node**: Valida workspace y que el nodo existe
2. **Detecta puerto**: Igual que flash (autodetección o `--port`)
3. **Logs**: `docker run -it --device=<port> esphome/esphome logs firmware.yaml [--follow]`

### Opciones

| Opción | Descripción |
|--------|-------------|
| `<node>` | ID del nodo |
| `--port <port>` | Puerto serial explícito |
| `--follow`, `-f` | Seguir logs continuamente (default) |
| `--lines`, `-n <n>` | Número de líneas a mostrar |
| `--no-follow` | Mostrar últimas líneas y salir |

### Ejemplos

```bash
astra logs usb sensor01                    # Follow mode (default)
astra logs usb sensor01 --follow           # Explícito follow
astra logs usb sensor01 --no-follow        # Últimas líneas y salir
astra logs usb sensor01 --lines 50         # Últimas 50 líneas
astra logs usb sensor01 --port /dev/ttyUSB1 --follow  # Puerto explícito
```

### Salida

```text
$ astra logs usb sensor01

• Workspace: mi-estacion
• Nodo: sensor01
• USB: /dev/ttyUSB0
• Conectando...

[07:21:03] ...
[07:21:04] WiFi connected
[07:21:05] MQTT connected
[07:21:06] BMP581 Temperature: 23.4°C
[07:21:06] BMP581 Pressure: 1013.2 hPa
[07:21:06] DS18B20 Temperature: 22.1°C
```

### Detener

Presione `Ctrl+C` para salir limpiamente. No deja procesos Docker huérfanos.

---

## Sistema de dependencias (install.sh)

El instalador verifica e instala automáticamente las dependencias requeridas:

```text
Docker
    ├── instalado → ✅ next
    └── no instalado → install_docker() → verify_docker() → next

yq (mikefarah/yq v4.x)
    ├── instalado → ✅ next
    └── no instalado → install_yq() (binary) → verify_yq() → next

ESPHome image
    ├── disponible → ✅ next
    └── no disponible → docker pull esphome/esphome → verify_esphome() → next
```

**No reinstala dependencias existentes.** Si ya están presentes, solo verifica.

Modos:
```bash
sudo ./install.sh           # Producción: copia archivos a /opt/astra
sudo ./install.sh --dev     # Desarrollo: symlink /opt/astra → repo actual
sudo ./install.sh --check-only  # Solo verifica dependencias
```

---

## Tests

Ejecutar suite de tests:

```bash
cd tests
./run_tests.sh
```

**Baseline actual: 46 tests pasan, 5 skipped (requieren sudo / docker permissions)**

Categorías:
- Workspace: find, load, secrets resolution, paths
- Router: dispatch, help, version, invalid commands
- Secrets: existing, missing file, missing key, no-tag
- Install: ASTRA_HOME resolution, launcher creation, dev/prod mode
- Node create: no workspace, missing args, invalid sensor, duplicate, driver render
- Driver: list-sensors, render, dependency checks
- Flash: no workspace, missing node, multiple nodes, auto-select, explicit port
- Logs: no workspace, missing node, multiple nodes, auto-select, explicit port

---

## Licencia

APACHE V2.0