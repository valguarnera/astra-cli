#!/usr/bin/env bash

# Tests for checks.sh functions

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/core/checks.sh"

# Mock hostname -I for testing
# We'll override the hostname command in a subshell

test_detect_lan_ip_finds_192_168() {
    # Mock hostname -I to return a 192.168.* IP
    local test_dir="/tmp/astra_test_lan_$$"
    mkdir -p "$test_dir"
    
    # Create a mock hostname script
    cat > "$test_dir/hostname" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "-I" ]; then
    echo "172.17.0.1 192.168.1.100 10.0.0.1"
fi
EOF
    chmod +x "$test_dir/hostname"
    
    # Run detect_lan_ip with mocked PATH
    local output
    output=$(PATH="$test_dir:$PATH" ASTRA_HOME="$ASTRA_HOME" bash -c 'source '"$ASTRA_HOME"'/lib/core/checks.sh; detect_lan_ip')
    local exit_code=$?
    
    rm -rf "$test_dir"
    
    assert_equals "0" "$exit_code" "detect_lan_ip should succeed when 192.168.* present"
    assert_equals "192.168.1.100" "$output" "detect_lan_ip should return the 192.168.* IP"
}

test_detect_lan_ip_ignores_loopback() {
    local test_dir="/tmp/astra_test_lan_$$"
    mkdir -p "$test_dir"
    
    cat > "$test_dir/hostname" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "-I" ]; then
    echo "127.0.0.1 172.17.0.1"
fi
EOF
    chmod +x "$test_dir/hostname"
    
    local output
    output=$(PATH="$test_dir:$PATH" ASTRA_HOME="$ASTRA_HOME" bash -c 'source '"$ASTRA_HOME"'/lib/core/checks.sh; detect_lan_ip')
    local exit_code=$?
    
    rm -rf "$test_dir"
    
    assert_equals "1" "$exit_code" "detect_lan_ip should fail when only loopback present"
}

test_detect_lan_ip_ignores_docker_when_192_168_exists() {
    local test_dir="/tmp/astra_test_lan_$$"
    mkdir -p "$test_dir"
    
    cat > "$test_dir/hostname" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "-I" ]; then
    echo "172.17.0.1 192.168.0.50 172.18.0.1"
fi
EOF
    chmod +x "$test_dir/hostname"
    
    local output
    output=$(PATH="$test_dir:$PATH" ASTRA_HOME="$ASTRA_HOME" bash -c 'source '"$ASTRA_HOME"'/lib/core/checks.sh; detect_lan_ip')
    local exit_code=$?
    
    rm -rf "$test_dir"
    
    assert_equals "0" "$exit_code" "detect_lan_ip should succeed"
    assert_equals "192.168.0.50" "$output" "detect_lan_ip should prefer 192.168.* over Docker IPs"
}

test_detect_lan_ip_ignores_ipv6() {
    local test_dir="/tmp/astra_test_lan_$$"
    mkdir -p "$test_dir"
    
    cat > "$test_dir/hostname" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "-I" ]; then
    echo "::1 fe80::1 192.168.1.10"
fi
EOF
    chmod +x "$test_dir/hostname"
    
    local output
    output=$(PATH="$test_dir:$PATH" ASTRA_HOME="$ASTRA_HOME" bash -c 'source '"$ASTRA_HOME"'/lib/core/checks.sh; detect_lan_ip')
    local exit_code=$?
    
    rm -rf "$test_dir"
    
    assert_equals "0" "$exit_code" "detect_lan_ip should succeed with IPv6 present"
    assert_equals "192.168.1.10" "$output" "detect_lan_ip should return IPv4 192.168.*"
}

test_get_default_mqtt_host_returns_lan_ip() {
    local test_dir="/tmp/astra_test_lan_$$"
    mkdir -p "$test_dir"
    
    cat > "$test_dir/hostname" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "-I" ]; then
    echo "192.168.1.100"
fi
EOF
    chmod +x "$test_dir/hostname"
    
    local output
    output=$(PATH="$test_dir:$PATH" ASTRA_HOME="$ASTRA_HOME" bash -c 'source '"$ASTRA_HOME"'/lib/core/checks.sh; get_default_mqtt_host')
    local exit_code=$?
    
    rm -rf "$test_dir"
    
    assert_equals "0" "$exit_code" "get_default_mqtt_host should succeed when LAN IP found"
    assert_equals "192.168.1.100" "$output" "get_default_mqtt_host should return the LAN IP"
}

test_get_default_mqtt_host_fallback_to_localhost() {
    local test_dir="/tmp/astra_test_lan_$$"
    mkdir -p "$test_dir"
    
    cat > "$test_dir/hostname" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "-I" ]; then
    echo "172.17.0.1 172.18.0.1"
fi
EOF
    chmod +x "$test_dir/hostname"
    
    local output
    output=$(PATH="$test_dir:$PATH" ASTRA_HOME="$ASTRA_HOME" bash -c 'source '"$ASTRA_HOME"'/lib/core/checks.sh; get_default_mqtt_host')
    local exit_code=$?
    
    rm -rf "$test_dir"
    
    assert_equals "1" "$exit_code" "get_default_mqtt_host should fail when no LAN IP"
    assert_equals "localhost" "$output" "get_default_mqtt_host should return localhost as fallback"
}

test_get_default_mqtt_host_warns_on_stderr() {
    local test_dir="/tmp/astra_test_lan_$$"
    mkdir -p "$test_dir"
    
    cat > "$test_dir/hostname" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "-I" ]; then
    echo "172.17.0.1"
fi
EOF
    chmod +x "$test_dir/hostname"
    
    # Capture stderr separately
    local stderr_output
    stderr_output=$(PATH="$test_dir:$PATH" ASTRA_HOME="$ASTRA_HOME" bash -c 'source '"$ASTRA_HOME"'/lib/core/checks.sh; get_default_mqtt_host' 2>&1 >/dev/null)
    
    rm -rf "$test_dir"
    
    echo "$stderr_output" | grep -q "No se detectó IP LAN" || return 1
    echo "$stderr_output" | grep -q "Para hardware físico" || return 1
}

# Test check_lan_connectivity with 192.168.* IP
test_check_lan_connectivity_with_lan() {
    local test_dir="/tmp/astra_test_lan_conn_$$"
    mkdir -p "$test_dir"
    
    cat > "$test_dir/hostname" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "-I" ]; then
    echo "192.168.1.100"
fi
EOF
    chmod +x "$test_dir/hostname"
    
    # Mock ping to succeed
    cat > "$test_dir/ping" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" = "-c" && "$2" = "1" && "$3" = "-W" && "$4" = "1" && "$5" = "192.168.1.1" ]]; then
    exit 0
fi
exit 1
EOF
    chmod +x "$test_dir/ping"
    
    local output
    output=$(PATH="$test_dir:$PATH" ASTRA_HOME="$ASTRA_HOME" bash -c 'source '"$ASTRA_HOME"'/lib/core/checks.sh; check_lan_connectivity' 2>&1)
    local exit_code=$?
    
    rm -rf "$test_dir"
    
    assert_equals "0" "$exit_code" "check_lan_connectivity should succeed with valid LAN"
    echo "$output" | grep -q "IP LAN: 192.168.1.100" || return 1
    echo "$output" | grep -q "Gateway 192.168.1.1 alcanzable" || return 1
}

# Test check_lan_connectivity without 192.168.* IP
test_check_lan_connectivity_no_lan() {
    local test_dir="/tmp/astra_test_lan_conn_$$"
    mkdir -p "$test_dir"
    
    cat > "$test_dir/hostname" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "-I" ]; then
    echo "172.17.0.1 172.18.0.1"
fi
EOF
    chmod +x "$test_dir/hostname"
    
    local output
    output=$(PATH="$test_dir:$PATH" ASTRA_HOME="$ASTRA_HOME" bash -c 'source '"$ASTRA_HOME"'/lib/core/checks.sh; check_lan_connectivity' 2>&1)
    local exit_code=$?
    
    rm -rf "$test_dir"
    
    assert_equals "1" "$exit_code" "check_lan_connectivity should fail when no 192.168.* IP"
    echo "$output" | grep -q "No se detectó IP LAN" || return 1
}

# Test check_mqtt_broker_connectivity with valid host
test_check_mqtt_broker_connectivity_success() {
    local test_dir="/tmp/astra_test_mqtt_$$"
    mkdir -p "$test_dir"
    
    # Mock nc to succeed
    cat > "$test_dir/nc" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" = "-z" && "$2" = "-w" && "$3" = "2" && "$4" = "192.168.1.100" && "$5" = "1883" ]]; then
    exit 0
fi
exit 1
EOF
    chmod +x "$test_dir/nc"
    
    local output
    output=$(PATH="$test_dir:$PATH" ASTRA_HOME="$ASTRA_HOME" bash -c 'source '"$ASTRA_HOME"'/lib/core/checks.sh; check_mqtt_broker_connectivity "192.168.1.100" 1883' 2>&1)
    local exit_code=$?
    
    rm -rf "$test_dir"
    
    assert_equals "0" "$exit_code" "check_mqtt_broker_connectivity should succeed with reachable broker"
    echo "$output" | grep -q "Broker MQTT en 192.168.1.100:1883 accesible" || return 1
}

# Test check_mqtt_broker_connectivity failure
test_check_mqtt_broker_connectivity_failure() {
    local test_dir="/tmp/astra_test_mqtt_$$"
    mkdir -p "$test_dir"
    
    # Mock nc to fail
    cat > "$test_dir/nc" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$test_dir/nc"
    
    local output
    output=$(PATH="$test_dir:$PATH" ASTRA_HOME="$ASTRA_HOME" bash -c 'source '"$ASTRA_HOME"'/lib/core/checks.sh; check_mqtt_broker_connectivity "192.168.1.100" 1883' 2>&1)
    local exit_code=$?
    
    rm -rf "$test_dir"
    
    assert_equals "1" "$exit_code" "check_mqtt_broker_connectivity should fail with unreachable broker"
    echo "$output" | grep -q "no accesible" || return 1
}

# Test check_mqtt_broker_connectivity with localhost (should skip)
test_check_mqtt_broker_connectivity_localhost() {
    local output
    output=$(ASTRA_HOME="$ASTRA_HOME" bash -c 'source '"$ASTRA_HOME"'/lib/core/checks.sh; check_mqtt_broker_connectivity "localhost" 1883' 2>&1)
    local exit_code=$?
    
    assert_equals "1" "$exit_code" "check_mqtt_broker_connectivity should skip for localhost"
    echo "$output" | grep -q "localhost" || return 1
}