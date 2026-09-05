#!/usr/bin/env bash

ok() {
    printf "✓ %s\n" "$1"
    sleep 0.18
}

fail() {
    printf "✗ %s\n" "$1"
    sleep 0.18
}

error() {
    printf "✗ %s\n" "$1"
    sleep 0.18
}

info() {
    printf "• %s\n" "$1"
    sleep 0.18
}

success() {
    printf "✔ %s\n" "$1"
    exit 0
}

die() {
    fail "$1"
    exit 1
}

prompt() {
    local label="$1"
    local default="$2"
    local value

    read -rp "$label [$default]: " value

    printf "%s" "${value:-$default}"
}

prompt_secret() {
    local label="$1"
    local value

    read -rsp "$label: " value
    echo >&2
    printf "%s" "$value"
}