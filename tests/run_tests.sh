#!/usr/bin/env bash

# Simple test runner for ASTRA CLI
# Usage: ./run_tests.sh [test_file]

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASTRA_HOME="$(cd "$TEST_DIR/.." && pwd)"
export ASTRA_HOME

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

assert_equals() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-}"
    if [ "$expected" = "$actual" ]; then
        return 0
    else
        echo "  ASSERT FAILED: $msg"
        echo "    Expected: '$expected'"
        echo "    Actual:   '$actual'"
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local msg="${2:-}"
    if [ -n "$value" ]; then
        return 0
    else
        echo "  ASSERT FAILED: $msg - value is empty"
        return 1
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-}"
    if [ "$expected" = "$actual" ]; then
        return 0
    else
        echo "  ASSERT FAILED: $msg"
        echo "    Expected exit code: $expected"
        echo "    Actual exit code:   $actual"
        return 1
    fi
}

run_test() {
    local test_name="$1"
    local test_func="$2"
    echo "TEST: $test_name"
    if $test_func; then
        echo "  PASS"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  FAIL"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

run_test_skip() {
    local test_name="$1"
    local reason="$2"
    echo "TEST: $test_name (SKIPPED: $reason)"
    SKIP_COUNT=$((SKIP_COUNT + 1))
}

# Discover and run test functions
run_all_tests() {
    # Get all functions starting with test_
    local test_funcs
    test_funcs=$(declare -F | awk '{print $3}' | grep '^test_' | sort)
    
    for func in $test_funcs; do
        run_test "$func" "$func"
    done
}

# Load test files
for test_file in "$TEST_DIR"/test_*.sh; do
    if [ -f "$test_file" ]; then
        source "$test_file"
    fi
done

run_all_tests

echo ""
echo "=== TEST SUMMARY ==="
echo "Passed:  $PASS_COUNT"
echo "Failed:  $FAIL_COUNT"
echo "Skipped: $SKIP_COUNT"

if [ $FAIL_COUNT -gt 0 ]; then
    exit 1
fi