#!/bin/bash
# shellcheck source=scripts/functions.sh
source "/home/steam/server/functions.sh"

# Configure RCON settings
cat >/home/steam/server/rcon.yaml  <<EOL
default:
  address: "127.0.0.1:${RCON_PORT}"
  password: "${ADMIN_PASSWORD}"
EOL

cd /project-zomboid || exit

LogAction "Starting server"
./start-server.sh \
    -cachedir="$CONFIG_DIR" \
    -adminusername "$ADMIN_USERNAME" \
    -adminpassword "$ADMIN_PASSWORD" \
    -ip "$BIND_IP" -port "$DEFAULT_PORT" \
    -servername "$SERVER_NAME" \
    -steamvac "$STEAM_VAC" "$USE_STEAM"
