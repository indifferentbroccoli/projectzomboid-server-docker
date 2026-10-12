#!/bin/bash
# shellcheck source=scripts/functions.sh
source "/home/steam/server/functions.sh"

LogAction "Set file permissions"

# if the user has not defined a PUID and PGID, throw an error and exit
if [ -z "${PUID}" ] || [ -z "${PGID}" ]; then
    LogError "PUID and PGID not set. Please set these in the environment variables."
    exit 1
else
    usermod -o -u "${PUID}" steam
    groupmod -o -g "${PGID}" steam
fi

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

# Configure memory settings
configure_memory

# Append extra VM args if specified
configure_vm_args

# Create lowercase symlinks for mods if enabled
fix_mod_case

# shellcheck disable=SC2317
term_handler() {
    if ! shutdown_server; then
        # Does not save
        kill -SIGTERM "$(pidof ProjectZomboid64)"
    fi
    tail --pid="$killpid" -f 2>/dev/null
}

trap 'term_handler' SIGTERM

# Check config for warnings
check_admin_password

# Start the server
./start.sh &

# Process ID of su
killpid="$!"
wait "$killpid"