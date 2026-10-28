#!/bin/sh
set -eu

# Link the mounted ConfigMap without overwriting an existing user configuration.
config_dir="$HOME/.pi/agent"
mkdir -p "$config_dir"
if [ ! -e "$config_dir/models.json" ] && [ ! -L "$config_dir/models.json" ]; then
    ln -s /etc/pi/models.json "$config_dir/models.json"
fi

# Part 5 uses separate Pi state without changing the earlier exercises.
if [ -e /etc/pi/models-nono.json ]; then
    config_dir="$HOME/.pi/agent-nono"
    mkdir -p "$config_dir" "$HOME/.cache/go-build"
    if [ ! -e "$config_dir/models.json" ] && [ ! -L "$config_dir/models.json" ]; then
        ln -s /etc/pi/models-nono.json "$config_dir/models.json"
    fi
fi

exec "$@"
