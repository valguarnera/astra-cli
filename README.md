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
Verificamos la instalación

```bash
astra --version
```

## Desinstalar correctamente

```bash
sudo ./uninstall.sh
```
---

## ¿Qué es ASTRA CLI?

ASTRA CLI no es un proyecto ASTRA.

Es la herramienta encargada de orquestar todo el ecosistema.

Con ella será posible:

- Crear Workspaces.
- Crear nodos.
- Compilar firmware.
- Flashear dispositivos por USB u OTA.
- Administrar el broker MQTT.
- Consultar logs.
- Gestionar proyectos ASTRA.

---

## ¿Cómo usar ASTRA CLI?

El comando `astra --help` muestra los casos de uso. Devuelve una estructura bella y simple de interpretar.

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

## Estado del proyecto

Actualmente ASTRA CLI se encuentra en desarrollo activo.

### Implementado

- Instalador
- CLI global.
- Gestión del broker.
- Integración con ESPHome.
- Verificaciones del sistema.
- Descarga automática de imágenes Docker.
- Workspace (`astra init`)

### Próximamente

- Gestión de nodos.
- ASTRA Discovery.
- Node Announcement.
- Request IDs (ADP).
- SDK.

---
## ¿Qué es ASTRA?

> ASTRA es un ecosistema para la automatización y el desarrollo de sistemas distribuidos. Está compuesto por una herramienta de línea de comandos (ASTRA CLI), un formato de Workspace para organizar proyectos, un conjunto de drivers para distintos tipos de nodos y un protocolo de comunicación propio llamado **ADP (ASTRA Device Protocol)**.
>
> El objetivo de ASTRA es desacoplar el hardware de la lógica de automatización, permitiendo que distintos dispositivos compartan una misma arquitectura y puedan integrarse al sistema mediante drivers específicos.

---

## Filosofía

ASTRA está dividido en tres componentes claramente separados.

* ### ASTRA CLI

  La herramienta que utiliza el usuario.

* ### Workspace

  El proyecto sobre el que trabaja ASTRA.

* ### Nodos

  Los dispositivos físicos que ejecutan el firmware.

Esta separación permite que la herramienta evolucione independientemente de los proyectos y del hardware.

---

## Ecositema

```text
ASTRA

├── CLI
│   Herramienta de desarrollo.
│
├── Workspace
│   Organización de un proyecto.
│
├── Nodes
│   Dispositivos físicos.
│
├── Drivers
│   Adaptadores entre cada tecnología y ASTRA.
│
└── ADP
    Protocolo de comunicación.
```

---

## Licencia

APACHE V2.0
