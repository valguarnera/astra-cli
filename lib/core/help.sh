show_help(){

cat << EOF

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
