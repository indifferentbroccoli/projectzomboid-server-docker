#!/bin/bash

#================
# Log Definitions
#================
export LINE='\n'                        # Line Break
export RESET='\033[0m'                  # Text Reset
export WhiteText='\033[0;37m'           # White

# Bold
export RedBoldText='\033[1;31m'         # Red
export GreenBoldText='\033[1;32m'       # Green
export YellowBoldText='\033[1;33m'      # Yellow
export CyanBoldText='\033[1;36m'        # Cyan
#================
# End Log Definitions
#================

LogInfo() {
  Log "$1" "$WhiteText"
}
LogWarn() {
  Log "$1" "$YellowBoldText"
}
LogError() {
  Log "$1" "$RedBoldText"
}
LogSuccess() {
  Log "$1" "$GreenBoldText"
}
LogAction() {
  Log "$1" "$CyanBoldText" "====" "===="
}
Log() {
  local message="$1"
  local color="$2"
  local prefix="$3"
  local suffix="$4"
  printf "$color%s$RESET$LINE" "$prefix$message$suffix"
}

install() {
  LogAction "Starting server install"
  /home/steam/steamcmd/steamcmd.sh +runscript /home/steam/server/install.scmd
}

# rcon call
rcon-call() {
  local args="$1"
  rcon-cli -c /home/steam/server/rcon.yml "$args"
}

# Saves the server
# Returns 0 if it saves
# Returns 1 if it is not able to save
save_server() {
    local return_val=0
    if ! rcon-call save; then
        return_val=1
    fi
    return "$return_val"
}

# Saves then shutdowns the server
# Returns 0 if it is shutdown
# Returns 1 if it is not able to be shutdown
shutdown_server() {
    local return_val=0
    # Do not shutdown if not able to save
    if save_server; then
        if ! rcon-call "quit"; then
            return_val=1
        fi
    else
        return_val=1
    fi
    return "$return_val"
}

# Check if the admin password has been changed
check_admin_password() {
    if [ -z "${ADMIN_PASSWORD}" ] ||  [ "${ADMIN_PASSWORD}" == "admin" ] || [ "${ADMIN_PASSWORD}" == "CHANGEME" ]; then
        LogWarn "ADMIN_PASSWORD is not set or is insecure. Please set this in the environment variables."
    fi
}
