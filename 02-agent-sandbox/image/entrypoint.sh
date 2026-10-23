#!/bin/sh
set -eu

# Link the mounted ConfigMap without overwriting an existing user configuration.
config_dir="$HOME/.pi/agent"
mkdir -p "$config_dir"
if [ ! -e "$config_dir/models.json" ] && [ ! -L "$config_dir/models.json" ]; then
    ln -s /etc/pi/models.json "$config_dir/models.json"
fi

exec "$@"
