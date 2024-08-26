#!/bin/bash
# shellcheck source=scripts/functions.sh
source "/home/steam/server/functions.sh"

cat /branding

LogAction "Creating Folders"
mkdir -p /project-zomboid /project-zomboid-config

install

# shellcheck disable=SC2317
term_handler() {

    if ! shutdown_server; then
        # Does not save
        kill -SIGTERM "$(pidof ProjectZomboid64)"
    fi

    tail --pid="$killpid" -f 2>/dev/null
}

trap 'term_handler' SIGTERM

if [[ "$(id -u)" -eq 0 ]]; then
    su steam -c ./start.sh &
else
    ./start.sh &
fi
# Process ID of su
killpid="$!"
wait "$killpid"