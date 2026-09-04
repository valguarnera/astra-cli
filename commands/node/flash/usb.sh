#!/usr/bin/env bash

# Uso:
# ./flash.sh cultivo01.yaml

ACTION="$1"

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIRMWARE_DIR="$PROJECT_ROOT/../node/"

#echo "$PROJECT_ROOT + $FIRMWARE_DIR"
cd "$FIRMWARE_DIR" || exit 1

docker run --rm \
  --device=/dev/ttyUSB0 \
  -v "${PWD}":/config \
  -it esphome/esphome \
  run "$1"
  