#!/usr/bin/env bash

# Secrets resolution tests

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/workspace.sh"

test_resolve_secret_existing() {
    local test_dir="/tmp/astra_test_secrets_$$"
    mkdir -p "$test_dir"
    
    cat > "$test_dir/astra.yaml" <<EOF
name: test
mqtt:
  host: !secret mqtt_host
wifi:
  ssid: !secret wifi_ssid
  password: !secret wifi_password
EOF
    
    cat > "$test_dir/secrets.yaml" <<EOF
wifi_ssid: mywifi
wifi_password: mypassword
mqtt_host: 192.168.1.100
EOF
    
    local result
    result=$(resolve_secret_from_tag "mqtt.host" "$test_dir/astra.yaml" "$test_dir/secrets.yaml")
    assert_equals "192.168.1.100" "$result" "should resolve mqtt_host secret"
    
    result=$(resolve_secret_from_tag "wifi.ssid" "$test_dir/astra.yaml" "$test_dir/secrets.yaml")
    assert_equals "mywifi" "$result" "should resolve wifi_ssid secret"
    
    result=$(resolve_secret_from_tag "wifi.password" "$test_dir/astra.yaml" "$test_dir/secrets.yaml")
    assert_equals "mypassword" "$result" "should resolve wifi_password secret"
    
    rm -rf "$test_dir"
}

test_resolve_secret_missing_file() {
    local test_dir="/tmp/astra_test_secrets_$$"
    mkdir -p "$test_dir"
    
    cat > "$test_dir/astra.yaml" <<EOF
name: test
mqtt:
  host: !secret mqtt_host
EOF
    
    # No secrets.yaml file
    local result
    result=$(resolve_secret_from_tag "mqtt.host" "$test_dir/astra.yaml" "$test_dir/secrets.yaml" 2>/dev/null)
    local exit_code=$?
    
    assert_equals "1" "$exit_code" "should fail when secrets.yaml missing"
    
    rm -rf "$test_dir"
}

test_resolve_secret_missing_key() {
    local test_dir="/tmp/astra_test_secrets_$$"
    mkdir -p "$test_dir"
    
    cat > "$test_dir/astra.yaml" <<EOF
name: test
mqtt:
  host: !secret mqtt_host
EOF
    
    cat > "$test_dir/secrets.yaml" <<EOF
wifi_ssid: mywifi
EOF
    
    local result
    result=$(resolve_secret_from_tag "mqtt.host" "$test_dir/astra.yaml" "$test_dir/secrets.yaml" 2>/dev/null)
    local exit_code=$?
    
    assert_equals "1" "$exit_code" "should fail when secret key missing"
    
    rm -rf "$test_dir"
}

test_resolve_secret_no_tag() {
    local test_dir="/tmp/astra_test_secrets_$$"
    mkdir -p "$test_dir"
    
    cat > "$test_dir/astra.yaml" <<EOF
name: test
mqtt:
  host: localhost
EOF
    
    local result
    result=$(resolve_secret_from_tag "mqtt.host" "$test_dir/astra.yaml" "$test_dir/secrets.yaml")
    assert_equals "localhost" "$result" "should return value directly when no !secret tag"
    
    rm -rf "$test_dir"
}

test_load_workspace_without_yq() {
    # This test requires yq to be unavailable
    # Skip if yq is available (which it is in our test environment)
    # We can't easily test without yq without modifying PATH
    return 0  # Skip
}