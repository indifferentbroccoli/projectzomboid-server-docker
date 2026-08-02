<!-- markdownlint-disable-next-line -->
![marketing_assets_banner](https://github.com/user-attachments/assets/b8b4ae5c-06bb-46a7-8d94-903a04595036)
[![GitHub License](https://img.shields.io/github/license/indifferentbroccoli/projectzomboid-server-docker?style=for-the-badge&color=6aa84f)](https://github.com/indifferentbroccoli/projectzomboid-server-docker/blob/main/LICENSE)
[![GitHub Release](https://img.shields.io/github/v/release/indifferentbroccoli/projectzomboid-server-docker?style=for-the-badge&color=6aa84f)](https://github.com/indifferentbroccoli/projectzomboid-server-docker/releases)
[![GitHub Repo stars](https://img.shields.io/github/stars/indifferentbroccoli/projectzomboid-server-docker?style=for-the-badge&color=6aa84f)](https://github.com/indifferentbroccoli/projectzomboid-server-docker)
[![Discord](https://img.shields.io/discord/798321161082896395?style=for-the-badge&label=Discord&labelColor=5865F2&color=6aa84f)](https://discord.gg/indifferentbroccoli)
[![Docker Pulls](https://img.shields.io/docker/pulls/indifferentbroccoli/projectzomboid-server-docker?style=for-the-badge&color=6aa84f)](https://hub.docker.com/r/indifferentbroccoli/projectzomboid-server-docker)

Game server hosting

Fast RAM, high-speed internet

Eat lag for breakfast

[Try our Project Zomboid Server hosting free for 2 days!](https://indifferentbroccoli.com/project-zomboid-server-hosting)

# Project Zomboid Server Docker (B42 Unstable Supported)

> [!IMPORTANT]
> Linux ARM64 support is experimental. Project Zomboid itself is **not ARM64-native**: the ARM64 image uses native ARM64 container utilities and runs only the downloaded x86-64 game JVM/server through Box64.

> [!IMPORTANT]
> Using Docker Desktop with WSL2 on Windows will result in a very slow download.

## Architecture support

| Host/image platform | Container, downloader, and RCON | Project Zomboid runtime | Status |
|---|---|---|---|
| `linux/amd64` | Native AMD64 Debian, DepotDownloader, and rcon-cli | Native x86-64 via the supplied `start-server.sh` | Supported source build |
| `linux/arm64` | Native ARM64 Debian, DepotDownloader, and rcon-cli; native Box64 | x86-64 bundled JVM, JNI libraries, and server through explicit Box64 invocation | Experimental source build |

The ARM64 image does not use full-container x86 emulation. DepotDownloader and rcon-cli execute natively, while `start-box64.sh` reads the installed `ProjectZomboid64.json` and passes its classpath, main class, JVM arguments, and normal server arguments to the downloaded x86-64 Java executable through Box64. It does not register `binfmt_misc`, need host binfmt support, or require `privileged: true`.

ARM64 remains experimental until real-ARM64 integration testing has passed repeatedly across supported Project Zomboid branches and representative ARM64 machines. Promotion requires the `compatibility` profile to provide reliable player joins, RCON readiness, save/quit, restart persistence, and no recurring Box64/JVM crashes.

## Server requirements

These are the project's existing baseline guidelines. ARM64 emulation adds CPU overhead, so strong per-core performance is especially important; no native-equivalent performance is promised.

| Resource | Minimum | Recommended |
|---|---:|---:|
| CPU | 4 cores | 4+ cores |
| RAM | 4 GB | Over 8 GB for stable operation |
| Storage | 5 GB | 10 GB |

## How to use

Copy `.env.example` to `.env`, then change `RCON_PASSWORD`, `ADMIN_USERNAME`, and `ADMIN_PASSWORD` before starting the server.

```bash
cp .env.example .env
```

### Docker Compose from source

The included Compose file builds directly from this checkout. Docker automatically selects the host architecture, so the same configuration is used on AMD64 and ARM64. Do not add `platform: linux/amd64` on an ARM64 host.

```yaml
services:
  projectzomboid:
    build:
      context: .
    restart: unless-stopped
    container_name: projectzomboid
    stop_grace_period: 30s
    ports:
      - 16261:16261/udp
      - 16262:16262/udp
      - 27015:27015/tcp
    env_file:
      - .env
    volumes:
      - ./server-files:/project-zomboid
      - ./server-data:/project-zomboid-config
```

Build and start it with:

```bash
docker compose up -d --build
```

On ARM64, the Dockerfile includes Box64 and the compatibility profile automatically. No privileged setting, host binfmt registration, or architecture environment override is required.

### Docker run

Build a local image for the host architecture first:

```bash
docker buildx build --load -t projectzomboid-server:local .
```

```bash
docker run -d \
    --restart unless-stopped \
    --name projectzomboid \
    --stop-timeout 30 \
    -p 16261:16261/udp \
    -p 16262:16262/udp \
    -p 27015:27015/tcp \
    --env-file .env \
    -v ./server-files:/project-zomboid \
    -v ./server-data:/project-zomboid-config \
    projectzomboid-server:local
```

## Environment variables

### Common settings

| Variable | Default | Info |
|---|---|---|
| `PUID` | `1000` in `.env.example` | Required user ID. |
| `PGID` | `1000` in `.env.example` | Required group ID. |
| `ADMIN_USERNAME` | `admin` | Admin username. |
| `ADMIN_PASSWORD` | `CHANGEME` in `.env.example` | Admin password; change it. |
| `RCON_PASSWORD` | `CHANGEME` in `.env.example` | RCON password; change it. |
| `RCON_PORT` | `27015` | RCON TCP port. |
| `SERVER_NAME` | `pzserver` | Server/map name. |
| `DEFAULT_PORT` | `16261` | Starting player-data port. |
| `UDP_PORT` | `16262` | Additional UDP port. |
| `MAX_PLAYERS` | `32` | Maximum players. |
| `MEMORY_XMX_GB` | `8` | Maximum JVM heap in GB. |
| `MEMORY_XMS_GB` | empty | Optional initial JVM heap in GB. |
| `VM_ARGS` | empty | Extra common JVM arguments, comma-separated. |
| `UPDATE_ON_START` | `true` | Set to `false` to skip validation/update when server files already exist. |
| `SERVER_BRANCH` | empty | Steam branch, such as `unstable` or `legacy41`; empty selects public. |
| `STEAM_VAC` | `true` | Steam VAC setting passed to the game server. |
| `USE_STEAM` | `true` | `false` adds the Project Zomboid `-nosteam` argument. |

JVM edits are idempotent. The image removes its previously managed arguments, preserves unrelated JSON arguments, applies memory and the selected profile once, and atomically replaces `ProjectZomboid64.json`. Its state is stored at `server-data/.pz-docker-managed-vmargs.json`, so it can reapply settings after a Steam update replaces the launcher JSON and restore a displaced bundled collector when the volume moves back to AMD64.

Do not put `-Xmx` or `-Xms` in `VM_ARGS`; use the memory variables. If an explicit garbage collector conflicts with a non-default collector already in the JSON, startup stops instead of silently deleting the user setting.

### Experimental ARM64 settings

| Variable | Default | Info |
|---|---:|---|
| `PZ_EMULATOR` | automatic | Empty selects `box64` on ARM64. The ARM64 launcher rejects other emulators. |
| `ARM64_JVM_PROFILE` | `compatibility` | `default`, `compatibility`, `interpreter`, or advanced opt-out `none`. |
| `ARM64_VM_ARGS` | empty | Extra ARM64-only JVM arguments, comma-separated. |
| `BOX64_DYNAREC_STRONGMEM` | `3` | Uses Box64's conservative Project Zomboid memory-order setting. Lower values may be faster but less stable. |
| `BOX64_DYNAREC_SAFEFLAGS` | `2` | Preserves flags across Box64 dynarec edge cases. |
| `BOX64_DYNAREC_ALIGNED_ATOMICS` | `1` | Uses Box64's Project Zomboid atomic setting. Set `0` when diagnosing an alignment-related failure. |
| `BOX64_DYNAREC_BIGBLOCK` | `0` | Disables large translated blocks so HotSpot can safely replace generated x86 code. |
| `BOX64_DYNAREC_CALLRET` | `0` | Disables Box64 CALL/RET linking across HotSpot-generated code. |
| `BOX64_JVM` | `0` | Keeps the explicit Project Zomboid settings from being replaced by Box64's generic JVM preset. |
| `BOX64_SSE42` | `0` | Hides SSE 4.2 from the x86 JVM for compatibility. |
| `BOX64_MAXCPU` | `4` | Maximum CPUs exposed to the emulated runtime; `0` exposes all. |

Profiles manage only their listed JVM compatibility options:

- `default`: G1 garbage collector and normal tiered JIT operation; currently more aggressive and experimental.
- `compatibility`: the ARM64 default; Serial GC, compressed-oops disabled, and tiered/C1 compilation disabled so HotSpot uses C2 only.
- `interpreter`: Serial GC, compressed-oops disabled, and `-Xint`. This is the slowest fallback and is intentionally not the default.
- `none`: no ARM64 JVM profile. Use only when manually managing emulator/JVM compatibility.

The bundled Project Zomboid JSON currently selects ZGC. On ARM64, a selected profile replaces that bundled collector with its own single collector. An explicitly supplied collector in `VM_ARGS` or `ARM64_VM_ARGS` overrides only the profile's collector; multiple collector selections are rejected.

## Configuration files

Files under `server-data/Server/` persist across container restarts and can be edited while the server is stopped:

- `<SERVER_NAME>.ini` controls networking, gameplay, anti-cheat, RCON, and player limits.
- `<SERVER_NAME>_SandboxVars.lua` controls world and sandbox settings.
- `<SERVER_NAME>_spawnregions.lua` defines player spawn regions.

## Migrating an existing server to ARM64

1. Stop the old container cleanly and back up both `server-data` and `server-files`.
2. Preserve `server-data`; it contains configuration, saves, and the database.
3. Existing `server-files` use the same Linux x86-64 Project Zomboid payload and can normally be reused. DepotDownloader validates/resumes partial downloads, but an interrupted or old partial directory may need another update pass. Do not delete `server-data` when repairing server files.
4. Remove any old `image:` and `platform: linux/amd64` lines so Compose builds this checkout for ARM64.
5. Run `docker compose up -d --build` and watch the first launch with `docker compose logs -f`.

Host binfmt registration is not required by the native ARM64 image. The old full-image AMD64 emulation configuration is only a troubleshooting fallback:

```yaml
services:
  projectzomboid:
    image: indifferentbroccoli/projectzomboid-server-docker:latest
    platform: linux/amd64
```

That fallback depends on the Docker host's x86-64 emulation support and can reproduce QEMU/DepotDownloader instability; it is not the ARM64 design described above.

## ARM64 troubleshooting

### Box64 crashes

Confirm the image really is ARM64 and Box64 is native:

```bash
docker compose images
docker compose run --rm --no-deps --entrypoint sh projectzomboid -c \
  'uname -m; file /usr/local/bin/box64 /depotdownloader/DepotDownloader /usr/bin/rcon-cli'
```

Try `BOX64_DYNAREC_ALIGNED_ATOMICS=0` if the crash suggests an alignment failure. Lowering `BOX64_DYNAREC_STRONGMEM` may improve performance but weakens the pinned Box64 release's Project Zomboid compatibility setting. Reduce `BOX64_MAXCPU` if failures correlate with high thread counts.

### JVM or JIT crashes

Use the default `ARM64_JVM_PROFILE=compatibility`, `BOX64_DYNAREC_BIGBLOCK=0`, and `BOX64_DYNAREC_CALLRET=0` combination first. It avoids the C1 compiler and conservative Box64 linking is important for HotSpot-generated code. If it still crashes, try `interpreter` only as a diagnostic because `-Xint` has a major performance cost and may be too slow to process initial world-chunk requests. Preserve the crashing log and Box64 output when reporting an issue.

### First-start download failures

The first download can be slow and the health check allows a 40-minute start period, including the much slower opt-in interpreter profile. DepotDownloader validates existing chunks on the next start. Confirm `/depotdownloader/DepotDownloader -V` runs and is AArch64 in the ARM image. Check DNS, outbound HTTPS/Steam connectivity, volume space, and volume permissions before removing any partial files.

### `exec format error`

Remove `platform: linux/amd64`, rebuild with `docker compose build --no-cache`, and verify all utility architectures with the commands above. The game JVM should remain x86-64; only Box64 launches it. Do not execute `/project-zomboid/start-server.sh` directly in the ARM64 image.

### RCON readiness or unhealthy status

The health check uses an authenticated, read-only `players` RCON command once startup begins. Inspect it with:

```bash
docker inspect projectzomboid --format '{{json .State.Health}}' | jq
docker exec projectzomboid rcon-cli -c /home/steam/server/rcon.yml players
docker logs projectzomboid
```

Verify `RCON_PASSWORD`, `RCON_PORT`, and the persisted `<SERVER_NAME>.ini`. An alive Box64/Java process is not treated as ready once the RCON configuration exists.

## Developer information

### Reproducible third-party inputs

| Input | Pin | SHA-256 |
|---|---|---|
| rcon-cli source | `v0.10.3` | `e871753e970300ff4fade6bc7e39eb086fd7a87c772657870b071b9e5f0468fe` |
| DepotDownloader Linux x64 | `3.4.0` | `a999dec66b4850fc961bd50366696d23c2d0fad7b18790e6a5647b2f19097a53` |
| DepotDownloader Linux ARM64 | `3.4.0` | `d9fb612ccebc1db8eeea3b4045d2221ec70431381393ce908fb72f01d4f9c812` |
| Box64 source | full commit `15e065ae5dd0207fe4f6cfce565884f68567d64f` | `01874a88c78d165aaecbde9d57aac2ef25ce19931ed187ae42a9d76b5d6979c6` |

The checksums were calculated with `sha256sum` after downloading the exact GitHub release/source URLs used in the Dockerfile. They are pinned as Docker build arguments and verified before extraction; they are not copied from an unverified checksum list.

### Build commands

AMD64 only, loaded into the local Docker engine:

```bash
docker buildx build --platform linux/amd64 --load -t projectzomboid:amd64 .
```

ARM64 only, loaded into the local Docker engine:

```bash
docker buildx build --platform linux/arm64 --load -t projectzomboid:arm64 .
```

Both platforms as a local OCI archive:

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --output type=oci,dest=projectzomboid-multiarch.tar \
  -t projectzomboid:multiarch .
```

To publish both under one non-stable test tag, replace `--output ...` with `--push` and use a registry-qualified tag. Do not publish that manifest as `latest` until ARM64 meets the promotion criteria above.
