#!/bin/bash
# shellcheck source=scripts/functions.sh
source "/home/steam/server/functions.sh"

LogAction "Set file permissions"

# check if the user is either unprivileged or allowed to run as root.
if [ $(id -u) -eq 0 ] && [ ! "${RUN_AS_ROOT,,}" = "true" ]; then
    LogError "Running as root is not allowed; configure user/group before running the container"
    exit 1
fi
if [ "${RUN_AS_ROOT,,}" = "true" ]; then
    LogWarn "Running as root, please consider configuring a unprivileged user/group before running the container"
fi

#chown -R steam:steam /project-zomboid /project-zomboid-config /home/steam/

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