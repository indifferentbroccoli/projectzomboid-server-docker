#!/bin/bash
# shellcheck source=scripts/functions.sh
source "/home/steam/server/functions.sh"

LogAction "Set file permissions"
usermod -o -u "${PUID}" steam
groupmod -o -g "${PGID}" steam
chown -R steam:steam /project-zomboid /project-zomboid-config /home/steam/

cat /branding

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

./start.sh &

# Process ID of su
killpid="$!"
wait "$killpid"