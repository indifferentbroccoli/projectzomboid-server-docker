#!/bin/bash
source "/home/steam/server/functions.sh"

RESTART_DELAY=${RESTART_DELAY:-15}
INTERVAL_COUNT=$(( (RESTART_DELAY + 4) / 5 ))
TOTAL_DELAY=$(( INTERVAL_COUNT * 5 ))

get_all_intervals() {
    local x y
    for (( x = 0; x < INTERVAL_COUNT; x++ )); do
        y=$(( TOTAL_DELAY - x * 5 ))
        (( y != 0 )) && echo "$y"
    done
    echo 1
}

build_message() {
    local interval=$1
    local base="Restarting the server for a mod update"

    case $interval in
        1) echo "Logout Now! $base in 1 minute." ;;
        *) echo "$base in $interval minutes." ;;
    esac
}

rcon-check-mods-need-update() {
    LogInfo "Sending rcon command to check if mods need updated"
    rcon-call "CheckModsNeedUpdate"
}

do-mods-need-update() {
    LogInfo "Checking logs for mod update check result"
    grep -qs "CheckModsNeedUpdate: Mods need update" $CONFIG_DIR/Logs/*DebugLog*
}


run_restart_countdown() {
    LogWarn "Mods need update, warning then restarting server to update mods"
    local -a intervals
    local i
    mapfile -t intervals < <(get_all_intervals)

    for i in "${intervals[@]}"; do
        rcon-server-msg "$(build_message "$i")"
        case $i in
            1) sleep 30 ;;
            *) sleep 300 ;;
        esac
    done
}

mod_update_loop() {
    trap - SIGTERM

    until rcon-check-mods-need-update && sleep 30 && do-mods-need-update; do
        sleep 600
    done

    # Only gets here once mods need an update
    run_restart_countdown

    sleep 30

    shutdown_server
}