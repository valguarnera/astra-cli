#!/usr/bin/env bash

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/core/project.sh"

write_file() {
    local file="$1"

    cat > "$file"

    ok "${file##*/}"
}

install_cli_dev() {
    sudo rm -rf /opt/astra
    sudo ln -s "$SCRIPT_DIR" /opt/astra
    ok "Development link"
}

install_cli() {
    sudo rm -rf /opt/astra
    sudo mkdir -p /opt/astra
    sudo cp -R \
        "$SCRIPT_DIR/bin" \
        "$SCRIPT_DIR/commands" \
        "$SCRIPT_DIR/lib" \
        "$SCRIPT_DIR/drivers" \
        /opt/astra

    ok "Installation directory"
}

create_launcher() {
    sudo ln -sf \
        /opt/astra/bin/astra \
        /usr/local/bin/astra

    ok "Launcher"
}

run_with_spinner(){
    frames='—\|/'
    i=0
    local text="$1"

    shift
    "$@" >/dev/null 2>&1 &

    local pid=$!

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r%s %s" "${frames:$i:1}" "$text"
        i=$(( (i + 1) % ${#frames} ))
        sleep 0.2
    done
    wait "$pid"
    
    # spinner refresh
    if [ $? -eq 0 ]; then
        printf "\r"
        ok "$text"
    else
        printf "\r"
        fail "$text"
    fi
}

pull_images() {
    run_with_spinner \
        "ESPHome image" \
        docker pull esphome/esphome

    run_with_spinner \
        "Mosquitto image" \
        docker pull eclipse-mosquitto
}

remove_launcher() {
  rm /usr/local/bin/astra
  ok "Launcher"
}

remove_installation() {
    if is_development; then
        rm /opt/astra
    else
        rm -rf /opt/astra
    fi    
    ok "Installation directory"
}
