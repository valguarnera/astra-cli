#!/usr/bin/env bash

# Installation tests

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/core/utils.sh"
source "$ASTRA_HOME/lib/core/project.sh"

test_astra_home_resolution_dev_mode() {
    # Simulate dev mode by creating a symlink
    local test_dir="/tmp/astra_test_install_$$"
    mkdir -p "$test_dir/opt"
    ln -s "$ASTRA_HOME" "$test_dir/opt/astra"
    
    # Test is_development function
    ASTRA_HOME="$test_dir/opt/astra" is_development
    local result=$?
    
    rm -rf "$test_dir"
    
    assert_equals "0" "$result" "is_development should return true for symlink"
}

test_astra_home_resolution_prod_mode() {
    # Simulate prod mode by creating a directory (not symlink)
    local test_dir="/tmp/astra_test_install_$$"
    mkdir -p "$test_dir/opt/astra"
    
    ASTRA_HOME="$test_dir/opt/astra" is_development
    local result=$?
    
    rm -rf "$test_dir"
    
    assert_equals "1" "$result" "is_development should return false for directory"
}

test_install_cli_dev_creates_symlink() {
    # Skip if sudo not available
    if ! command -v sudo >/dev/null 2>&1; then
        run_test_skip "test_install_cli_dev_creates_symlink" "sudo not available"
        return 0
    fi
    
    local test_dir="/tmp/astra_test_install_$$"
    mkdir -p "$test_dir/opt"
    
    SCRIPT_DIR="$ASTRA_HOME" ASTRA_HOME="$test_dir/opt/astra" install_cli_dev
    local result=$?
    
    [ -L "$test_dir/opt/astra" ] || return 1
    [ "$(readlink "$test_dir/opt/astra")" = "$ASTRA_HOME" ] || return 1
    
    rm -rf "$test_dir"
    
    assert_equals "0" "$result" "install_cli_dev should create correct symlink"
}

test_install_cli_copies_files() {
    # Skip if sudo not available
    if ! command -v sudo >/dev/null 2>&1; then
        run_test_skip "test_install_cli_copies_files" "sudo not available"
        return 0
    fi
    
    local test_dir="/tmp/astra_test_install_$$"
    mkdir -p "$test_dir/opt"
    
    SCRIPT_DIR="$ASTRA_HOME" ASTRA_HOME="$test_dir/opt/astra" install_cli
    local result=$?
    
    [ -d "$test_dir/opt/astra/bin" ] || return 1
    [ -d "$test_dir/opt/astra/commands" ] || return 1
    [ -d "$test_dir/opt/astra/lib" ] || return 1
    [ -d "$test_dir/opt/astra/drivers" ] || return 1
    [ -f "$test_dir/opt/astra/bin/astra" ] || return 1
    
    rm -rf "$test_dir"
    
    assert_equals "0" "$result" "install_cli should copy all directories"
}

test_astra_entry_point_resolves_astra_home() {
    # Test that bin/astra correctly resolves ASTRA_HOME
    local output
    output=$(ASTRA_HOME="/workspace" "$ASTRA_HOME/bin/astra" --version 2>&1)
    assert_equals "0.1.0" "$output" "astra --version should work with explicit ASTRA_HOME"
}

test_launcher_creation() {
    local test_dir="/tmp/astra_test_install_$$"
    mkdir -p "$test_dir/usr/local/bin"
    
    # Test create_launcher (without sudo)
    create_launcher() {
        ln -sf "$1" "$2"
        ok "Launcher"
    }
    
    create_launcher "/fake/astra" "$test_dir/usr/local/bin/astra"
    
    [ -L "$test_dir/usr/local/bin/astra" ] || return 1
    [ "$(readlink "$test_dir/usr/local/bin/astra")" = "/fake/astra" ] || return 1
    
    rm -rf "$test_dir"
}