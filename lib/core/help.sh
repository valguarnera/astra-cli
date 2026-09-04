show_help(){

cat << EOF

ASTRA CLI

Uso:

    astra init

    astra broker up
    astra broker down
    astra broker state

    astra node create
    astra node delete

    astra flash usb <node>
    astra flash ota <node>

    astra logs usb <node>
    astra logs ota <node>

Opciones

    -h, --help
    -v, --version

EOF

}
