#!/usr/bin/env bash

# Node create and ESPHome driver tests

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/workspace.sh"
source "$ASTRA_HOME/lib/core/checks.sh"

# Test: node create without workspace
test_node_create_no_workspace() {
    local test_dir="/tmp/astra_test_node_nows_$$"
    mkdir -p "$test_dir"
    
    cd "$test_dir"
    output=$(ASTRA_HOME="$ASTRA_HOME" "$ASTRA_HOME/commands/node/create.sh" sensor01 --board esp32dev --sensors bmp580 2>&1)
    local exit_code=$?
    
    cd - >/dev/null
    rm -rf "$test_dir"
    
    assert_equals "1" "$exit_code" "node create should fail without workspace"
    echo "$output" | grep -q "No se encontró un Workspace ASTRA" || return 1
}

# Test: node create with missing arguments
test_node_create_missing_args() {
    local test_dir="/tmp/astra_test_node_missing_$$"
    mkdir -p "$test_dir"
    echo "name: test" > "$test_dir/astra.yaml"
    echo "mqtt: {host: 192.168.1.100}" >> "$test_dir/astra.yaml"
    echo "wifi: {ssid: test, password: test}" >> "$test_dir/astra.yaml"
    
    cd "$test_dir"
    output=$(ASTRA_HOME="$ASTRA_HOME" "$ASTRA_HOME/commands/node/create.sh" 2>&1)
    local exit_code=$?
    
    cd - >/dev/null
    (rm -rf "$test_dir" 2>/dev/null) &
    sleep 0.2
    
    assert_equals "1" "$exit_code" "node create should fail with missing args"
    echo "$output" | grep -q "Falta <id> del nodo" || return 1
}

# Test: node create with invalid sensor
test_node_create_invalid_sensor() {
    local test_dir="/tmp/astra_test_node_invalid_$$"
    mkdir -p "$test_dir"
    echo "name: test" > "$test_dir/astra.yaml"
    echo "mqtt: {host: 192.168.1.100}" >> "$test_dir/astra.yaml"
    echo "wifi: {ssid: test, password: test}" >> "$test_dir/astra.yaml"
    
    cd "$test_dir"
    output=$(ASTRA_HOME="$ASTRA_HOME" "$ASTRA_HOME/commands/node/create.sh" sensor01 --board esp32dev --sensors invalidsensor 2>&1)
    local exit_code=$?
    
    cd - >/dev/null
    (rm -rf "$test_dir" 2>/dev/null) &
    sleep 0.2
    
    assert_equals "1" "$exit_code" "node create should fail with invalid sensor"
    echo "$output" | grep -q "no soportado" || return 1
}

# Test: node create duplicate node
test_node_create_duplicate() {
    local test_dir="/tmp/astra_test_node_dup_$$"
    mkdir -p "$test_dir/nodes/sensor01"
    echo "name: test" > "$test_dir/astra.yaml"
    echo "mqtt: {host: 192.168.1.100}" >> "$test_dir/astra.yaml"
    echo "wifi: {ssid: test, password: test}" >> "$test_dir/astra.yaml"
    echo "id: sensor01" > "$test_dir/nodes/sensor01/node.yaml"
    echo "friendly_name: Sensor01" >> "$test_dir/nodes/sensor01/node.yaml"
    echo "driver: esphome" >> "$test_dir/nodes/sensor01/node.yaml"
    echo "board: esp32dev" >> "$test_dir/nodes/sensor01/node.yaml"
    echo "sensors: [bmp580]" >> "$test_dir/nodes/sensor01/node.yaml"
    
    cd "$test_dir"
    output=$(ASTRA_HOME="$ASTRA_HOME" "$ASTRA_HOME/commands/node/create.sh" sensor01 --board esp32dev --sensors bmp580 2>&1)
    local exit_code=$?
    
    cd - >/dev/null
    (rm -rf "$test_dir" 2>/dev/null) &
    sleep 0.2
    
    assert_equals "1" "$exit_code" "node create should fail with duplicate node"
    echo "$output" | grep -q "ya existe" || return 1
}

# Test: ESPHome driver list-sensors
test_driver_list_sensors() {
    local output
    output=$(ASTRA_HOME="$ASTRA_HOME" "$ASTRA_HOME/drivers/esphome/driver.sh" list-sensors --raw 2>&1)
    
    echo "$output" | grep -q "bmp580" || return 1
    echo "$output" | grep -q "ds18b20" || return 1
}

# Test: ESPHome driver render (requires workspace)
test_driver_render() {
    local test_dir="/tmp/astra_test_driver_render_$$"
    mkdir -p "$test_dir/nodes/sensor01"
    echo "name: test" > "$test_dir/astra.yaml"
    echo "mqtt: {host: 192.168.1.100}" >> "$test_dir/astra.yaml"
    echo "wifi: {ssid: test, password: test}" >> "$test_dir/astra.yaml"
    cat > "$test_dir/nodes/sensor01/node.yaml" <<EOF
id: sensor01
friendly_name: "Sensor 01"
driver: esphome
board: esp32dev
sensors:
  - bmp580
EOF
    
    cd "$test_dir"
    output=$(ASTRA_HOME="$ASTRA_HOME" WORKSPACE="$test_dir" "$ASTRA_HOME/drivers/esphome/driver.sh" render sensor01 2>&1)
    local exit_code=$?
    
    [ -f "$test_dir/nodes/sensor01/firmware.yaml" ] || return 1
    
    cd - >/dev/null
    (rm -rf "$test_dir" 2>/dev/null) &
    sleep 0.2
    
    assert_equals "0" "$exit_code" "driver render should succeed"
}

# Test: dependency checks - Docker present
test_check_docker_present() {
    check_docker
    local result=$?
    assert_equals "0" "$result" "check_docker should pass when Docker is installed"
}

# Test: dependency checks - yq present
test_check_yq_present() {
    check_yq
    local result=$?
    assert_equals "0" "$result" "check_yq should pass when yq is installed"
}

# Test: node create with invalid sensor
test_node_create_invalid_sensor() {
    local test_dir="/tmp/astra_test_node_invalid_$$"
    mkdir -p "$test_dir"
    echo "name: test" > "$test_dir/astra.yaml"
    echo "mqtt: {host: 192.168.1.100}" >> "$test_dir/astra.yaml"
    echo "wifi: {ssid: test, password: test}" >> "$test_dir/astra.yaml"
    
    cd "$test_dir"
    output=$(ASTRA_HOME="$ASTRA_HOME" "$ASTRA_HOME/commands/node/create.sh" sensor01 --board esp32dev --sensors invalidsensor 2>&1)
    local exit_code=$?
    
    cd - >/dev/null
    (rm -rf "$test_dir" 2>/dev/null) &
    sleep 0.2
    
    assert_equals "1" "$exit_code" "node create should fail with invalid sensor"
    echo "$output" | grep -q "no soportado" || return 1
}

# Test: node create with invalid board (not in whitelist)
test_node_create_invalid_board() {
    local test_dir="/tmp/astra_test_node_invboard_$$"
    mkdir -p "$test_dir"
    echo "name: test" > "$test_dir/astra.yaml"
    echo "mqtt: {host: 192.168.1.100}" >> "$test_dir/astra.yaml"
    echo "wifi: {ssid: test, password: test}" >> "$test_dir/astra.yaml"
    
    cd "$test_dir"
    output=$(ASTRA_HOME="$ASTRA_HOME" "$ASTRA_HOME/commands/node/create.sh" sensor01 --board invalidboard --sensors bmp580 2>&1)
    local exit_code=$?
    
    cd - >/dev/null
    rm -rf "$test_dir"
    
    assert_equals "1" "$exit_code" "node create should fail with invalid board"
    echo "$output" | grep -q "no válido" || return 1
    echo "$output" | grep -q "esp32dev" || return 1
}

# Test: node create with ESP8266 board in ESP32 template
test_node_create_esp8266_board_in_esp32_template() {
    local test_dir="/tmp/astra_test_node_esp8266_$$"
    mkdir -p "$test_dir"
    echo "name: test" > "$test_dir/astra.yaml"
    echo "mqtt: {host: 192.168.1.100}" >> "$test_dir/astra.yaml"
    echo "wifi: {ssid: test, password: test}" >> "$test_dir/astra.yaml"
    
    cd "$test_dir"
    output=$(ASTRA_HOME="$ASTRA_HOME" "$ASTRA_HOME/commands/node/create.sh" sensor01 --board esp01 --sensors bmp580 2>&1)
    local exit_code=$?
    
    cd - >/dev/null
    rm -rf "$test_dir"
    
    assert_equals "1" "$exit_code" "node create should fail with ESP8266 board"
    echo "$output" | grep -q "ESP8266" || return 1
    echo "$output" | grep -q "ESP32" || return 1
    echo "$output" | grep -q "no implementado" || return 1
}

# Test: node create with mqtt_host = localhost (should fail)
test_node_create_mqtt_localhost() {
    local test_dir="/tmp/astra_test_node_mqttlh_$$"
    mkdir -p "$test_dir"
    echo "name: test" > "$test_dir/astra.yaml"
    echo "mqtt: {host: localhost}" >> "$test_dir/astra.yaml"
    echo "wifi: {ssid: test, password: test}" >> "$test_dir/astra.yaml"
    
    cd "$test_dir"
    output=$(ASTRA_HOME="$ASTRA_HOME" "$ASTRA_HOME/commands/node/create.sh" sensor01 --board esp32dev --sensors bmp580 2>&1)
    local exit_code=$?
    
    cd - >/dev/null
    rm -rf "$test_dir"
    
    assert_equals "1" "$exit_code" "node create should fail with localhost MQTT"
    echo "$output" | grep -q "no es válido" || return 1
    echo "$output" | grep -q "192.168.1.100" || return 1
}

# Test: dependency checks - ESPHome image present
test_check_esphome_present() {
    check_esphome
    local result=$?
    assert_equals "0" "$result" "check_esphome should pass when image exists"
}

# Test: ensure_dependency with existing dependency
test_ensure_dependency_existing() {
    # check_docker should pass (Docker is installed)
    ensure_dependency check_docker install_docker "Docker" 2>/dev/null
    local result=$?
    assert_equals "0" "$result" "ensure_dependency should pass for existing dependency"
}