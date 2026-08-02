#!/bin/bash

set -Eeuo pipefail

# Once start.sh writes the RCON configuration, require an actual server response.
if [ -f /home/steam/server/rcon.yml ]; then
    exec timeout --foreground 5s \
        rcon-cli -c /home/steam/server/rcon.yml players >/dev/null 2>&1
fi

# This fallback is useful only before RCON has been configured. Match the native
# launcher or the Java game-server main class; do not depend on one process name.
pgrep -af 'ProjectZomboid64|zombie[./]network[./]GameServer' >/dev/null
