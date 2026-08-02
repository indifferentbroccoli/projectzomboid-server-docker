#!/bin/bash

set -Eeuo pipefail

# shellcheck source=scripts/functions.sh
source "/home/steam/server/functions.sh"

if [ "$(container_arch)" != arm64 ]; then
    LogError "The Box64 launcher is only valid in the linux/arm64 image"
    exit 1
fi

emulator="${PZ_EMULATOR:-box64}"
case "$emulator" in
    box64|*/box64) ;;
    *)
        LogError "Unsupported PZ_EMULATOR '$emulator'; the ARM64 image requires box64"
        exit 1
        ;;
esac

if ! box64_bin="$(command -v "$emulator")"; then
    LogError "Box64 executable not found: $emulator"
    exit 1
fi

server_dir="${PZ_SERVER_DIR:-/project-zomboid}"
json_file="${server_dir}/ProjectZomboid64.json"

if [ ! -f "$json_file" ]; then
    LogError "Launcher metadata not found: $json_file"
    exit 1
fi

if ! jq -e '
    (.mainClass | type == "string" and length > 0) and
    (.classpath | type == "array" and length > 0 and all(.[]; type == "string" and length > 0)) and
    (.vmArgs | type == "array" and all(.[]; type == "string"))
' "$json_file" >/dev/null; then
    LogError "Invalid Project Zomboid launcher metadata in $json_file"
    exit 1
fi

java_bin=""
if [ -x "${server_dir}/jre64/bin/java" ]; then
    java_bin="${server_dir}/jre64/bin/java"
else
    while IFS= read -r candidate; do
        java_bin="$candidate"
        break
    done < <(find "$server_dir" -maxdepth 4 -type f -path '*/bin/java' -perm /111 -print 2>/dev/null)
fi

if [ -z "$java_bin" ] || [ ! -x "$java_bin" ]; then
    LogError "Downloaded x86-64 Java executable was not found under $server_dir"
    exit 1
fi

java_description="$(file -b "$java_bin")"
if [[ "$java_description" != *x86-64* ]] && [[ "$java_description" != *x86_64* ]]; then
    LogError "Expected an x86-64 bundled JVM, got: $java_description"
    exit 1
fi

main_class="$(jq -r '.mainClass' "$json_file")"
main_class="${main_class//\//.}"

mapfile -d '' -t classpath_entries < <(jq -j '.classpath[] | ., "\u0000"' "$json_file")
mapfile -d '' -t vm_args < <(jq -j '.vmArgs[] | ., "\u0000"' "$json_file")

for classpath_entry in "${classpath_entries[@]}"; do
    if [[ "$classpath_entry" != *'*'* ]] && [ ! -e "${server_dir}/${classpath_entry}" ]; then
        LogError "Classpath entry from ProjectZomboid64.json does not exist: $classpath_entry"
        exit 1
    fi
done

classpath="$(IFS=:; printf '%s' "${classpath_entries[*]}")"
jre_dir="$(cd "$(dirname "$java_bin")/.." && pwd)"

guest_library_dirs=(
    "/usr/lib/box64-x86_64-linux-gnu"
    "${server_dir}/linux64"
    "${server_dir}/natives"
    "${server_dir}"
    "${jre_dir}/lib"
    "${jre_dir}/lib/server"
    "${jre_dir}/lib/amd64"
    "${jre_dir}/lib/jli"
)

existing_library_dirs=()
for library_dir in "${guest_library_dirs[@]}"; do
    if [ -d "$library_dir" ]; then
        existing_library_dirs+=("$library_dir")
    fi
done
guest_library_path="$(IFS=:; printf '%s' "${existing_library_dirs[*]}")"

export BOX64_DYNAREC_STRONGMEM="${BOX64_DYNAREC_STRONGMEM:-3}"
export BOX64_DYNAREC_SAFEFLAGS="${BOX64_DYNAREC_SAFEFLAGS:-2}"
export BOX64_DYNAREC_ALIGNED_ATOMICS="${BOX64_DYNAREC_ALIGNED_ATOMICS:-1}"
export BOX64_DYNAREC_BIGBLOCK="${BOX64_DYNAREC_BIGBLOCK:-0}"
export BOX64_DYNAREC_CALLRET="${BOX64_DYNAREC_CALLRET:-0}"
export BOX64_JVM="${BOX64_JVM:-0}"
export BOX64_SSE42="${BOX64_SSE42:-0}"
export BOX64_MAXCPU="${BOX64_MAXCPU:-4}"
export BOX64_LD_LIBRARY_PATH="${guest_library_path}${BOX64_LD_LIBRARY_PATH:+:${BOX64_LD_LIBRARY_PATH}}"

if [ -f "${jre_dir}/lib/libjsig.so" ]; then
    export BOX64_LD_PRELOAD="${jre_dir}/lib/libjsig.so${BOX64_LD_PRELOAD:+:${BOX64_LD_PRELOAD}}"
elif [ -f "${jre_dir}/lib/server/libjsig.so" ]; then
    export BOX64_LD_PRELOAD="${jre_dir}/lib/server/libjsig.so${BOX64_LD_PRELOAD:+:${BOX64_LD_PRELOAD}}"
fi

if [ "${1:-}" = "--validate-only" ]; then
    LogSuccess "ARM64 launcher metadata validated (JVM: $java_bin, main class: $main_class)"
    exit 0
fi

cd "$server_dir"

LogInfo "Launching the downloaded x86-64 JVM explicitly through Box64"
exec "$box64_bin" "$java_bin" "${vm_args[@]}" -cp "$classpath" "$main_class" "$@"
