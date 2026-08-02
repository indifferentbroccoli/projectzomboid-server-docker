#!/bin/bash

set -Eeuo pipefail

# shellcheck source=scripts/functions.sh
source "/home/steam/server/functions.sh"

validate_image_architecture

LogAction "Set file permissions"

if [ -z "${PUID:-}" ] || [ -z "${PGID:-}" ]; then
    LogError "PUID and PGID not set. Please set these in the environment variables."
    exit 1
fi

usermod -o -u "${PUID}" steam
groupmod -o -g "${PGID}" steam

chown -R steam:steam /project-zomboid /project-zomboid-config /home/steam/

cat /branding

if [ ! -f "/project-zomboid/start-server.sh" ]; then
    LogWarn "start-server.sh not found in server-files, forcing install regardless of UPDATE_ON_START"
    install
elif [ "${UPDATE_ON_START:-true}" = "true" ]; then
    install
else
    LogWarn "UPDATE_ON_START is set to false, skipping server update from Steam"
fi

# This runs after every update because Steam may replace ProjectZomboid64.json.
configure_jvm

server_pid=""
shutdown_requested=0

# shellcheck disable=SC2317 # Invoked indirectly by signal traps.
term_handler() {
    local signal="$1"

    if [ "$shutdown_requested" -eq 1 ]; then
        return
    fi
    shutdown_requested=1

    LogAction "Received SIG${signal}; saving and stopping the server"

    if ! shutdown_server; then
        LogWarn "RCON save/quit failed; forwarding SIG${signal} to the server process group"
        terminate_server_process_group "$server_pid" "$signal"
    fi

    if ! wait_for_server_exit "$server_pid" "${SERVER_SHUTDOWN_TIMEOUT:-20}"; then
        LogWarn "Server did not exit before the shutdown timeout; forwarding SIGTERM"
        terminate_server_process_group "$server_pid" TERM
        wait_for_server_exit "$server_pid" 3 || true
    fi
}

trap 'term_handler TERM' SIGTERM
trap 'term_handler INT' SIGINT

check_admin_password

# A separate session gives the launcher and all of its descendants a process
# group that can be targeted without also terminating this supervisor.
setsid /home/steam/server/start.sh &
server_pid="$!"

server_status=0
if wait "$server_pid"; then
    server_status=0
else
    server_status="$?"
fi

# A handled Docker stop is a clean container exit even when wait was interrupted
# by the signal trap.
if [ "$shutdown_requested" -eq 1 ]; then
    exit 0
fi

exit "$server_status"
