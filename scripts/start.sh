#!/bin/bash
# shellcheck source=scripts/functions.sh
source "/home/steam/server/functions.sh"

# Configure RCON settings
cat >/home/steam/server/rcon.yml  <<EOL
default:
  address: "127.0.0.1:${RCON_PORT}"
  password: "${RCON_PASSWORD}"
EOL

cd /project-zomboid || exit

# if GENERATE_SETTINGS IS FALSE then we will not generate the settings
if [ "$GENERATE_SETTINGS" = "true" ]; then
  LogAction "Compiling settings"
  /home/steam/server/compile-settings.sh
fi

LogAction "Starting server"
./start-server.sh \
    -cachedir="$CONFIG_DIR" \
    -adminusername "$ADMIN_USERNAME" \
    -adminpassword "$ADMIN_PASSWORD" \
    -port "$DEFAULT_PORT" \
    -servername "$SERVER_NAME" \
    -steamvac "$STEAM_VAC" "$USE_STEAM"
