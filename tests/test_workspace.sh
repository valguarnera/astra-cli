#!/usr/bin/env bash

# Workspace tests

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/workspace.sh"

test_workspace_find_from_subdirectory() {
    local test_dir="/tmp/astra_test_ws_$$"
    mkdir -p "$test_dir/subdir1/subdir2"
    echo "name: test" > "$test_dir/astra.yaml"
    echo "mqtt: {host: localhost}" >> "$test_dir/astra.yaml"
    echo "wifi: {ssid: test, password: test}" >> "$test_dir/astra.yaml"
    
    cd "$test_dir/subdir1/subdir2"
    workspace_find
    local result="$WORKSPACE"
    cd - >/dev/null
    
    rm -rf "$test_dir"
    
    assert_equals "$test_dir" "$result" "workspace_find should find workspace from subdirectory"
}

test_workspace_find_not_found_outside() {
    local test_dir="/tmp/astra_test_ws_$$"
    mkdir -p "$test_dir/workspace"
    echo "name: test" > "$test_dir/workspace/astra.yaml"
    echo "mqtt: {host: localhost}" >> "$test_dir/workspace/astra.yaml"
    echo "wifi: {ssid: test, password: test}" >> "$test_dir/workspace/astra.yaml"
    
    cd "$test_dir"
    workspace_find
    local exit_code=$?
    cd - >/dev/null
    
    rm -rf "$test_dir"
    
    assert_equals "1" "$exit_code" "workspace_find should fail outside workspace"
}

test_workspace_find_returns_absolute_path() {
    local test_dir="/tmp/astra_test_ws_$$"
    mkdir -p "$test_dir/subdir"
    echo "name: test" > "$test_dir/astra.yaml"
    echo "mqtt: {host: localhost}" >> "$test_dir/astra.yaml"
    echo "wifi: {ssid: test, password: test}" >> "$test_dir/astra.yaml"
    
    cd "$test_dir/subdir"
    workspace_find
    local result="$WORKSPACE"
    cd - >/dev/null
    
    rm -rf "$test_dir"
    
    # Check that result is absolute path
    case "$result" in
        /*) 
            assert_equals "$test_dir" "$result" "workspace_find should return absolute path"
            ;;
        *)
            echo "  ASSERT FAILED: workspace_find returned relative path: $result"
            return 1
            ;;
    esac
}

test_workspace_require_exits_on_missing() {
    # This test would exit the script, so we test in a subshell
    (
        source "$ASTRA_HOME/lib/core/ui.sh"
        source "$ASTRA_HOME/lib/workspace.sh"
        cd /tmp
        workspace_require
    )
    local exit_code=$?
    
    assert_equals "1" "$exit_code" "workspace_require should exit with code 1 when no workspace"
}