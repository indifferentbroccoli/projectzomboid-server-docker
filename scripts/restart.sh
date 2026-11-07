#!/bin/bash
source "/home/steam/server/functions.sh"

RESTART_DELAY=${RESTART_DELAY:-5}

build_message() {
    local interval=$1
    local base="[Indifferent Broccoli]: Restarting the server"

    case $interval in
        1) echo "[Indifferent Broccoli]: Logout Now! Restarting the server in 1 minute." ;;
        *) echo "$base for a mod update in $interval minutes." ;;
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


minute_countdown() {
    LogWarn "Mods need update, warning then restarting server to update mods"
    local -a intervals

    for (( minute=$RESTART_DELAY; minute>=1; minute-- )); do
        rcon-server-msg "$(build_message "$minute")"

        send_discord_message "$(build_message "$minute")"

        case $minute in
            1) sleep 30 ;;
            *) sleep 60 ;;
        esac
    done
}

thirty_second_message() {
    local message="[Indifferent Broccoli]: Restarting the server in 30 seconds for mod updates."
    rcon-server-msg "$message"
    send_discord_message "$message"
    sleep 20
}

ten_second_countdown() {
    for (( second=10; second>=1; second-- )); do
        unit="seconds"; [ "$second" -eq 1 ] && unit="second"
        rcon-server-msg "[Indifferent Broccoli]: Restarting the server in $second $unit for mod updates."
        sleep 1
    done
}

mod_update_loop() {
    trap - SIGTERM

    interval=${CHECK_MODS_INTERVAL:-10}
    [[ $interval =~ ^[0-9]+$ ]] || interval=10
    (( interval < 10 )) && interval=10
    interval_seconds=$(( interval * 60 ))

    until rcon-check-mods-need-update && sleep 30 && do-mods-need-update; do
        sleep "$interval_seconds"
    done

    # Only gets here once mods need an update
    minute_countdown

    thirty_second_message

    ten_second_countdown

    shutdown_server
}