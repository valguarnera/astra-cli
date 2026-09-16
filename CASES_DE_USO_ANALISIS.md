# ANÁLISIS DE CASOS DE USO - ASTRA CLI
## Fase 5: Entender los flujos reales antes de evolucionar

---

## 1. CASO DE USO: CREAR UNA ESTACIÓN

### Flujo actual (comandos atómicos)

```bash
# 1. Crear workspace (guiado)
astra init mi-estacion
#    → Prompts: WiFi SSID, Password, MQTT Host (auto-detecta IP LAN)

# 2. Crear nodo
astra node create sensor01 --board esp32dev --sensors bmp580,ds18b20
#    → Valida board, sensors, genera firmware.yaml, valida con esphome config

# 3. Levantar broker
astra broker up
#    → docker compose up -d mosquitto en workspace/docker/

# 4. Flashear por USB
astra flash usb sensor01
#    → Regenera firmware, valida, auto-detecta puerto, flashea con esphome run

# 5. Ver logs
astra logs usb sensor01 --follow
#    → Auto-detecta puerto, conecta con esphome logs --follow
```

### Análisis de decisiones que toma el usuario

| Paso | Decisión del usuario | Información que ASTRA ya conoce | Gaps |
|------|---------------------|--------------------------------|------|
| `init` | Nombre workspace | Ninguna (primer paso) | - |
| `init` | WiFi SSID/Password | Ninguna | Credenciales sensibles |
| `init` | MQTT Host | Auto-detecta IP LAN 192.168.* | Fallback a localhost si no hay LAN |
| `node create` | ID del nodo | Workspace actual | - |
| `node create` | Board (ej: esp32dev) | Lista de boards soportados | Usuario debe saber cuál tiene |
| `node create` | Sensores | Lista de sensores soportados por driver | Usuario debe saber qué sensores conectó |
| `flash usb` | Puerto USB | Auto-detecta (fallback: --port) | Falla si múltiples puertos |
| `logs usb` | Puerto USB | Auto-detecta (fallback: --port) | Idem |

### Qué obliga ASTRA a hacer manualmente (pasos que podrían unificarse)

1. **`astra broker up`** - Comando separado obligatorio. El broker es requisito para que el nodo funcione, pero ASTRA no lo levanta automáticamente.
2. **Orden de comandos** - El usuario debe saber el orden correcto: init → node create → broker up → flash → logs
3. **Credenciales WiFi** - Se piden en `init` pero se usan en `node create` (via secrets). No hay validación de que funcionen.
4. **Board/Sensors** - Usuario debe conocer el hardware exacto. No hay auto-detección de "qué board tengo conectado".

### Qué información ASTRA ya conoce y reutiliza

- `astra.yaml` + `secrets.yaml` → WiFi, MQTT, project name
- `node.yaml` → board, sensors, driver
- `firmware.yaml` (generado) → configuración completa ESPHome
- Auto-detección de puerto USB serial

### Errores típicos en este flujo

| Error | Cuándo ocurre | Qué hace ASTRA |
|-------|---------------|----------------|
| MQTT_HOST = localhost | `node create` / `flash` | Rechaza con error explicativo |
| Board no soportado | `node create` | Lista boards válidos |
| Sensor no soportado | `node create` | Lista sensores válidos |
| Múltiples puertos USB | `flash` / `logs` | Pide `--port` explícito |
| Sin permisos dialout | `flash` / `logs` | Instrucción `usermod -aG dialout` |
| ESP no en bootloader | `flash` | Falla `esphome run` (requiere bootloader manual) |

---

## 2. CASO DE USO: INCORPORAR UN NODO

### Modelo actual

```bash
astra node create cultivo01 \
  --board esp01 \
  --sensors bmp580,ds18b20
```

### Análisis del modelo `node`

```yaml
# node.yaml generado
id: cultivo01
friendly_name: "Cultivo 01"
driver: esphome
board: esp01
sensors:
  - bmp580
  - ds18b20
```

### Board ↔ Arquitectura (resolución interna)

| Board solicitado | Arquitectura resuelta | Driver ESPHome |
|------------------|----------------------|----------------|
| `esp32dev`, `esp32-c3-devkitm-1`, etc. | `esp32` | `esphome` (template.yaml) |
| `esp01`, `d1_mini`, `nodemcu`, etc. | `esp8266` | `esphome` (template_esp8266.yaml) |

**Regla actual:** El usuario declara `--board esp01`, ASTRA resuelve `arch: esp8266` internamente. No hay flag `--arch` separado.

### ¿Es suficientemente claro?

**Sí, para usuarios que conocen su hardware.** El mapeo board→arch es conocimiento interno de ASTRA (hardcoded en `node/create.sh`).

**Problema:** Si el usuario tiene un ESP01 pero pone `--board esp32dev`, ASTRA genera firmware para ESP32 que no flasheará correctamente en el ESP01. No hay validación de "el board coincide con el hardware conectado".

### Decisiones que el usuario NO debería tener que tomar

- `--arch` - Resuelto automáticamente desde `--board`
- Template a usar - Resuelto por driver
- Pines I2C/1-Wire - Definidos en fragments del driver (bmp580.yaml, ds18b20.yaml)

---

## 3. CASO DE USO: HARDWARE FÍSICO

### Flujo real de diagnóstico

```bash
# 1. ¿Hay algo conectado?
astra hardware detect
#    → Lista /dev/ttyUSB* y /dev/ttyACM* con vendor/product ID
#    → Marca "ESP compatible" si vendor ID conocido (CP210x, CH340, FTDI)

# 2. ¿Qué adaptador serial es?
astra hardware identify /dev/ttyUSB0
#    → USB-Serial: CH340 (o CP210x, FTDI)
#    → MCU: unknown (o ESP32/ESP8266 si esptool.py responde)
#    → Board: ch340  ← PROBLEMA: confunde adaptador con board

# 3. ¿El ESP responde?
astra hardware check-esp /dev/ttyUSB0
#    → Intenta esptool.py chip_id (requiere bootloader)
#    → Fallback: AT commands (requiere firmware con AT)
#    → Falla si ESP tiene ESPHome corriendo (no responde a AT ni esptool)

# 4. Check completo
astra hardware check
#    → Pipeline: detect ESP → check connectivity → check sensors (si workspace) → check USB storage
```

### Distinción crítica de estados (NO confundir)

```
USB-serial detectado (CH340/CP210x/FTDI en /dev/ttyUSB0)
        ≠
ESP identificado (MCU responde: ESP32 o ESP8266 via esptool.py)
        ≠
Bootloader accesible (ESP en modo download: GPIO0=LOW + RESET)
        ≠
Firmware flasheado (esphome run completado)
        ≠
Firmware ejecutándose (ESP boot → WiFi → MQTT → sensores publicando)
        ≠
Nodo funcionando (datos llegando a broker MQTT)
```

### Problema actual en `hardware identify`

```bash
# Salida actual
USB-Serial: CH340
MCU: unknown
Board: ch340    ← INCORRECTO: CH340 es el adaptador USB-serial, NO la board ESP
```

**Correcto debería ser:**
```
USB-Serial: CH340
MCU: unknown (o ESP32/ESP8266 si identificado)
Board: unknown
Adaptador serial: CH340 (vendor=1a86 product=7523)
```

El adaptador USB-serial ≠ board ESP. El board ESP está *detrás* del adaptador y requiere comunicación directa (esptool.py en bootloader) para identificarse.

### Qué hace `check-esp` realmente

| Condición del ESP | `check-esp` resultado |
|-------------------|----------------------|
| En bootloader (GPIO0=LOW) | ✅ `esptool.py chip_id` funciona |
| Con firmware AT | ✅ AT commands responden |
| Con ESPHome/Arduino custom | ❌ Falla (no responde a AT, esptool falla si no en bootloader) |
| Sin firmware / corrupto | ❌ Falla |

**Conclusión:** `check-esp` verifica **conectividad física + bootloader**, NO "el ESP está funcionando con mi firmware".

---

## 4. CASO DE USO: DIAGNÓSTICO

### Qué quiere saber el usuario realmente

| Pregunta del usuario | Comando ASTRA | Qué responde realmente |
|---------------------|---------------|------------------------|
| ¿Hay hardware conectado? | `hardware detect` | Hay adaptadores USB-serial con IDs conocidos |
| ¿Qué tipo de adaptador? | `hardware identify` | CH340/CP210x/FTDI (adaptador, NO board ESP) |
| ¿El ESP está vivo? | `hardware check-esp` | Responde a esptool.py (bootloader) O AT commands |
| ¿Todo OK para flashear? | `hardware check` | Pipeline completo + sensors + USB storage |

### Gaps en el diagnóstico actual

1. **No hay "identificar board ESP real"** - Requiere poner ESP en bootloader y usar `esptool.py chip_id` manualmente
2. **No hay "verificar firmware flasheado"** - Solo `logs usb` muestra si el firmware corre
3. **`check` mezcla niveles** - USB storage y sensors son orthogonal a "¿puedo flashear?"

---

## 5. FLASH USB Y LOGS USB - REALIDAD

### `astra flash usb <node>`

**Qué hace realmente:**
1. Regenera `firmware.yaml` desde `node.yaml` + `astra.yaml` + `secrets.yaml`
2. Valida con `esphome config` (dry-run)
3. Auto-detecta puerto `/dev/ttyUSB*` o `/dev/ttyACM*`
4. Ejecuta: `docker run --privileged --device=<port> -v <node_dir>:/config esphome/esphome run firmware.yaml`

**Qué requiere del hardware:**
- ESP en **modo bootloader** (GPIO0=LOW al reset) para primer flasheo
- O ESP con **ESPHome previo** (actualización OTA via serial)
- Permisos `dialout` en puerto
- **NO funciona** si ESP tiene firmware ajeno (Arduino, Tasmota, etc.) sin poner en bootloader

**Probado:**
| Escenario | Automático | Manual | Hardware real | Mock |
|-----------|------------|--------|---------------|------|
| Flash ESP virgen (bootloader) | ❌ | ✅ | ✅ | ❌ |
| Flash ESP con ESPHome previo | ✅ | - | ✅ | ❌ |
| Flash ESP con Arduino/Tasmota | ❌ | ✅ (bootloader manual) | ✅ | ❌ |
| Validación config (esphome config) | ✅ | - | ✅ | ✅ |
| Auto-detección puerto | ✅ | - | ✅ | ❌ |

### `astra logs usb <node>`

**Qué hace:**
1. Auto-detecta puerto (misma lógica que flash)
2. `docker run -it --device=<port> -v <node_dir>:/config esphome/esphome logs firmware.yaml --follow`

**Qué muestra:**
- Output serial del ESP (baud 115200)
- Boot messages, WiFi connection, MQTT connection, sensor readings
- **Ctrl+C para salir limpiamente**

**Probado:**
| Escenario | Automático | Hardware real |
|-----------|------------|---------------|
| Logs con ESPHome corriendo | ✅ | ✅ |
| Logs durante boot | ✅ | ✅ |
| Auto-detección puerto | ✅ | ✅ |
| Opciones --follow/--lines | ✅ | ✅ |

### Clasificación de verificación

| Función | AUTOMÁTICO | MANUAL | REQUIERE HARDWARE | MOCK/STUB | NO VERIFICADO |
|---------|------------|--------|-------------------|-----------|---------------|
| Workspace init | ✅ | - | - | - | - |
| Node create + firmware gen | ✅ | - | - | - | - |
| Firmware validation (esphome config) | ✅ | - | - | ✅ | - |
| Broker up/down | ✅ | - | Docker | - | - |
| Flash USB (ESP virgen) | ❌ | ✅ | ✅ | ❌ | - |
| Flash USB (ESPHome previo) | ✅ | - | ✅ | ❌ | - |
| Logs USB | ✅ | - | ✅ | ❌ | - |
| Hardware detect | ✅ | - | ✅ | ❌ | - |
| Hardware identify (adaptador) | ✅ | - | ✅ | ❌ | - |
| Hardware identify (board ESP) | ❌ | ✅ | ✅ | ❌ | - |
| Check-esp (bootloader) | ✅ | - | ✅ | ❌ | - |
| Check-esp (ESPHome corriendo) | ❌ | - | ❌ | ❌ | ✅ |

---

## 6. ERGONOMÍA: CLI TÉCNICA vs FLUJOS GUIADOS

### Comandos técnicos actuales (17)

| Categoría | Comandos | Uso |
|-----------|----------|-----|
| Workspace | `init` | Guiado (prompts) |
| Node | `create`, `list`, `delete` | Técnico (flags) |
| Flash | `usb` | Técnico |
| Logs | `usb` | Técnico |
| Broker | `up`, `down`, `state` | Técnico |
| Hardware | `detect`, `identify`, `check`, `check-esp` | Técnico |
| USB Storage | `list`, `test`, `mount`, `unmount` | Técnico |

### ¿Hay exceso de comandos?

**No.** Los comandos atómicos son necesarios para:
- Automatización/scripts
- Debugging granular
- Usuarios avanzados

### Candidatos a agrupar (simplificación semántica)

| Grupo actual | Propuesta |
|--------------|-----------|
| `hardware detect` + `identify` + `check-esp` | Subcomandos de `hardware check` (que ya hace pipeline) |
| `usb mount` + `unmount` | Eliminar (solo `usb test` los usa internamente) |
| `broker up/down/state` | `broker start/stop/status` (semántica estándar) |
| `flash usb` + `flash ota` | `flash <node> [--method usb\|ota]` |
| `logs usb` + `logs ota` | `logs <node> [--method usb\|ota]` |

### Flujo guiado potencial (NO implementar todavía)

```bash
astra init
    ↓
¿Crear nodo ahora? [S/n]
    ↓
Nombre del nodo:
    ↓
Board (lista): esp32dev, esp01, d1_mini...
    ↓
Sensores (lista): bmp580, ds18b20...
    ↓
¿Levantar broker? [S/n]
    ↓
Generar firmware...
    ↓
¿Conectar hardware y flashear? [S/n]
    ↓
astra flash usb <node> (auto)
    ↓
¿Ver logs? [S/n]
    ↓
astra logs usb <node> --follow
```

**Regla:** Primero claridad en modelo y comandos atómicos. El flujo guiado es una capa *encima*, no un reemplazo.

---

## 7. DOCUMENTACIÓN: README vs DOCS TÉCNICAS

### README.md (actual: 483 líneas) → Objetivo: ~150 líneas

**Debe contener:**
- Qué es ASTRA (1 párrafo)
- Instalación (3 comandos)
- Quick start (flujo principal 5 pasos)
- Tabla de comandos principales
- Estructura workspace (árbol + tabla)
- Sensores soportados (tabla)
- Requisitos
- Licencia

**Debe ELIMINARSE del README:**
- Detalles de detección IP LAN (→ docs/)
- Explicación DEV vs PROD (→ docs/)
- Detalles de flash/logs (→ docs/)
- Matriz de tests (→ docs/)
- Referencias a archivos internos
- Secciones "En desarrollo"

### Documentación técnica (docs/) → Para desarrolladores/usuarios avanzados

| Archivo | Contenido |
|---------|-----------|
| `architecture.md` | Principios, capas, flujo de datos |
| `hardware.md` | Detección, identificación, estados del ESP |
| `drivers.md` | Cómo escribir un driver, fragments, templates |
| `workspace.md` | Estructura, secrets, docker-compose |
| `flash-logs.md` | Detalles de flasheo, bootloader, logs |
| `troubleshooting.md` | Errores comunes y soluciones |
| `roadmap.md` | Qué viene, qué NO viene |

---

## RESUMEN: QUÉ QUEDA POR HACER

### Inmediato (bugs/claridad)
1. ✅ Fix `success()` exit code
2. ✅ Split `checks.sh` por responsabilidades
3. ✅ Eliminar código muerto (ota.sh, project.sh)
4. ✅ Reducir duplicación con `command_base.sh`
5. ✅ Fix test isolation (67/67 PASS)
6. ⬜ Fix `hardware identify` - no confundir adaptador con board ESP
7. ⬜ Documentar claramente estados: USB-serial ≠ ESP identificado ≠ bootloader ≠ firmware ≠ funcionando

### Corto plazo (usabilidad)
8. ⬜ Renombrar `broker up/down/state` → `start/stop/status`
9. ⬜ Agrupar `hardware detect/identify/check-esp` bajo `hardware check`
10. ⬜ Eliminar `usb mount/unmount` (solo `test`)
11. ⬜ Unificar `flash usb` / `logs usb` con flag `--method`

### Documentación
12. ⬜ README reducido a ~150 líneas
13. ⬜ Mover detalles técnicos a docs/
14. ⬜ Crear `troubleshooting.md` con errores comunes

### NO HACER (fuera de alcance)
- ❌ Implementar flujo guiado/wizard
- ❌ OTA, ADP, Discovery, SDK
- ❌ Desktop, API externa
- ❌ Múltiples drivers prematuramente
- ❌ Refactor masivo por "elegancia"

---

**Estado actual:** 67/67 tests PASS. Arquitectura Core/Hardware/Driver separada. Listo para documentar y pulir detalles.