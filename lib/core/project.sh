#!/usr/bin/env bash

is_development() {
    [ -L "$ASTRA_HOME" ]
}