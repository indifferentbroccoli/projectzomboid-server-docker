#!/bin/bash

set -Eeuo pipefail

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
    local prefix="${3:-}"
    local suffix="${4:-}"
    printf '%b%s%b\n' "$color" "$prefix$message$suffix" "$RESET"
}

# Return the architecture of the running userspace, not a user-provided value.
container_arch() {
    case "$(uname -m)" in
        x86_64|amd64) printf '%s\n' amd64 ;;
        aarch64|arm64) printf '%s\n' arm64 ;;
        *)
            LogError "Unsupported container architecture: $(uname -m)"
            return 1
            ;;
    esac
}

validate_image_architecture() {
    local actual_arch
    actual_arch="$(container_arch)"

    if [ -n "${IMAGE_ARCH:-}" ] && [ "$actual_arch" != "$IMAGE_ARCH" ]; then
        LogError "Image architecture mismatch: built for ${IMAGE_ARCH}, running as ${actual_arch}"
        return 1
    fi
}

install() {
    LogAction "Starting server install"

    # The PZ server is x86-64 on both image architectures. Pin both OS and
    # payload architecture so DepotDownloader never infers them from the host.
    local args=(-app 380870 -dir /project-zomboid -os linux -osarch 64 -validate)

    if [ -n "${SERVER_BRANCH:-}" ]; then
        LogInfo "Installing branch: ${SERVER_BRANCH}"
        args+=(-branch "${SERVER_BRANCH}")
    else
        LogInfo "Installing stable branch"
    fi

    if ! /depotdownloader/DepotDownloader "${args[@]}"; then
        LogError "Failed to install server"
        return 1
    fi

    chmod +x /project-zomboid/start-server.sh /project-zomboid/ProjectZomboid64 2>/dev/null || true

    local java_dir
    for java_dir in /project-zomboid/jre64/bin /project-zomboid/jre/bin; do
        if [ -d "$java_dir" ]; then
            find "$java_dir" -type f -exec chmod +x {} +
        fi
    done
    find /project-zomboid/jre64/lib /project-zomboid/jre/lib \
        -maxdepth 1 -type f -name jspawnhelper -exec chmod +x {} + 2>/dev/null || true

    LogSuccess "Server install complete"
}

# rcon call
rcon-call() {
    timeout --foreground "${RCON_COMMAND_TIMEOUT:-5}s" \
        rcon-cli -c /home/steam/server/rcon.yml "$@"
}

# Saves the server. Returns non-zero if RCON is not ready or save fails.
save_server() {
    rcon-call save
}

# Save first, then ask the game server to quit.
shutdown_server() {
    save_server && rcon-call quit
}

wait_for_server_exit() {
    local pid="$1"
    local wait_seconds="$2"

    timeout --foreground "${wait_seconds}s" tail --pid="$pid" -f /dev/null 2>/dev/null
}

terminate_server_process_group() {
    local pid="$1"
    local signal="${2:-TERM}"

    # start.sh is launched with setsid, so its PID is also its process-group ID.
    kill -s "$signal" -- "-$pid" 2>/dev/null || kill -s "$signal" "$pid" 2>/dev/null || true
}

# Set or insert if missing.
set_ini_value() {
    local file="$1"
    local key="$2"
    local value="$3"
    local tmp_file line
    local found=0

    if [[ "$value" == *$'\n'* ]]; then
        LogError "INI value for ${key} must not contain a newline"
        return 1
    fi

    tmp_file="$(mktemp "${file}.tmp.XXXXXX")"
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" == "${key}="* ]]; then
            if [ "$found" -eq 0 ]; then
                printf '%s=%s\n' "$key" "$value" >> "$tmp_file"
                found=1
            fi
        else
            printf '%s\n' "$line" >> "$tmp_file"
        fi
    done < "$file"

    if [ "$found" -eq 0 ]; then
        printf '%s=%s\n' "$key" "$value" >> "$tmp_file"
    fi

    chmod --reference="$file" "$tmp_file"
    mv -f "$tmp_file" "$file"
}

# Check if the admin password has been changed.
check_admin_password() {
    if [ -z "${ADMIN_PASSWORD:-}" ] || [ "${ADMIN_PASSWORD}" = "admin" ] || [ "${ADMIN_PASSWORD}" = "CHANGEME" ]; then
        LogWarn "ADMIN_PASSWORD is not set or is insecure. Please set this in the environment variables."
    fi
}

json_array_from_csv() {
    jq -cn --arg value "$1" \
        '$value | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0))'
}

json_array_without_gc() {
    local args_json="$1"
    jq -cn --argjson args "$args_json" \
        '$args | map(select(test("^-XX:\\+Use(Z|G1|Serial|Parallel|Shenandoah|Epsilon)GC$") | not))'
}

arm64_profile_args() {
    case "$1" in
        default)
            jq -cn '["-Dpz.docker.arm64.profile=default", "-XX:+UseG1GC"]'
            ;;
        compatibility)
            jq -cn '[
                "-Dpz.docker.arm64.profile=compatibility",
                "-XX:+UseSerialGC",
                "-XX:-UseCompressedOops",
                "-XX:-UseCompressedClassPointers",
                "-XX:-TieredCompilation"
            ]'
            ;;
        interpreter)
            jq -cn '[
                "-Dpz.docker.arm64.profile=interpreter",
                "-XX:+UseSerialGC",
                "-XX:-UseCompressedOops",
                "-XX:-UseCompressedClassPointers",
                "-Xint"
            ]'
            ;;
        none)
            jq -cn '[]'
            ;;
        *)
            LogError "Unknown ARM64_JVM_PROFILE '$1' (expected default, compatibility, interpreter, or none)"
            return 1
            ;;
    esac
}

# Apply every project-managed JVM option in one atomic JSON update. A sidecar
# file records exactly which non-memory options were inserted, allowing a later
# restart (or architecture switch) to remove only this project's prior values.
configure_jvm() {
    local server_dir="${PZ_SERVER_DIR:-/project-zomboid}"
    local json_file="${server_dir}/ProjectZomboid64.json"
    local state_file="${CONFIG_DIR}/.pz-docker-managed-vmargs.json"
    local memory_xmx_gb="${MEMORY_XMX_GB:-8}"
    local memory_xms_gb="${MEMORY_XMS_GB:-}"
    local arch
    arch="$(container_arch)"

    if [ ! -f "$json_file" ]; then
        LogError "ProjectZomboid64.json not found at $json_file"
        return 1
    fi

    if ! jq -e '.vmArgs | type == "array" and all(.[]; type == "string")' "$json_file" >/dev/null; then
        LogError "Invalid vmArgs in $json_file"
        return 1
    fi

    if ! [[ "$memory_xmx_gb" =~ ^[0-9]+([.][0-9]+)?$ ]] || \
       { [ -n "$memory_xms_gb" ] && ! [[ "$memory_xms_gb" =~ ^[0-9]+([.][0-9]+)?$ ]]; }; then
        LogError "MEMORY_XMX_GB and MEMORY_XMS_GB must be numeric gigabyte values"
        return 1
    fi

    local previous_managed='[]'
    local previous_replaced='[]'
    if [ -f "$state_file" ]; then
        if jq -e '
            (.managedArgs | type == "array" and all(.[]; type == "string")) and
            ((.replacedArgs // []) | type == "array" and all(.[]; type == "string"))
        ' "$state_file" >/dev/null 2>&1; then
            previous_managed="$(jq -c '.managedArgs' "$state_file")"
            previous_replaced="$(jq -c '.replacedArgs // []' "$state_file")"
        else
            LogWarn "Ignoring invalid managed JVM state at $state_file"
        fi
    fi

    local vm_args_json arm_vm_args_json requested_args
    vm_args_json="$(json_array_from_csv "${VM_ARGS:-}")"
    arm_vm_args_json='[]'
    if [ "$arch" = arm64 ]; then
        arm_vm_args_json="$(json_array_from_csv "${ARM64_VM_ARGS:-}")"
    fi
    requested_args="$(jq -cn --argjson common "$vm_args_json" --argjson arm "$arm_vm_args_json" '$common + $arm')"

    if jq -e 'any(.[]; startswith("-Xmx") or startswith("-Xms"))' <<<"$requested_args" >/dev/null; then
        LogError "Use MEMORY_XMX_GB/MEMORY_XMS_GB instead of memory options in VM_ARGS or ARM64_VM_ARGS"
        return 1
    fi

    local profile="none"
    local profile_args='[]'
    if [ "$arch" = arm64 ]; then
        profile="${ARM64_JVM_PROFILE:-compatibility}"
        profile_args="$(arm64_profile_args "$profile")"
    fi

    local requested_gc profile_gc
    requested_gc="$(jq -c '[.[] | select(test("^-XX:\\+Use(Z|G1|Serial|Parallel|Shenandoah|Epsilon)GC$"))] | unique' <<<"$requested_args")"
    profile_gc="$(jq -c '[.[] | select(test("^-XX:\\+Use(Z|G1|Serial|Parallel|Shenandoah|Epsilon)GC$"))] | unique' <<<"$profile_args")"

    if [ "$(jq 'length' <<<"$requested_gc")" -gt 1 ]; then
        LogError "VM_ARGS and ARM64_VM_ARGS select multiple garbage collectors"
        return 1
    fi

    # An explicitly requested collector overrides only the collector portion of
    # the selected profile; all other profile compatibility flags remain.
    if [ "$(jq 'length' <<<"$requested_gc")" -eq 1 ]; then
        profile_args="$(json_array_without_gc "$profile_args")"
        profile_gc='[]'
    fi

    local base_args
    base_args="$(jq -c --argjson previous "$previous_managed" '
        [.vmArgs[]
          | select(. as $arg | ($previous | index($arg)) == null)
          | select((startswith("-Xmx") or startswith("-Xms")) | not)]
    ' "$json_file")"

    local desired_gc base_gc base_gc_count desired_gc_count replaced_args
    desired_gc="$(jq -cn --argjson requested "$requested_gc" --argjson profile "$profile_gc" '$requested + $profile')"
    base_gc="$(jq -c '[.[] | select(test("^-XX:\\+Use(Z|G1|Serial|Parallel|Shenandoah|Epsilon)GC$"))] | unique' <<<"$base_args")"
    base_gc_count="$(jq 'length' <<<"$base_gc")"
    desired_gc_count="$(jq 'length' <<<"$desired_gc")"
    replaced_args="$previous_replaced"

    # If an ARM64 profile previously displaced a bundled JVM option, restore it
    # when no profile/explicit collector is active (for example after moving the
    # same server-files volume back to AMD64).
    if [ "$desired_gc_count" -eq 0 ] && [ "$(jq 'length' <<<"$previous_replaced")" -gt 0 ]; then
        if [ "$base_gc_count" -eq 0 ]; then
            base_args="$(jq -cn --argjson base "$base_args" --argjson restore "$previous_replaced" '
                ($base + $restore)
                | reduce .[] as $arg ([]; if index($arg) == null then . + [$arg] else . end)
            ')"
            base_gc="$(jq -c '[.[] | select(test("^-XX:\\+Use(Z|G1|Serial|Parallel|Shenandoah|Epsilon)GC$"))] | unique' <<<"$base_args")"
            base_gc_count="$(jq 'length' <<<"$base_gc")"
        else
            LogWarn "Not restoring a previously replaced bundled collector because the JSON now has an explicit collector"
        fi
        replaced_args='[]'
    fi

    if [ "$base_gc_count" -gt 1 ]; then
        LogError "ProjectZomboid64.json already selects multiple garbage collectors; refusing to guess which one to remove"
        return 1
    fi

    if [ "$desired_gc_count" -eq 1 ] && [ "$base_gc_count" -eq 1 ]; then
        local existing_gc selected_gc
        existing_gc="$(jq -r '.[0]' <<<"$base_gc")"
        selected_gc="$(jq -r '.[0]' <<<"$desired_gc")"

        if [ "$existing_gc" = "-XX:+UseZGC" ] && [ "$selected_gc" != "$existing_gc" ]; then
            LogWarn "Replacing the bundled ZGC selection with ${selected_gc} for emulator compatibility"
            local removed_bundled
            removed_bundled="$(jq -c '[.[] | select(. == "-XX:+UseZGC" or . == "-XX:+ZGenerational")]' <<<"$base_args")"
            replaced_args="$(jq -cn --argjson previous "$replaced_args" --argjson removed "$removed_bundled" '
                ($previous + $removed)
                | reduce .[] as $arg ([]; if index($arg) == null then . + [$arg] else . end)
            ')"
            base_args="$(jq -c '[.[] | select(. != "-XX:+UseZGC" and . != "-XX:+ZGenerational")]' <<<"$base_args")"
        elif [ "$existing_gc" != "$selected_gc" ]; then
            LogError "Existing JVM collector ${existing_gc} conflicts with requested ${selected_gc}; remove one or set ARM64_JVM_PROFILE=none"
            return 1
        fi
    fi

    local memory_args managed_args
    memory_args="$(jq -cn --arg xmx "-Xmx${memory_xmx_gb}G" --arg xms "${memory_xms_gb:+-Xms${memory_xms_gb}G}" \
        'if $xms == "" then [$xmx] else [$xmx, $xms] end')"
    managed_args="$(jq -cn \
        --argjson memory "$memory_args" \
        --argjson profile "$profile_args" \
        --argjson requested "$requested_args" '
        ($memory + $profile + $requested)
        | reduce .[] as $arg ([]; if index($arg) == null then . + [$arg] else . end)
    ')"

    mkdir -p "$(dirname "$state_file")"

    local json_tmp state_tmp
    json_tmp="$(mktemp "${json_file}.tmp.XXXXXX")"
    state_tmp="$(mktemp "${state_file}.tmp.XXXXXX")"

    if ! jq --argjson base "$base_args" --argjson managed "$managed_args" '
        .vmArgs = (($base + $managed)
          | reduce .[] as $arg ([]; if index($arg) == null then . + [$arg] else . end))
    ' "$json_file" > "$json_tmp"; then
        rm -f "$json_tmp" "$state_tmp"
        LogError "Failed to update $json_file"
        return 1
    fi

    if ! jq -n \
        --arg architecture "$arch" \
        --arg profile "$profile" \
        --argjson managed "$managed_args" \
        --argjson replaced "$replaced_args" \
        '{version: 1, architecture: $architecture, profile: $profile, managedArgs: $managed, replacedArgs: $replaced}' \
        > "$state_tmp"; then
        rm -f "$json_tmp" "$state_tmp"
        LogError "Failed to create managed JVM state"
        return 1
    fi

    chmod --reference="$json_file" "$json_tmp"
    chmod 0644 "$state_tmp"
    mv -f "$json_tmp" "$json_file"
    mv -f "$state_tmp" "$state_file"

    if [ -n "$memory_xms_gb" ]; then
        LogSuccess "JVM configured: Xmx ${memory_xmx_gb}GB, Xms ${memory_xms_gb}GB, ARM64 profile ${profile}"
    else
        LogSuccess "JVM configured: Xmx ${memory_xmx_gb}GB, ARM64 profile ${profile}"
    fi
}

build_server_args() {
    local -n output_args="$1"
    local use_steam="${USE_STEAM:-true}"
    output_args=(
        "-cachedir=${CONFIG_DIR}"
        -adminusername "${ADMIN_USERNAME}"
        -adminpassword "${ADMIN_PASSWORD}"
        -port "${DEFAULT_PORT}"
        -servername "${SERVER_NAME}"
        -steamvac "${STEAM_VAC}"
    )

    case "${use_steam,,}" in
        true|1|yes|on|"")
            # Steam networking is the game's default; no switch is required.
            ;;
        false|0|no|off)
            # PZ treats -nosteam as a flag. Passing the textual false value as
            # a second argument produces an "unknown option" warning.
            output_args+=(-nosteam)
            ;;
        *)
            # Preserve compatibility for deployments that historically used
            # USE_STEAM as a raw final launcher argument.
            LogWarn "Passing unrecognised USE_STEAM value through to the server: ${use_steam}"
            output_args+=("${use_steam}")
            ;;
    esac
}
