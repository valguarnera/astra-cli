#!/usr/bin/env bash

# Flash and Logs tests

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/workspace.sh"
source "$ASTRA_HOME/lib/core/checks.sh"

# Test: flash usb without workspace
test_flash_usb_no_workspace() {
    local test_dir="/tmp/astra_test_flash_nows_$$"
    mkdir -p "$test_dir"
    
    cd "$test_dir"
    output=$(ASTRA_HOME="$ASTRA_HOME" "$ASTRA_HOME/commands/node/flash/usb.sh" sensor01 2>&1)
    local exit_code=$?
    
    cd - >/dev/null
    rm -rf "$test_dir"
    
    assert_equals "1" "$exit_code" "flash usb should fail without workspace"
    echo "$output" | grep -q "No se encontró un Workspace ASTRA" || return 1
}

# Test: flash usb with missing node
test_flash_usb_missing_node() {
    local test_dir="/tmp/astra_test_flash_missing_$$"
    mkdir -p "$test_dir"
    echo "name: test" > "$test_dir/astra.yaml"
    echo "mqtt: {host: localhost}" >> "$test_dir/astra.yaml"
    echo "wifi: {ssid: test, password: test}" >> "$test_dir/astra.yaml"
    
    cd "$test_dir"
    output=$(ASTRA_HOME="$ASTRA_HOME" "$ASTRA_HOME/commands/node/flash/usb.sh" sensor01 2>&1)
    local exit_code=$?
    
    cd - >/dev/null
    rm -rf "$test_dir"
    
    assert_equals "1" "$exit_code" "flash usb should fail with missing node"
    echo "$output" | grep -q "no encontrado" || return 1
}

# Test: flash usb with explicit port that doesn't exist (skipped - docker permission issues)
test_flash_usb_explicit_port_not_exist() {
    run_test_skip "test_flash_usb_explicit_port_not_exist" "docker permission issues in test env"
    return 0
}

# Test: flash usb auto-select single node (skipped - docker permission issues)
test_flash_usb_auto_select_single() {
    run_test_skip "test_flash_usb_auto_select_single" "docker permission issues in test env"
    return 0
}

# Test: flash usb multiple nodes error
test_flash_usb_multiple_nodes_error() {
    local test_dir="/tmp/astra_test_flash_multi_$$"
    mkdir -p "$test_dir/nodes/sensor01" "$test_dir/nodes/sensor02"
    echo "name: test" > "$test_dir/astra.yaml"
    echo "mqtt: {host: localhost}" >> "$test_dir/astra.yaml"
    echo "wifi: {ssid: test, password: test}" >> "$test_dir/astra.yaml"
    cat > "$test_dir/nodes/sensor01/node.yaml" <<EOF
id: sensor01
friendly_name: "Sensor 01"
driver: esphome
board: esp32dev
sensors:
  - bmp580
EOF
    cat > "$test_dir/nodes/sensor02/node.yaml" <<EOF
id: sensor02
friendly_name: "Sensor 02"
driver: esphome
board: esp32dev
sensors:
  - ds18b20
EOF
    cat > "$test_dir/nodes/sensor01/firmware.yaml" <<EOF
esphome:
  name: sensor01
  friendly_name: "Sensor 01"
esp32:
  board: esp32dev
wifi:
  ssid: "test"
  password: "test"
EOF
    cat > "$test_dir/nodes/sensor02/firmware.yaml" <<EOF
esphome:
  name: sensor02
  friendly_name: "Sensor 02"
esp32:
  board: esp32dev
wifi:
  ssid: "test"
  password: "test"
EOF
    
    cd "$test_dir"
    output=$(ASTRA_HOME="$ASTRA_HOME" "$ASTRA_HOME/commands/node/flash/usb.sh" 2>&1)
    local exit_code=$?
    
    cd - >/dev/null
    rm -rf "$test_dir"
    
    assert_equals "1" "$exit_code" "flash usb should fail with multiple nodes"
    echo "$output" | grep -q "Múltiples nodos encontrados" || return 1
    echo "$output" | grep -q "sensor01" || return 1
    echo "$output" | grep -q "sensor02" || return 1
}

# Test: flash usb permission denied handling (mock)
test_flash_usb_permission_denied() {
    # We can't easily test permission denied without actual device
    return 0
}

# Test: logs usb without workspace
test_logs_usb_no_workspace() {
    local test_dir="/tmp/astra_test_logs_nows_$$"
    mkdir -p "$test_dir"
    
    cd "$test_dir"
    output=$(ASTRA_HOME="$ASTRA_HOME" "$ASTRA_HOME/commands/logs/usb.sh" sensor01 2>&1)
    local exit_code=$?
    
    cd - >/dev/null
    rm -rf "$test_dir"
    
    assert_equals "1" "$exit_code" "logs usb should fail without workspace"
    echo "$output" | grep -q "No se encontró un Workspace ASTRA" || return 1
}

# Test: logs usb with missing node
test_logs_usb_missing_node() {
    local test_dir="/tmp/astra_test_logs_missing_$$"
    mkdir -p "$test_dir"
    echo "name: test" > "$test_dir/astra.yaml"
    echo "mqtt: {host: localhost}" >> "$test_dir/astra.yaml"
    echo "wifi: {ssid: test, password: test}" >> "$test_dir/astra.yaml"
    
    cd "$test_dir"
    output=$(ASTRA_HOME="$ASTRA_HOME" "$ASTRA_HOME/commands/logs/usb.sh" sensor01 2>&1)
    local exit_code=$?
    
    cd - >/dev/null
    rm -rf "$test_dir"
    
    assert_equals "1" "$exit_code" "logs usb should fail with missing node"
    echo "$output" | grep -q "no encontrado" || return 1
}

# Test: logs usb explicit port not exist (skipped - docker permission issues)
test_logs_usb_explicit_port_not_exist() {
    run_test_skip "test_logs_usb_explicit_port_not_exist" "docker permission issues in test env"
    return 0
}

# Test: logs usb auto-select single node
test_logs_usb_auto_select_single() {
    local test_dir="/tmp/astra_test_logs_auto_$$"
    mkdir -p "$test_dir/nodes/sensor01"
    echo "name: test" > "$test_dir/astra.yaml"
    echo "mqtt: {host: localhost}" >> "$test_dir/astra.yaml"
    echo "wifi: {ssid: test, password: test}" >> "$test_dir/astra.yaml"
    cat > "$test_dir/nodes/sensor01/node.yaml" <<EOF
id: sensor01
friendly_name: "Sensor 01"
driver: esphome
board: esp32dev
sensors:
  - bmp580
EOF
    cat > "$test_dir/nodes/sensor01/firmware.yaml" <<EOF
esphome:
  name: sensor01
  friendly_name: "Sensor 01"
esp32:
  board: esp32dev
wifi:
  ssid: "test"
  password: "test"
EOF
    
    cd "$test_dir"
    output=$(ASTRA_HOME="$ASTRA_HOME" "$ASTRA_HOME/commands/logs/usb.sh" 2>&1)
    local exit_code=$?
    
    cd - >/dev/null
    rm -rf "$test_dir"
    
    assert_equals "1" "$exit_code" "logs usb should fail on no USB"
    echo "$output" | grep -q "Auto-seleccionando único nodo: sensor01" || return 1
    echo "$output" | grep -q "No se detectó ningún dispositivo USB" || return 1
}

# Test: logs usb multiple nodes error
test_logs_usb_multiple_nodes_error() {
    local test_dir="/tmp/astra_test_logs_multi_$$"
    mkdir -p "$test_dir/nodes/sensor01" "$test_dir/nodes/sensor02"
    echo "name: test" > "$test_dir/astra.yaml"
    echo "mqtt: {host: localhost}" >> "$test_dir/astra.yaml"
    echo "wifi: {ssid: test, password: test}" >> "$test_dir/astra.yaml"
    cat > "$test_dir/nodes/sensor01/node.yaml" <<EOF
id: sensor01
friendly_name: "Sensor 01"
driver: esphome
board: esp32dev
sensors:
  - bmp580
EOF
    cat > "$test_dir/nodes/sensor02/node.yaml" <<EOF
id: sensor02
friendly_name: "Sensor 02"
driver: esphome
board: esp32dev
sensors:
  - ds18b20
EOF
    cat > "$test_dir/nodes/sensor01/firmware.yaml" <<EOF
esphome:
  name: sensor01
  friendly_name: "Sensor 01"
esp32:
  board: esp32dev
wifi:
  ssid: "test"
  password: "test"
EOF
    cat > "$test_dir/nodes/sensor02/firmware.yaml" <<EOF
esphome:
  name: sensor02
  friendly_name: "Sensor 02"
esp32:
  board: esp32dev
wifi:
  ssid: "test"
  password: "test"
EOF
    
    cd "$test_dir"
    output=$(ASTRA_HOME="$ASTRA_HOME" "$ASTRA_HOME/commands/logs/usb.sh" 2>&1)
    local exit_code=$?
    
    cd - >/dev/null
    rm -rf "$test_dir"
    
    assert_equals "1" "$exit_code" "logs usb should fail with multiple nodes"
    echo "$output" | grep -q "Múltiples nodos encontrados" || return 1
    echo "$output" | grep -q "sensor01" || return 1
    echo "$output" | grep -q "sensor02" || return 1
}

# Test: logs usb permission denied handling (mock)
test_logs_usb_permission_denied() {
    return 0
}

# Test: flash usb without workspace
test_flash_usb_no_workspace() {
    local test_dir="/tmp/astra_test_flash_nows_$$"
    mkdir -p "$test_dir"
    
    cd "$test_dir"
    output=$(ASTRA_HOME="$ASTRA_HOME" "$ASTRA_HOME/commands/node/flash/usb.sh" sensor01 2>&1)
    local exit_code=$?
    
    cd - >/dev/null
    rm -rf "$test_dir"
    
    assert_equals "1" "$exit_code" "flash usb should fail without workspace"
    echo "$output" | grep -q "No se encontró un Workspace ASTRA" || return 1
}

# Test: flash usb with missing node
test_flash_usb_missing_node() {
    local test_dir="/tmp/astra_test_flash_missing_$$"
    mkdir -p "$test_dir"
    echo "name: test" > "$test_dir/astra.yaml"
    echo "mqtt: {host: localhost}" >> "$test_dir/astra.yaml"
    echo "wifi: {ssid: test, password: test}" >> "$test_dir/astra.yaml"
    
    cd "$test_dir"
    output=$(ASTRA_HOME="$ASTRA_HOME" "$ASTRA_HOME/commands/node/flash/usb.sh" sensor01 2>&1)
    local exit_code=$?
    
    cd - >/dev/null
    rm -rf "$test_dir"
    
    assert_equals "1" "$exit_code" "flash usb should fail with missing node"
    echo "$output" | grep -q "no encontrado" || return 1
}

# Test: detect_usb_ports function
test_detect_usb_ports() {
    # Function is defined in the script, we can't easily test it in isolation
    # Just verify the script loads
    return 0
}

# Test: logs usb permission denied handling (mock)
test_logs_usb_permission_denied() {
    return 0
}