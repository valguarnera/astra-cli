# DISEÑO VERTICAL SLICE V1 - ASTRA CLI

---

## 1. Objetivo del MVP

Construir el **mínimo sistema real end-to-end** que permita:

```
astra init mi-estacion
astra node create estacion01 --driver esphome --board esp32dev --sensors bmp580,ds18b20
astra broker up
astra flash usb estacion01
astra logs usb estacion01
```

Y obtener **lecturas reales** de:
- **BMP580**: temperatura, presión atmosférica
- **DS18B20**: temperatura (1-Wire)

**Fuera de alcance explícito para este MVP:**
- ADP, Discovery, Node Announcement, Request IDs
- SDK, Device Registry, Capability Registry
- Station management complejo
- OTA flash (solo USB)
- Múltiples drivers (solo ESPHome)
- Arquitecturas distribuidas

---

## 2. Modelo conceptual mínimo

```
┌─────────────────────────────────────────────────────────────┐
│                        WORKSPACE                            │
│  astra.yaml          ← configuración proyecto (mqtt, wifi)  │
│  secrets.yaml        ← valores reales (gitignored)          │
│  nodes/                                                        │
│  └── estacion01/                                              │
│       ├── node.yaml    ← intención declarativa del nodo     │
│       └── firmware.yaml← generado por driver (build artifact)│
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      DRIVER ESPHOME                         │
│  $ASTRA_HOME/drivers/esphome/                                │
│  ├── template.yaml      ← base ESPHome                      │
│  ├── sensors/                                                     │
│  │   ├── bmp580.yaml    ← fragmento sensor I2C (bmp581_i2c) │
│  │   └── ds18b20.yaml   ← fragmento sensor 1-Wire (dallas_temp) │
│  └── driver.sh          ← lógica: render(template + fragments)│
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        HARDWARE                             │
│  ESP32 + BMP580 (I2C) + DS18B20 (1-Wire)                   │
└─────────────────────────────────────────────────────────────┘
```

**Principios rectores:**
- Workspace = intención del usuario + artefactos generados (local)
- Driver = lógica de generación de firmware (en ASTRA_HOME, versionado con CLI)
- Node = unidad de despliegue física (1 MCU = 1 node.yaml)
- Core = orquestación, no conoce GPIO/I2C/sensores específicos

---

## 3. Definición de Node

### Para este MVP:

> **Node = Un dispositivo físico programable único (1 MCU = 1 node)**

**Justificación:**
- Un ESP32 = un node.yaml
- Los sensores son **componentes declarados dentro del nodo**, no nodos separados
- Evita complejidad de "sub-nodos" o "componentes" como entidades independientes
- Mapea 1:1 con `esphome: name:` y flasheo unitario

---

## 4. Estructura propuesta del Workspace

```
mi-estacion/                    ← workspace root
├── astra.yaml                  ← configuración proyecto
├── secrets.yaml                ← secretos (gitignored)
├── .gitignore
├── nodes/                      ← directorio de nodos
│   └── estacion01/             ← un directorio por nodo
│       ├── node.yaml           ← declaración del nodo (source of truth)
│       └── firmware.yaml       ← generado por driver (build artifact, gitignored)
└── docker/                     ← infraestructura local
    └── docker-compose.yml      ← mosquitto, etc.
```

### astra.yaml (mínimo)
```yaml
name: mi-estacion
version: 1

mqtt:
  host: !secret mqtt_host
  port: 1883

wifi:
  ssid: !secret wifi_ssid
  password: !secret wifi_password
```

### secrets.yaml (mínimo)
```yaml
wifi_ssid: "MiWiFi"
wifi_password: "password123"
mqtt_host: "localhost"
```

### .gitignore
```
secrets.yaml
nodes/*/firmware.yaml
docker/mosquitto/
build/
.temp/
```

### docker/docker-compose.yml
```yaml
services:
  mosquitto:
    image: eclipse-mosquitto:2
    ports:
      - "1883:1883"
      - "9001:9001"
    volumes:
      - ./mosquitto:/mosquitto
```

**Decisiones de diseño:**
- `firmware.yaml` en `nodes/<id>/` → co-localizado con su node.yaml
- `docker/` en workspace (no en ASTRA_HOME) → cada proyecto tiene su broker
- `firmware.yaml` en .gitignore → artefacto generado, no fuente

---

## 5. Formato propuesto de node.yaml

```yaml
# nodes/estacion01/node.yaml
id: estacion01
friendly_name: "Estación 01"
driver: esphome
board: esp32dev
sensors:
  - bmp580
  - ds18b20
```

### Campos obligatorios:
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | string | Identificador único (directorio, hostname, topic MQTT base) |
| `friendly_name` | string | Nombre legible para ESPHome `friendly_name` |
| `driver` | string | Driver a usar (`esphome` por ahora) |
| `board` | string | Board ESPHome (`esp32dev`, `esp32-c3-devkitm-1`, etc.) |
| `sensors` | list[string] | Lista de IDs de sensores soportados por el driver |

**Principio:** Mínimo viable. Si el driver necesita más config, la lee de `astra.yaml`/`secrets.yaml` o usa defaults.

---

## 6. Diseño del Driver ESPHome

### Arquitectura del driver

```
$ASTRA_HOME/drivers/esphome/
├── template.yaml          # Template base ESPHome
├── sensors/
│   ├── bmp580.yaml        # Fragmento: i2c + sensor bmp581_i2c
│   └── ds18b20.yaml       # Fragmento: one_wire + sensor dallas_temp
└── driver.sh              # Script: render(template + fragments) → firmware.yaml
```

### 6.1 template.yaml (base)

```yaml
# $ASTRA_HOME/drivers/esphome/template.yaml
esphome:
  name: {{NODE_ID}}
  friendly_name: {{NODE_FRIENDLY_NAME}}

esp32:
  board: {{BOARD}}

wifi:
  ssid: !secret wifi_ssid
  password: !secret wifi_password
  power_save_mode: none
  reboot_timeout: 0s

mqtt:
  broker: "{{MQTT_HOST}}"
  port: 1883
  username: ""
  password: ""
  discovery: true
  discovery_prefix: "homeassistant"
  topic_prefix: "astra/{{NODE_ID}}"

logger:
  level: DEBUG
  baud_rate: 115200

api:
  encryption: ""
  port: 6053

ota:
  - platform: esphome

web_server:
  port: 80

# --- INCLUDE POINT: Sensors injected here ---
{{SENSORS_CONFIG}}
```

### 6.2 Sensor fragments (validados contra ESPHome 2026.8.2)

**bmp580.yaml:**
```yaml
# $ASTRA_HOME/drivers/esphome/sensors/bmp580.yaml
i2c:
  sda: 21
  scl: 22
  scan: true
  id: bus_a

sensor:
  - platform: bmp581_i2c
    address: 0x47
    temperature:
      name: "{{NODE_FRIENDLY_NAME}} Temperatura BMP580"
      oversampling: 16x
    pressure:
      name: "{{NODE_FRIENDLY_NAME}} Presión"
      oversampling: 16x
    iir_filter: 4x
    update_interval: 30s
```

**ds18b20.yaml:**
```yaml
# $ASTRA_HOME/drivers/esphome/sensors/ds18b20.yaml
one_wire:
  - platform: gpio
    pin: 4

sensor:
  - platform: dallas_temp
    name: "{{NODE_FRIENDLY_NAME}} Temperatura DS18B20"
    resolution: 12
    update_interval: 30s
```

**Notas importantes:**
- **BMP580**: Usa `bmp581_i2c` (plataforma que soporta BMP580/BMP581/BMP585). Address default `0x47`. Oversampling `16x` para presión (default ESPHome), `NONE` para temperatura. IIR filter `4x`.
- **DS18B20**: Usa `dallas_temp` (reemplaza `dallas` deprecated). Requiere `one_wire` con `platform: gpio`. **NO se especifica address** → ESPHome auto-descubre dispositivos en el bus 1-Wire. Resolution `12` (default).

### 6.3 driver.sh (lógica de renderizado - SIN template engine general)

```bash
#!/usr/bin/env bash
# $ASTRA_HOME/drivers/esphome/driver.sh

set -e

COMMAND="$1"
NODE_ID="$2"

# Cargar contexto del workspace
source "$ASTRA_HOME/lib/workspace.sh"
workspace_require
load_workspace

# Cargar node.yaml
NODE_DIR="$WORKSPACE/nodes/$NODE_ID"
NODE_YAML="$NODE_DIR/node.yaml"

if [ ! -f "$NODE_YAML" ]; then
    die "Node $NODE_ID no encontrado en $NODE_DIR"
fi

# Parsear node.yaml (usar yq)
NODE_FRIENDLY_NAME=$(yq '.friendly_name' "$NODE_YAML")
BOARD=$(yq '.board' "$NODE_YAML")
SENSORS=$(yq '.sensors | join(",")' "$NODE_YAML")

# Generar SENSORS_CONFIG concatenando fragments
SENSORS_CONFIG=""
IFS=',' read -ra SENSOR_ARRAY <<< "$SENSORS"
for SENSOR in "${SENSOR_ARRAY[@]}"; do
    FRAGMENT="$ASTRA_HOME/drivers/esphome/sensors/${SENSOR}.yaml"
    if [ -f "$FRAGMENT" ]; then
        # Procesar variables en fragment antes de concatenar
        FRAGMENT_CONTENT=$(cat "$FRAGMENT")
        FRAGMENT_CONTENT="${FRAGMENT_CONTENT//\{\{NODE_FRIENDLY_NAME\}\}/$NODE_FRIENDLY_NAME}"
        SENSORS_CONFIG="${SENSORS_CONFIG}${FRAGMENT_CONTENT}\n"
    else
        warn "Sensor fragment no encontrado: $SENSOR"
    fi
done

# Renderizar template.yaml directamente en driver.sh (sin template engine general)
TEMPLATE="$ASTRA_HOME/drivers/esphome/template.yaml"
OUTPUT="$NODE_DIR/firmware.yaml"

# Leer template y reemplazar placeholders
cat "$TEMPLATE" | \
    sed "s/{{NODE_ID}}/$NODE_ID/g" | \
    sed "s/{{NODE_FRIENDLY_NAME}}/$NODE_FRIENDLY_NAME/g" | \
    sed "s/{{BOARD}}/$BOARD/g" | \
    sed "s|{{MQTT_HOST}}|$MQTT_HOST|g" | \
    sed "s/{{SENSORS_CONFIG}}/$SENSORS_CONFIG/g" \
    > "$OUTPUT"

ok "Firmware generado: $OUTPUT"
```

**Decisión:** No extender `lib/template.sh`. El reemplazo simple con `sed` en `driver.sh` es suficiente para los 5 placeholders. Evita complejidad de escaping newlines.

### 6.4 Variables disponibles en templates/fragments

| Variable | Origen | Ejemplo |
|----------|--------|---------|
| `{{NODE_ID}}` | node.yaml:id | `estacion01` |
| `{{NODE_FRIENDLY_NAME}}` | node.yaml:friendly_name | `Estación 01` |
| `{{BOARD}}` | node.yaml:board | `esp32dev` |
| `{{MQTT_HOST}}` | astra.yaml:mqtt.host (resuelto) | `192.168.1.50` |
| `{{SENSORS_CONFIG}}` | driver.sh (concat fragments procesados) | multilínea YAML |

---

## 7. Integración de sensores

### Principio: Core no conoce sensores

```
┌────────────────────────────────────────────────────────────┐
│  CORE (astra CLI)                                          │
│  - Sabe: node.yaml tiene campo "sensors: [list]"           │
│  - No sabe: qué es bmp580, pines I2C, direcciones          │
└────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────┐
│  DRIVER ESPHome                                            │
│  - Sabe: mapear "bmp580" → fragment YAML con bmp581_i2c    │
│  - Sabe: mapear "ds18b20" → fragment YAML con dallas_temp  │
│  - Encapsula: GPIO, direcciones, oversampling, etc.        │
└────────────────────────────────────────────────────────────┘
```

### Decisión para MVP: **Fragments en driver (Opción A)**

- Core permanece ajeno a sensores
- Driver encapsula conocimiento ESPHome-específico
- Fácil agregar sensores: nuevo archivo en `drivers/esphome/sensors/`
- `node.yaml` sigue limpio: `sensors: [bmp580, ds18b20]`

### Hardware-specific configs (defaults en fragments, confirmar con hardware real)

| Sensor | Config en fragment | Pendiente de hardware |
|--------|-------------------|----------------------|
| BMP580 | `address: 0x47`, `sda: 21`, `scl: 22` | Dirección I2C real (0x46/0x47), pines |
| DS18B20 | `pin: 4` (GPIO para 1-Wire) | GPIO real |

---

## 8. Flujo de comandos

### 8.1 `astra init mi-estacion`

```
1. Prompts: WiFi SSID, WiFi Password, MQTT Host
2. Crea: astra.yaml, secrets.yaml, .gitignore
3. Crea dirs: nodes/, docker/
4. Crea: docker/docker-compose.yml (NUEVO)
```

### 8.2 `astra node create estacion01 --driver esphome --board esp32dev --sensors bmp580,ds18b20`

```
1. Parsear flags: --driver, --board, --sensors
2. Validar driver existe en $ASTRA_HOME/drivers/<driver>/
3. Validar board conocido (lista blanca básica)
4. Validar sensors existen en driver (listar fragments disponibles)
5. Crear directorio: $WORKSPACE/nodes/estacion01/
6. Escribir node.yaml con campos parseados
7. Invocar driver render: $ASTRA_HOME/drivers/esphome/driver.sh render estacion01
8. driver.sh genera: $WORKSPACE/nodes/estacion01/firmware.yaml
9. ok "Nodo estacion01 creado. Firmware generado."
```

### 8.3 `astra broker up`

```
1. workspace_require() → encuentra astra.yaml
2. cd $WORKSPACE/docker
3. docker compose up -d mosquitto
4. ok "Broker MQTT iniciado"
```

### 8.4 `astra flash usb estacion01` (flujo completo con regeneración)

```
1. workspace_require() + load_workspace()
2. Validar node existe: $WORKSPACE/nodes/estacion01/
3. REGENERAR firmware.yaml desde node.yaml:
   → invocar $ASTRA_HOME/drivers/esphome/driver.sh render estacion01
4. Validar configuración ESPHome:
   → docker run --rm -v "$WORKSPACE/nodes/estacion01":/config esphome/esphome config firmware.yaml
5. Auto-detectar puerto serie:
   - Buscar /dev/ttyUSB*, /dev/ttyACM*
   - Permitir --port /dev/ttyUSB0 override
6. Compilar y flashear:
   → docker run --rm --device=<detected_port> -v "$WORKSPACE/nodes/estacion01":/config esphome/esphome run firmware.yaml
7. ok "Flasheo completado"
```

### 8.5 `astra logs usb estacion01`

```
1. workspace_require() + load_workspace()
2. Validar node existe
3. Auto-detectar puerto (igual que flash)
4. Opciones: --follow / -f (default), --lines N
5. Ejecutar: picocom -b 115200 <port> (o screen/minicom)
6. Ctrl+C para salir
```

---

## 9. Decisiones pendientes de hardware

### 9.1 Decisiones arquitectónicas (TOMAR AHORA)

| Decisión | Valor propuesto | Justificación |
|----------|----------------|---------------|
| Node = 1 MCU | Sí | Simplicidad, mapea 1:1 con flasheo |
| Sensores en node.yaml | Lista simple `sensors: [bmp580, ds18b20]` | Mínimo, extensible |
| Driver fragments | Archivos YAML en `drivers/esphome/sensors/` | Declarativo, sin acoplar core |
| Firmware location | `nodes/<id>/firmware.yaml` | Co-localizado, gitignored |
| Broker | docker-compose en workspace/docker | Aislado por proyecto |
| Template rendering | sed en driver.sh (5 placeholders) | Simple, sin engine general |
| Secret resolution | load_workspace() resuelve !secret → pasa valores a driver | Suficiente para firmware |

### 9.2 Configuraciones de hardware (CONFIRMAR DESPUÉS)

| Parámetro | Dónde se define | Valor por defecto propuesto | Cómo confirmar |
|-----------|-----------------|----------------------------|----------------|
| **ESP32 board** | node.yaml:board | `esp32dev` | `esphome boards` o datasheet |
| **BMP580 I2C address** | drivers/esphome/sensors/bmp580.yaml | `0x47` | `i2cdetect -y 1` en ESP32 |
| **BMP580 SDA pin** | drivers/esphome/sensors/bmp580.yaml | `21` | Esquemático hardware |
| **BMP580 SCL pin** | drivers/esphome/sensors/bmp580.yaml | `22` | Esquemático hardware |
| **DS18B20 GPIO pin** | drivers/esphome/sensors/ds18b20.yaml | `4` | Esquemático hardware |
| **DS18B20 address** | Auto-descubrir (no especificar) | N/A | ESPHome auto-scan |
| **Puerto serie USB** | Auto-detect en flash/logs | `/dev/ttyUSB0` o `/dev/ttyACM0` | `ls /dev/tty*` con device |
| **Baud rate** | template.yaml:logger | `115200` | Estándar ESP32 |

---

## 10. Plan de implementación por pasos

### Fase 0: Base (1-2h) - Prerequisitos
- [ ] Fix `success()` exit code en `lib/core/ui.sh:20` (exit 0 no 1)
- [ ] Agregar check `yq` en `lib/core/checks.sh`
- [ ] Implementar resolutor `!secret` simple en `lib/workspace.sh:load_workspace()`
- [ ] Crear `docker/docker-compose.yml` generado por `astra init`
- [ ] Ajustar `commands/broker/*.sh` para usar `$WORKSPACE/docker/docker-compose.yml`

### Fase 1: Node Create (2-3h)
- [ ] Implementar `commands/node/add.sh` con flags parsing (--driver, --board, --sensors)
- [ ] Validaciones: driver existe, board válido, sensors existen en driver
- [ ] Crear `nodes/<id>/node.yaml`
- [ ] Invocar `driver.sh render <node_id>`

### Fase 2: Driver ESPHome (3-4h)
- [ ] Crear `drivers/esphome/driver.sh` con lógica render (sed, sin template engine)
- [ ] Crear `drivers/esphome/sensors/bmp580.yaml` (bmp581_i2c, address 0x47, i2c 21/22)
- [ ] Crear `drivers/esphome/sensors/ds18b20.yaml` (dallas_temp, one_wire gpio 4, sin address)
- [ ] Ajustar `template.yaml` con `{{SENSORS_CONFIG}}` placeholder

### Fase 3: Flash USB (2-3h)
- [ ] Reescribir `commands/node/flash/usb.sh` usando workspace + node
- [ ] Regenerar firmware.yaml antes de flashear
- [ ] Validar config ESPHome (`esphome config`)
- [ ] Implementar auto-detección puerto serie
- [ ] Permitir `--port` override
- [ ] Ejecutar `docker run esphome/esphome run firmware.yaml`

### Fase 4: Logs USB (1-2h)
- [ ] Implementar `commands/logs/usb.sh`
- [ ] Reutilizar auto-detección puerto de flash
- [ ] Usar `picocom` o `screen`

### Fase 5: Integración y testing (2-3h)
- [ ] Test completo: init → node create → broker up → flash → logs
- [ ] Verificar lecturas BMP580 + DS18B20 en logs
- [ ] Documentar valores por defecto en fragments
- [ ] Ajustar según hardware real

**Total estimado: 11-17 horas**

---

## 11. Riesgos de sobrearquitectura

| Riesgo | Señal de alerta | Mitigación |
|--------|-----------------|------------|
| **Template engine complejo** | Agregar loops, conditionals, includes | Solo sed en driver.sh para 5 placeholders |
| **Schema node.yaml extenso** | Agregar campos opcionales "por si acaso" | Solo 5 campos obligatorios en MVP |
| **Sensor config en node.yaml** | Querer poner pines/direcciones en node.yaml | Mantener en driver fragments |
| **Abstracción driver genérica** | Crear interfaz `Driver` con `render()`, `flash()`, `logs()` | `driver.sh` con subcomandos `render` basta |
| **Múltiples boards/configs** | Matriz de boards en node.yaml | Un board por nodo, simple |
| **Secret resolution universal** | Resolver `!secret` en cualquier YAML | Solo en `astra.yaml` via `load_workspace()` |
| **Workspace find complejo** | Buscar en múltiples directorios | Un workspace por proyecto, `astra.yaml` marker |

**Regla de oro:** Si no lo necesitamos para flashear el ESP32 con los 2 sensores **hoy**, no se implementa.

---

## 12. Criterios de aceptación

### Funcionales (must pass)

```bash
# 1. Init workspace
astra init test-station
# ✓ Crea astra.yaml, secrets.yaml, .gitignore, nodes/, docker/
# ✓ docker/docker-compose.yml con mosquitto

# 2. Create node
astra node create estacion01 --driver esphome --board esp32dev --sensors bmp580,ds18b20
# ✓ Crea nodes/estacion01/node.yaml
# ✓ Genera nodes/estacion01/firmware.yaml válido ESPHome
# ✓ firmware.yaml incluye config BMP580 (bmp581_i2c I2C) y DS18B20 (dallas_temp 1-Wire)

# 3. Broker up
astra broker up
# ✓ Mosquitto corriendo en docker
# ✓ Puerto 1883 accesible

# 4. Flash USB (ESP32 conectado)
astra flash usb estacion01
# ✓ Regenera firmware.yaml desde node.yaml
# ✓ Valida config ESPHome (esphome config)
# ✓ Detecta puerto automáticamente
# ✓ Compila y flashea firmware.yaml
# ✓ Dispositivo reinicia y conecta a WiFi/MQTT

# 5. Logs USB
astra logs usb estacion01
# ✓ Muestra output serial
# ✓ Se ven lecturas: "Temperatura BMP580: 23.4°C", "Presión: 1013.2 hPa", "Temperatura DS18B20: 22.1°C"
```

### No funcionales

- **Tiempo total flujo init→logs**: < 5 min (excluyendo compile/flash ESPHome)
- **Comandos fallan con mensajes claros** si: no workspace, node no existe, puerto no detectado
- **Sin hardcoded paths** en commands (usan `$WORKSPACE`, `$ASTRA_HOME`)
- **Secrets resueltos** en firmware.yaml (no literales `!secret`)

---

## Apéndice: Archivos a crear/modificar (resumen)

### Nuevos archivos
| Archivo | Propósito |
|---------|-----------|
| `commands/node/add.sh` | Node create con flags |
| `drivers/esphome/driver.sh` | Render template + fragments → firmware.yaml |
| `drivers/esphome/sensors/bmp580.yaml` | Fragment sensor BMP580 (bmp581_i2c) |
| `drivers/esphome/sensors/ds18b20.yaml` | Fragment sensor DS18B20 (dallas_temp + one_wire) |
| `commands/logs/usb.sh` | Logs serial USB |

### Archivos a modificar
| Archivo | Cambio |
|---------|--------|
| `lib/core/ui.sh` | Fix `success()` exit 0 |
| `lib/core/checks.sh` | Agregar check `yq` |
| `lib/workspace.sh` | Implementar resolución `!secret` simple en `load_workspace()` |
| `commands/workspace/init.sh` | Generar `docker/docker-compose.yml` |
| `commands/broker/up.sh` | Usar `$WORKSPACE/docker/docker-compose.yml` |
| `commands/broker/down.sh` | Idem |
| `commands/broker/state.sh` | Idem |
| `commands/node/flash/usb.sh` | Reescribir completo: workspace-aware, regenera firmware, valida, auto-detect port |
| `drivers/esphome/template.yaml` | Agregar `{{SENSORS_CONFIG}}` placeholder |

---

*Diseño v1 - Septiembre 2026 - Aprobado para implementación*
