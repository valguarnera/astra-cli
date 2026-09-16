#!/usr/bin/env bash

source "$ASTRA_HOME/lib/core/ui.sh"
source "$ASTRA_HOME/lib/workspace.sh"

workspace_require
load_workspace

cd "$WORKSPACE/docker" || exit 1
docker compose up -d mosquitto