#!/usr/bin/env bash
source "$ASTRA_HOME/lib/core/help.sh"

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    return 0
fi

COMMAND="$1"
ACTION="$2"

# Handle --help for subcommands
if [ "$ACTION" = "--help" ] || [ "$ACTION" = "-h" ]; then
    case "$COMMAND" in
        hardware)
            cat <<EOF
astra hardware - Gestión y verificación de hardware

Uso:
    astra hardware detect           Detecta dispositivos ESP8266/ESP32 conectados
    astra hardware check            Verifica hardware completo (ESP, sensores, USB)
    astra hardware identify <port>  Identifica modelo de ESP en puerto específico
    astra hardware check-esp [port] Verifica conectividad con ESP

Ejemplos:
    astra hardware detect
    astra hardware check
    astra hardware identify /dev/ttyUSB0
    astra hardware check-esp /dev/ttyUSB0
EOF
            exit 0
            ;;
        usb)
            cat <<EOF
astra usb - Gestión de almacenamiento USB

Uso:
    astra usb list              Lista dispositivos de almacenamiento USB
    astra usb test [device]     Prueba almacenamiento USB (mount, write, read, verify, cleanup)
    astra usb mount <device>    Monta dispositivo USB
    astra usb unmount           Desmonta almacenamiento USB

Ejemplos:
    astra usb list
    astra usb test /dev/sdb1
    astra usb mount /dev/sdb1
    astra usb unmount
EOF
            exit 0
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
fi

COMMAND="$1"
ACTION="$2"

case "$COMMAND" in
  -h|--help)
    show_help
    ;;
  -v|--version)
    cat "$ASTRA_HOME/bin/VERSION"
    ;;
  init)
    shift
    "$ASTRA_HOME/commands/workspace/$COMMAND.sh" "$@"
    ;;
  node)
    shift 2
    "$ASTRA_HOME/commands/node/${ACTION}.sh" "$@"
    ;;
  flash)
    shift 2
    "$ASTRA_HOME/commands/node/flash/${ACTION}.sh" "$@"
    ;;
  broker|logs)
    shift 2
    "$ASTRA_HOME/commands/$COMMAND/${ACTION}.sh" "$@"
    ;;
  hardware|usb)
    shift 2
    "$ASTRA_HOME/commands/$COMMAND/${ACTION}.sh" "$@"
    ;;
  *)
    show_help
    exit 1
    ;;
esac