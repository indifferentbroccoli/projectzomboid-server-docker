#!/bin/bash

set -Eeuo pipefail

# shellcheck source=scripts/functions.sh
source "/home/steam/server/functions.sh"

LogAction "Configuring RCON settings"
rcon_password_json="$(jq -Rn --arg value "${RCON_PASSWORD:-}" '$value')"
rcon_tmp="$(mktemp /home/steam/server/rcon.yml.tmp.XXXXXX)"
printf 'default:\n  address: "127.0.0.1:%s"\n  password: %s\n' \
    "${RCON_PORT}" "$rcon_password_json" > "$rcon_tmp"
chmod 0600 "$rcon_tmp"
mv -f "$rcon_tmp" /home/steam/server/rcon.yml

config_file="$CONFIG_DIR/Server/${SERVER_NAME}.ini"
mkdir -p "$(dirname "$config_file")" "$CONFIG_DIR/mods"
touch "$config_file"

set_ini_value "$config_file" DefaultPort "${DEFAULT_PORT}"
set_ini_value "$config_file" UDPPort "${UDP_PORT}"
set_ini_value "$config_file" RCONPort "${RCON_PORT}"
set_ini_value "$config_file" RCONPassword "${RCON_PASSWORD:-}"
if [ -n "${MAX_PLAYERS:-}" ]; then
    set_ini_value "$config_file" MaxPlayers "${MAX_PLAYERS}"
fi

declare -a server_args
build_server_args server_args

cd /project-zomboid

arch="$(container_arch)"
LogAction "Starting server on ${arch}"

case "$arch" in
    amd64)
        # Preserve the native launch path used by the existing image.
        exec ./start-server.sh "${server_args[@]}"
        ;;
    arm64)
        if [ -z "${PZ_EMULATOR:-}" ]; then
            export PZ_EMULATOR=box64
        fi
        exec /home/steam/server/start-box64.sh "${server_args[@]}"
        ;;
esac
