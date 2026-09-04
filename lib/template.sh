replace() {
    local text="$1"
    local key="$2"
    local value="$3"

    printf "%s" "${text//\{\{$key\}\}/$value}"
}

render() {
    local template

    template="$(cat "$1")"

    shift

    while [ $# -gt 1 ]; do
        template=$(replace \
            "$template" \
            "$1" \
            "$2")
        shift 2
    done

    printf "%s" "$template"
}