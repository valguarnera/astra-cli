#!/usr/bin/env bash

# Router tests

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/core/help.sh"
source "$ASTRA_HOME/lib/core/router.sh"

test_router_help_command() {
    local output
    output=$(show_help 2>&1)
    assert_not_empty "$output" "show_help should produce output"
    # Check that help contains expected commands
    echo "$output" | grep -q "astra init" || return 1
    echo "$output" | grep -q "astra broker up" || return 1
    echo "$output" | grep -q "astra node create" || return 1
    echo "$output" | grep -q "astra node list" || return 1
    echo "$output" | grep -q "astra node delete" || return 1
}

test_router_version_command() {
    local output
    output=$("$ASTRA_HOME/bin/astra" --version 2>&1)
    assert_equals "0.1.0" "$output" "version should be 0.1.0"
}

test_router_invalid_command() {
    # Test that invalid command shows help and exits with error
    local output
    output=$("$ASTRA_HOME/bin/astra" invalidcommand 2>&1)
    local exit_code=$?
    
    assert_equals "1" "$exit_code" "invalid command should exit with code 1"
    echo "$output" | grep -q "ASTRA CLI" || return 1
}

test_router_dispatch_node_create() {
    # Test that node create dispatches to correct script
    # We can't easily test the actual dispatch without mocking, but we can verify the script exists
    [ -f "$ASTRA_HOME/commands/node/create.sh" ] || return 1
    [ -x "$ASTRA_HOME/commands/node/create.sh" ] || return 1
}

test_router_dispatch_node_list() {
    [ -f "$ASTRA_HOME/commands/node/list.sh" ] || return 1
    [ -x "$ASTRA_HOME/commands/node/list.sh" ] || return 1
}

test_router_dispatch_node_delete() {
    [ -f "$ASTRA_HOME/commands/node/delete.sh" ] || return 1
    [ -x "$ASTRA_HOME/commands/node/delete.sh" ] || return 1
}

test_router_dispatch_broker_commands() {
    [ -f "$ASTRA_HOME/commands/broker/up.sh" ] || return 1
    [ -f "$ASTRA_HOME/commands/broker/down.sh" ] || return 1
    [ -f "$ASTRA_HOME/commands/broker/state.sh" ] || return 1
}

test_help_matches_filesystem() {
    # Verify that all commands in help have corresponding scripts
    local help_output
    help_output=$(show_help 2>&1)
    
    # Check node create
    echo "$help_output" | grep -q "astra node create" || return 1
    [ -f "$ASTRA_HOME/commands/node/create.sh" ] || return 1
    
    # Check node list
    echo "$help_output" | grep -q "astra node list" || return 1
    [ -f "$ASTRA_HOME/commands/node/list.sh" ] || return 1
    
    # Check node delete
    echo "$help_output" | grep -q "astra node delete" || return 1
    [ -f "$ASTRA_HOME/commands/node/delete.sh" ] || return 1
    
    # Check broker commands
    echo "$help_output" | grep -q "astra broker up" || return 1
    [ -f "$ASTRA_HOME/commands/broker/up.sh" ] || return 1
    
    echo "$help_output" | grep -q "astra broker down" || return 1
    [ -f "$ASTRA_HOME/commands/broker/down.sh" ] || return 1
    
    echo "$help_output" | grep -q "astra broker state" || return 1
    [ -f "$ASTRA_HOME/commands/broker/state.sh" ] || return 1
}