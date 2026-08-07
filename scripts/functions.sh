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

  local args=(-app 380870 -dir /project-zomboid -validate)

  if [ -n "${SERVER_BRANCH}" ]; then
    LogInfo "Installing branch: ${SERVER_BRANCH}"
    args+=(-branch "${SERVER_BRANCH}")
  else
    LogInfo "Installing stable branch"
  fi

  if ! /depotdownloader/DepotDownloader "${args[@]}"; then
    LogError "Failed to install server"
    exit 1
  fi

  chmod +x /project-zomboid/start-server.sh /project-zomboid/ProjectZomboid64 2>/dev/null
  find /project-zomboid/jre64/bin /project-zomboid/jre/bin \
    -type f -exec chmod +x {} + 2>/dev/null

  LogSuccess "Server install complete"
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

# Set or insert if missing
set_ini_value() {
    local file="$1"
    local key="$2"
    local value="$3"

    if grep -q "^${key}=" "$file" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    else
        echo "${key}=${value}" >> "$file"
    fi
}

# Check if the admin password has been changed
check_admin_password() {
    if [ -z "${ADMIN_PASSWORD}" ] ||  [ "${ADMIN_PASSWORD}" == "admin" ] || [ "${ADMIN_PASSWORD}" == "CHANGEME" ]; then
        LogWarn "ADMIN_PASSWORD is not set or is insecure. Please set this in the environment variables."
    fi
}

configure_vm_args() {
    if [ -z "${VM_ARGS}" ]; then
        return 0
    fi

    local json_file="/project-zomboid/ProjectZomboid64.json"

    if [ ! -f "$json_file" ]; then
        LogError "ProjectZomboid64.json not found at $json_file"
        return 1
    fi

    LogAction "Adding extra VM args"

    local arg

    for arg in $(printf '%s' "${VM_ARGS}" | tr -d "[:space:]\"'" | tr ',' ' '); do
        if jq -e --arg arg "$arg" 'any(.vmArgs[]; . == $arg)' "$json_file" >/dev/null; then
            continue
        fi

        jq --arg arg "$arg" '.vmArgs += [$arg]' "$json_file" > "$json_file.tmp" &&
            mv "$json_file.tmp" "$json_file"
    done
    return 0
}

# Configure JVM memory settings in ProjectZomboid64.json
configure_memory() {
    local json_file="/project-zomboid/ProjectZomboid64.json"
    local memory_xmx_gb=${MEMORY_XMX_GB:-8}
    local memory_xms_gb=${MEMORY_XMS_GB:-""}
    
    if [ ! -f "$json_file" ]; then
        LogError "ProjectZomboid64.json not found at $json_file"
        return 1
    fi
    
    LogAction "Configuring memory settings to ${memory_xmx_gb}GB"
    
    # Update Xmx
    jq ".vmArgs |= map(if startswith(\"-Xmx\") then \"-Xmx${memory_xmx_gb}G\" else . end)" "$json_file" > "$json_file.tmp" && mv "$json_file.tmp" "$json_file"
    
    # Update or add Xms if specified
    if [ -n "$memory_xms_gb" ]; then
        jq ".vmArgs |= if (map(select(startswith(\"-Xms\"))) | length) > 0 then map(if startswith(\"-Xms\") then \"-Xms${memory_xms_gb}G\" else . end) else . + [\"-Xms${memory_xms_gb}G\"] end" "$json_file" > "$json_file.tmp" && mv "$json_file.tmp" "$json_file"
        LogSuccess "Xmx: ${memory_xmx_gb}GB, Xms: ${memory_xms_gb}GB"
    else
        jq ".vmArgs |= map(select(startswith(\"-Xms\") | not))" "$json_file" > "$json_file.tmp" && mv "$json_file.tmp" "$json_file"
        LogSuccess "Xmx: ${memory_xmx_gb}GB"
    fi
    return 0
}
