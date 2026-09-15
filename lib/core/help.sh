show_help(){

cat << EOF

ASTRA CLI

Uso:

    astra init

    astra broker up
    astra broker down
    astra broker state

    astra node create <id> --board <board> --sensors <list>
    astra node list
    astra node delete <id>

    astra flash usb <node> [--port <port>]

    astra logs usb <node> [--port <port>] [--follow] [--lines <n>]

    astra hardware detect
    astra hardware check
    astra hardware identify <port>
    astra hardware check-esp [port]

    astra usb list
    astra usb test [device]
    astra usb mount <device>
    astra usb unmount

Opciones

    -h, --help
    -v, --version

EOF

}
