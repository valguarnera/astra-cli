#!/usr/bin/env bash
source "$ASTRA_HOME/lib/core/help.sh"

COMMAND="$1"
ACTION="$2"

case "$COMMAND" in
  -h|--help)
    show_help
    ;;
  -v|--version)
    cat "$ASTRA_HOME/bin/VERSION"
    ;;
  init)
    shift
    "$ASTRA_HOME/commands/workspace/$COMMAND.sh" "$@"
    ;;
  node)
    shift 2
    "$ASTRA_HOME/commands/node/${ACTION}.sh" "$@"
    ;;
  flash)
    shift 2
    "$ASTRA_HOME/commands/node/flash/${ACTION}.sh" "$@"
    ;;
  broker|logs)
    shift 2
    "$ASTRA_HOME/commands/$COMMAND/${ACTION}.sh" "$@"
    ;;
  *)
    show_help
    exit 1
    ;;
esac