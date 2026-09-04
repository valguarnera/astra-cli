# AUDITORÍA ARQUITECTÓNICA - ASTRA CLI

---

## 1. Resumen ejecutivo

**Astra CLI** es actualmente una **herramienta de línea de comandos escrita en Bash** que se instala globalmente en `/opt/astra` y expone un binario `astra` en `/usr/local/bin/astra`.

Según la evidencia del código, Astra CLI se encuentra en una **fase temprana de desarrollo** (versión 0.1.0). Su funcionalidad real implementada se limita a:

- Instalación/desinstalación del CLI con verificaciones de sistema (Docker, permisos, OS)
- Inicialización de Workspaces (`astra init`)
- Gestión básica del broker MQTT via Docker Compose (`astra broker up/down/state`)
- Plantilla de driver para ESPHome (solo archivo template.yaml)

**No está implementado**: gestión de nodos (create/delete/list), flasheo real integrado con workspace, logs, protocolo ADP, discovery, node announcement, SDK.

---

## 2. Arquitectura actual

### Componentes y responsabilidades

| Componente | Ubicación | Responsabilidad | Estado |
|------------|-----------|-----------------|--------|
| **Entry Point** | `bin/astra` | Configura `ASTRA_HOME`, detecta modo dev/prod, invoca router | Implementado |
| **Router** | `lib/core/router.sh` | Parseo de `COMMAND` y `ACTION`, despacho a scripts de commands | Implementado |
| **Help/Version** | `lib/core/help.sh` | Muestra ayuda y versión | Implementado |
| **UI/Utils** | `lib/core/ui.sh`, `lib/core/utils.sh` | Utilidades de salida, spinners, instalación, docker pull | Implementado |
| **Checks** | `lib/core/checks.sh` | Validaciones de OS, Docker, daemon, permisos | Implementado |
| **Project/Workspace** | `lib/core/project.sh`, `lib/workspace.sh` | Detección de workspace, carga de astra.yaml/secrets.yaml | Implementado |
| **Template Engine** | `lib/template.sh` | Motor de templates simple `{{KEY}}` → valor | Implementado |
| **Workspace Init** | `commands/workspace/init.sh` | Crea workspace, astra.yaml, secrets.yaml, .gitignore, dirs | Implementado |
| **Node Commands** | `commands/node/*.sh` | CRUD de nodos | **Vacíos (no implementados)** |
| **Flash Commands** | `commands/node/flash/*.sh` | Flasheo USB/OTA via ESPHome Docker | **Parcial (hardcoded, no usan workspace)** |
| **Broker Commands** | `commands/broker/*.sh` | docker-compose up/down/ps mosquitto | **Parcial (referencian docker/ inexistente)** |
| **Logs Commands** | `commands/logs/*.sh` | Logs USB/OTA | **Vacíos (no implementados)** |
| **ESPHome Driver** | `drivers/esphome/template.yaml` | Template de configuración ESPHome | **Solo template (no hay lógica de driver)** |

### Capas arquitectónicas observadas

```
┌─────────────────────────────────────┐
│         bin/astra (entry)           │
├─────────────────────────────────────┤
│      lib/core/router.sh             │  ← Routing centralizado
├─────────────────────────────────────┤
│  commands/{workspace,node,broker,   │  ← Capa de comandos
│           flash,logs}/*.sh          │
├─────────────────────────────────────┤
│  lib/{workspace,template,core}/*.sh │  ← Librerías compartidas
├─────────────────────────────────────┤
│  drivers/esphome/template.yaml      │  ← Templates de drivers
└─────────────────────────────────────┘
```

**No existe**: capa de abstracción de drivers, runtime de nodos, implementación ADP, Docker Compose project files.

---

## 3. Flujo de ejecución

### Paso a paso: `astra <comando>`

```
1. Usuario ejecuta: astra init miproyecto
                │
                ▼
2. /usr/local/bin/astra (symlink) 
                │
                ▼
3. /opt/astra/bin/astra
   - export ASTRA_HOME="/opt/astra"
   - source project.sh (detecta is_development via symlink)
   - export ASTRA_ENV=development|production
   - exec router.sh "$@"
                │
                ▼
4. lib/core/router.sh
   - COMMAND="$1" (init)
   - ACTION="$2"  (miproyecto)
   - case COMMAND:
       init) shift; exec commands/workspace/init.sh "$@"
       node) shift 2; exec commands/node/${ACTION}.sh "$@"
       flash) shift 2; exec commands/node/flash/${ACTION}.sh "$@"
       broker|logs) shift 2; exec commands/$COMMAND/${ACTION}.sh "$@"
       -h|--help) show_help
       -v|--version) cat VERSION
       *) show_help; exit 1
                │
                ▼
5. commands/workspace/init.sh
   - source ui.sh, workspace.sh
   - WORKSPACE="$PWD/$1" (o $PWD)
   - Valida que no exista astra.yaml
   - PROJECT_NAME="${WORKSPACE##*/}"
   - Prompts: WIFI_SSID, WIFI_PASSWORD, MQTT_HOST
   - create_workspace → mkdir -p
   - create_astra_yaml → escribe astra.yaml con !secret refs
   - create_secrets_yaml → escribe secrets.yaml con valores reales
   - create_git_ignore → .gitignore (secrets.yaml, build/, .temp/)
   - create_directories → nodes/, docker/
   - success "Workspace creado."
```

### Flujo para `astra broker up`:

```
router.sh → commands/broker/up.sh → docker compose up -d mosquitto
                                    (desde directorio ../docker/ que NO EXISTE)
```

### Flujo para `astra flash usb nodo01`:

```
router.sh → commands/node/flash/usb.sh
   - ACTION="$1" (nodo01)
   - PROJECT_ROOT=.../commands/node
   - FIRMWARE_DIR=.../commands/node/../node/  ← HARDCODED, no usa workspace
   - cd FIRMWARE_DIR
   - docker run --rm --device=/dev/ttyUSB0 -v PWD:/config esphome/esphome run "nodo01"
```

---

## 4. Modelo conceptual actual

### Relaciones entre conceptos (según código real)

```
WORKSPACE (directorio con astra.yaml)
    │
    ├── astra.yaml          ← Intención del usuario (name, mqtt, wifi con !secret)
    ├── secrets.yaml        ← Valores reales (gitignored)
    ├── .gitignore
    ├── nodes/              ← Directorio vacío (creado pero no usado)
    └── docker/             ← Directorio vacío (creado pero no usado; broker commands fallan)
    
NODE (concepto, no implementado)
    │
    ├── node.yaml           ← NO EXISTE en código (documentado en vision.md)
    ├── driver: esphome     ← Solo template.yaml en drivers/esphome/
    └── firmware/           ← NO EXISTE estructura

DRIVER (solo ESPHome, solo template)
    │
    └── template.yaml       ← Variables: {{NODE_ID}}, {{NODE_FRIENDLY}}, {{BOARD}}, 
                               {{MQTT_HOST}}, wifi secrets via !secret

BROKER (Mosquitto via Docker Compose)
    │
    ├── commands/broker/up.sh    → docker compose up -d mosquitto
    ├── commands/broker/down.sh  → docker compose down mosquitto
    └── commands/broker/state.sh → docker compose ps mosquitto
    PROBLEMA: Referencian $PROJECT_ROOT/../docker/ que NO EXISTE

LOGS (no implementado)
    │
    ├── commands/logs/usb.sh     → VACÍO
    └── commands/logs/ota.sh     → VACÍO

ADP (Astro Device Protocol)
    │
    └── docs/adp.md, docs/protocolo.md → ARCHIVOS VACÍOS
```

### Discrepancia visión vs realidad

| Concepto | Documentado en `vision.md` / `README.md` | Implementado en código |
|----------|------------------------------------------|------------------------|
| `node.yaml` dice qué nodo querés | Sí | **No** |
| `astra.yaml` dice cómo es el proyecto | Sí | **Sí (parcial)** |
| `secrets.yaml` dice cómo se conecta | Sí | **Sí** |
| Drivers intercambiables | Sí | **No (solo template estático)** |
| ADP protocolo comunicación | Sí | **No (docs vacías)** |
| Node Announcement / Discovery | Roadmap | **No** |
| Request IDs (ADP) | Roadmap | **No** |
| SDK | Roadmap | **No** |

---

## 5. Estado de implementación

### ✅ Implementado (funciona)

| Componente | Archivos | Evidencia |
|------------|----------|-----------|
| Instalador (`install.sh --dev` / `install.sh`) | install.sh, utils.sh, checks.sh, ui.sh | Verificaciones OS, Docker, daemon, permisos; symlink o copy a /opt/astra; launcher en /usr/local/bin; pull images esphome/mosquitto |
| Desinstalador | uninstall.sh, utils.sh | remove_launcher, remove_installation |
| CLI entry point | bin/astra | Configura ASTRA_HOME, ENV, exec router |
| Router | lib/core/router.sh | Case statement completo para todos los comandos declarados |
| Help/Version | lib/core/help.sh, bin/VERSION | Muestra ayuda exacta del README; versión 0.1.0 |
| Workspace init | commands/workspace/init.sh, lib/workspace.sh, lib/template.sh | Crea estructura completa con prompts interactivos |
| Workspace find/load | lib/workspace.sh | `workspace_find()` busca astra.yaml hacia arriba; `load_workspace()` parsea con yq |
| Broker commands (estructura) | commands/broker/up.sh, down.sh, state.sh | Scripts existen y llaman docker compose |
| ESPHome template | drivers/esphome/template.yaml | Template YAML válido con variables {{ }} |
| Template engine | lib/template.sh | `render()` y `replace()` funcionan para sustitución simple |

### ⚠️ Parcialmente implementado

| Componente | Qué funciona | Qué falta / Problemas |
|------------|--------------|----------------------|
| **Broker MQTT** | Scripts existen, sintaxis docker compose correcta | Directorio `docker/` no existe; no hay `docker-compose.yml`; commands fallan en runtime |
| **Flash USB/OTA** | Scripts existen, invocan esphome/esphome Docker | Paths hardcoded (`../node/`); no usan workspace; no validan nodo; no usan template driver; `--device=/dev/ttyUSB0` hardcoded |
| **Workspace directories** | `nodes/` y `docker/` se crean | Vacíos, no usados por ningún comando real |
| **Secret management** | `secrets.yaml` creado y gitignored | `astra.yaml` usa `!secret` pero **no hay resolutor de secrets** (yq no resuelve `!secret`); `load_workspace` lee literalmente `!secret mqtt_host` |

### ❌ Documentado pero no implementado (vacíos)

| Componente | Archivos | Referenciado en |
|------------|----------|-----------------|
| `astra node create` | commands/node/add.sh (vacío) | router.sh, help.sh, README |
| `astra node delete` | commands/node/remove.sh (vacío) | router.sh, help.sh, README |
| `astra node list` | commands/node/list.sh (vacío) | router.sh (no está en case), help.sh, README |
| `astra logs usb <node>` | commands/logs/usb.sh (vacío) | router.sh, help.sh, README |
| `astra logs ota <node>` | commands/logs/ota.sh (vacío) | router.sh, help.sh, README |
| Driver system | drivers/ (solo esphome/template.yaml) | docs/drivers.md (vacío), vision.md |
| ADP Protocol | docs/adp.md, docs/protocolo.md (vacíos) | vision.md, README |
| Node lifecycle | docs/nodes.md (vacío) | vision.md, README |
| Architecture docs | docs/arquitectura.md, docs/filosofia.md, docs/workspace.md, docs/drivers.md, docs/roadmap.md | Todos vacíos salvo vision.md |

### 📋 Pendiente (solo en roadmap/README)

- ASTRA Discovery
- Node Announcement
- Request IDs (ADP)
- SDK
- Gestión completa de nodos (CRUD)
- Logs USB/OTA
- Resolución de `!secret` en astra.yaml
- Docker Compose project para broker
- Integración real driver ↔ workspace ↔ node

---

## 6. Inconsistencias

### 6.1 Documentación vs Código

| Documentación | Código real | Discrepancia |
|---------------|-------------|--------------|
| README: "Gestión del broker" implementado | Broker commands fallan (docker/ no existe) | **Falso positivo** |
| README: "Integración con ESPHome" implementado | Solo template.yaml; flash commands hardcoded, no integrados con workspace | **Exagerado** |
| README: "Workspace (`astra init`)" implementado | ✅ Correcto | - |
| vision.md: "Workspace nunca almacena archivos generados" | Workspace crea `nodes/`, `docker/` vacíos | **Inconsistencia menor** |
| vision.md: `node.yaml` dice qué nodo querés | No existe node.yaml en ningún lado | **Concepto solo documentado** |
| help.sh / README: `astra node list` | No está en router.sh case statement | **Comando fantasma en ayuda** |

### 6.2 Arquitectura declarada vs Real

| Declarado (vision.md/README) | Real (código) |
|------------------------------|---------------|
| "Drivers son intercambiables" | Un solo driver (esphome) como template estático; no hay registry, factory, ni interfaz |
| "Todo se comunica mediante ADP" | ADP no existe (docs vacías); comunicación es docker run directo |
| "El Core nunca conoce GPIO" | Flash commands usan `--device=/dev/ttyUSB0` hardcoded |
| "Nodos son reemplazables" | No hay abstracción de nodo; no hay node.yaml |
| "Workspace es portable" | `load_workspace` usa `yq` que no resuelve `!secret`; secrets.yaml tiene valores en claro |

### 6.3 Router vs Help vs Commands

- `router.sh` case tiene: `init`, `node`, `flash`, `broker`, `logs`
- `help.sh` muestra: `node create`, `node delete` (pero router usa `node` + ACTION → `create`/`delete`)
- `help.sh` muestra: `astra flash usb <node>`, `astra flash ota <node>` (router: `flash` + ACTION → `usb`/`ota`)
- `help.sh` muestra: `astra logs usb <node>`, `astra logs ota <node>` (router: `logs` + ACTION → `usb`/`ota`)
- **Falta en router**: `node list` (help lo muestra pero router no lo maneja)

### 6.4 Paths y referencias rotas

| Archivo | Referencia rota | Impacto |
|---------|-----------------|---------|
| `commands/broker/up.sh` | `cd "$DOCKER_DIR"` donde `DOCKER_DIR="$PROJECT_ROOT/../docker"` | Falla: directorio no existe |
| `commands/broker/down.sh` | Igual | Falla |
| `commands/broker/state.sh` | Igual | Falla |
| `commands/node/flash/usb.sh` | `FIRMWARE_DIR="$PROJECT_ROOT/../node/"` | Hardcoded, no usa workspace |
| `commands/node/flash/ota.sh` | Igual | Hardcoded, no usa workspace |
| `lib/workspace.sh:89-95` | `yq '.mqtt.host'` devuelve `!secret mqtt_host` literal | No resuelve secrets |

---

## 7. Deuda técnica y riesgos arquitectónicos

### 7.1 Riesgos críticos

| Riesgo | Evidencia | Impacto |
|--------|-----------|---------|
| **Secret resolution roto** | `lib/workspace.sh:89-95` usa `yq` directo; `astra.yaml` tiene `!secret` tags YAML | Variables `MQTT_HOST`, `WIFI_SSID`, `WIFI_PASSWORD` cargan literalmente `!secret key` en lugar del valor real |
| **Broker commands rotos** | `commands/broker/*.sh` referencian `../docker/` inexistente | `astra broker up/down/state` fallan completamente |
| **Flash commands no integrados** | `commands/node/flash/*.sh` usan paths hardcoded `../node/`, ignoran workspace | No pueden flashear nodos definidos en workspace; device USB hardcoded |
| **No node CRUD** | `commands/node/add.sh`, `list.sh`, `remove.sh` vacíos | Imposible gestionar nodos desde CLI |
| **No logs** | `commands/logs/*.sh` vacíos | Imposible ver logs de dispositivos |

### 7.2 Deuda técnica estructural

| Problema | Archivo | Descripción |
|----------|---------|-------------|
| **Hardcoded paths** | `commands/node/flash/*.sh`, `commands/broker/*.sh` | Usan `../node/`, `../docker/` relativos al script, no al workspace |
| **No driver abstraction** | `drivers/esphome/template.yaml` solo template | No hay loader de drivers, no hay interfaz común, no hay validación |
| **Template engine limitado** | `lib/template.sh` | Solo sustitución simple `{{KEY}}`; no soporta conditionals, loops, includes |
| **No validation** | `commands/workspace/init.sh` | No valida SSID, password, IP/hostname MQTT |
| **yq dependency no declarada** | `lib/workspace.sh:89-95` | Usa `yq` pero `checks.sh` no lo verifica |
| **Error handling inconsistente** | `lib/core/ui.sh:18-21` `success()` hace `exit 1` (¡bug!) | `success` debería salir con 0, no 1 |
| **No tests** | Ningún archivo de test en proyecto | Sin regresión detection |

### 7.3 Bugs confirmados

```bash
# lib/core/ui.sh:18-21
success() {
    printf "✔ %s\n" "$1"
    exit 1   # <-- BUG: exit 1 en función "success"
}
```

Esto hace que `astra init` termine con código de salida 1 (error) aun cuando todo funciona.

---

## 8. Preparación para hardware real

### Objetivo: ESP32 + BMP580 + DS18B20 administrado por Astra CLI

### 8.1 Qué falta en la arquitectura actual

| Requerimiento | Estado actual | Qué se necesita |
|---------------|---------------|-----------------|
| **Definición de nodo** | No existe `node.yaml` | Esquema: `node.yaml` con `id`, `driver: esphome`, `board: esp32`, `sensors: [...]` |
| **Driver ESPHome real** | Solo `template.yaml` | Lógica que: lee `node.yaml` + `astra.yaml` + `secrets.yaml` → genera firmware YAML completo |
| **Firmware generation** | No existe | Comando `astra node create` que renderiza template → `nodes/<id>/firmware.yaml` |
| **Flash integrado** | Hardcoded, fuera de workspace | `astra flash usb <node>` que usa `nodes/<node>/firmware.yaml` y device auto-detect |
| **Sensor abstraction** | No existe | Mapeo BMP580/DS18B20 → configuración ESPHome (I2C, OneWire, GPIO) |
| **Device detection** | Hardcoded `/dev/ttyUSB0` | Auto-detección puerto serie (udev, lsusb, esphome detector) |
| **OTA flash** | Mismo script que USB (copia) | Implementación real OTA via ESPHome API o ADP |
| **Logs** | Vacío | `astra logs usb <node>` → `screen`/`picocom` o `esphome logs`; `astra logs ota` → MQTT/ADP |

### 8.2 Cómo encajar sensores sin romper diseño

Según `vision.md`: *"El Workspace nunca depende de un driver. Los drivers nunca conocen la lógica del Core. Todo se comunica mediante ADP."*

**Propuesta de integración respetando arquitectura:**

```
workspace/
├── astra.yaml          (proyecto: mqtt, wifi via secrets)
├── secrets.yaml        (valores reales)
├── nodes/
│   └── estacion01/
│       ├── node.yaml   (intención: id, driver, board, sensors[])
│       └── firmware.yaml  (generado: template renderizado)
└── drivers/            (NO en workspace - drivers están en ASTRA_HOME)
    └── esphome/
        ├── template.yaml      (base)
        ├── sensors/
        │   ├── bmp580.yaml    (fragmento ESPHome para BMP580)
        │   └── ds18b20.yaml   (fragmento ESPHome para DS18B20)
        └── driver.sh          (lógica: render template + fragments → firmware.yaml)
```

**Flujo `astra node create estacion01 --driver esphome --board esp32dev --sensors bmp580,ds18b20`:**

1. Valida driver existe en `$ASTRA_HOME/drivers/esphome/`
2. Crea `nodes/estacion01/node.yaml` con intención
3. Invoca `drivers/esphome/driver.sh render estacion01`
4. `driver.sh` carga `astra.yaml`, `secrets.yaml`, `node.yaml`
5. Renderiza `template.yaml` + fragments de sensores → `firmware.yaml`
6. Guarda en `nodes/estacion01/firmware.yaml`

**Flujo `astra flash usb estacion01`:**

1. `workspace_find()` → carga workspace
2. Lee `nodes/estacion01/firmware.yaml`
3. Auto-detecta puerto USB (o usa `--port`)
4. `docker run esphome/esphome run firmware.yaml`

### 8.3 Mínimo viable para ESP32 + BMP580 + DS18B20

| Archivo a crear/modificar | Propósito |
|---------------------------|-----------|
| `commands/node/add.sh` | Implementar `node create` con flags `--driver`, `--board`, `--sensors` |
| `drivers/esphome/driver.sh` | Lógica de renderizado: template + sensor fragments → firmware.yaml |
| `drivers/esphome/sensors/bmp580.yaml` | Fragmento ESPHome: `i2c:`, `sensor: - platform: bmp580...` |
| `drivers/esphome/sensors/ds18b20.yaml` | Fragmento ESPHome: `dallas:`, `sensor: - platform: ds18b20...` |
| `commands/node/flash/usb.sh` | Reescribir para usar workspace + firmware.yaml generado + auto-detect port |
| `lib/workspace.sh` | Agregar `node_find()`, `load_node()`, `render_firmware()` |
| `lib/template.sh` | Extender para includes/partials (sensor fragments) |

---

## 9. Próximo vertical slice recomendado

### Objetivo: **ESP32 + BMP580 + DS18B20 + Astra CLI funcionando end-to-end**

### Vertical Slice Mínimo (MVP)

```
┌─────────────────────────────────────────────────────────────┐
│                    VERTICAL SLICE MVP                       │
├─────────────────────────────────────────────────────────────┤
│  1. astra init mi-estacion          ← YA FUNCIONA           │
│  2. astra node create estacion01    ← NUEVO (implementar)   │
│       --driver esphome                                         │
│       --board esp32dev                                         │
│       --sensors bmp580,ds18b20                                 │
│  3. astra flash usb estacion01      ← NUEVO (reimplementar)  │
│  4. astra logs usb estacion01       ← NUEVO (implementar)    │
│  5. astra broker up                 ← ARREGLAR (docker/)     │
└─────────────────────────────────────────────────────────────┘
```

### Plan de implementación ordenado

#### Fase 0: Arreglar base rota (1-2 horas)
- [ ] Crear `docker/docker-compose.yml` con servicio `mosquitto`
- [ ] Fix `success()` en `lib/core/ui.sh` (exit 0 no 1)
- [ ] Agregar check `yq` en `lib/core/checks.sh`
- [ ] Implementar resolutor `!secret` en `lib/workspace.sh:load_workspace()`

#### Fase 1: Node Create (2-3 horas)
- [ ] Implementar `commands/node/add.sh`:
  - Args parsing: `--driver`, `--board`, `--sensors` (comma-separated)
  - Validar driver existe en `$ASTRA_HOME/drivers/<driver>/`
  - Crear `nodes/<id>/node.yaml` con intención
  - Invocar `driver.sh render <node_id>`

#### Fase 2: Driver ESPHome con sensores (3-4 horas)
- [ ] Crear `drivers/esphome/driver.sh`:
  - `render` command: carga workspace + node.yaml + secrets
  - Renderiza `template.yaml` + sensor fragments → `firmware.yaml`
  - Soporte `include` en template engine (`lib/template.sh`)
- [ ] Crear `drivers/esphome/sensors/bmp580.yaml` (I2C address 0x47, temp/pressure)
- [ ] Crear `drivers/esphome/sensors/ds18b20.yaml` (OneWire GPIO, temp)

#### Fase 3: Flash USB real (2-3 horas)
- [ ] Reescribir `commands/node/flash/usb.sh`:
  - Usar `workspace_find()` + `load_workspace()` + `load_node()`
  - Leer `nodes/<id>/firmware.yaml`
  - Auto-detectar puerto: `esphome-detect` o `ls /dev/ttyUSB*` / `ttyACM*`
  - Permitir `--port` override
  - Ejecutar `docker run esphome/esphome run firmware.yaml`

#### Fase 4: Logs USB (1-2 horas)
- [ ] Implementar `commands/logs/usb.sh`:
  - Usar `screen`, `picocom`, o `esphome logs` contra puerto detectado
  - Opción `--follow` / `-f`

#### Fase 5: Broker funcional (1 hora)
- [ ] Crear `docker/docker-compose.yml`:
  ```yaml
  services:
    mosquitto:
      image: eclipse-mosquitto:2
      ports: ["1883:1883", "9001:9001"]
      volumes: ["./mosquitto:/mosquitto"]
  ```
- [ ] Ajustar `commands/broker/*.sh` para usar `docker compose -f $WORKSPACE/docker/docker-compose.yml`

### Estimación total: **10-15 horas** para vertical slice completo funcional

### Criterios de aceptación del slice

```bash
# 1. Init workspace
astra init mi-estacion
# → prompts WiFi, MQTT; crea estructura completa

# 2. Crear nodo con sensores
astra node create estacion01 --driver esphome --board esp32dev --sensors bmp580,ds18b20
# → genera nodes/estacion01/firmware.yaml con config ESPHome completa

# 3. Levantar broker
astra broker up
# → mosquitto corriendo en docker

# 4. Flashear por USB (ESP32 conectado)
astra flash usb estacion01
# → detecta puerto, compila y flashea firmware

# 5. Ver logs
astra logs usb estacion01
# → muestra salida serial del ESP32 con lecturas BMP580/DS18B20
```

---

## Conclusión

Astra CLI tiene una **base sólida pero incompleta**: el scaffolding de instalación, routing, workspace y templates está bien diseñado y funcionando. Los **gaps críticos** son:

1. **Infraestructura de broker rota** (docker/ faltante)
2. **Node CRUD inexistente** (comandos vacíos)
3. **Driver system es solo un template** (sin lógica de renderizado)
4. **Flash/Logs desconectados del workspace** (hardcoded paths)
5. **Secret resolution roto** (`!secret` no se resuelve)

El **vertical slice propuesto** ataca directamente estos gaps en orden de dependencia, entregando valor tangible (hardware real funcionando) sin requerir la arquitectura completa de ADP, Discovery, SDK, etc. Cada fase construye sobre la anterior y valida la arquitectura `workspace → node → driver → firmware → flash → logs` que ya está diseñada en `vision.md` pero no implementada.

---

*Informe generado mediante auditoría directa de código y documentación en `/workspace` - Septiembre 2026*