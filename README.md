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
> Using Docker Desktop with WSL2 on Windows will result in a very slow download!

## Server Requirements

| Resource | Minimum | Recommended                             |
|----------|---------|-----------------------------------------|
| CPU      | 4 cores | 4+ cores                                |
| RAM      | 4GB     | Recommend over 8GB for stable operation |
| Storage  | 5GB     | 10GB                                    |

## How to use

Copy the .env.example file to a new file called .env file and make adjustments.
Then make sure the mounted volumes are read/write accessible to the user that will run the server.
If the user is named `pz` on the host, the following will setup the storage in the current folder:

```bash
mkdir ./server-files ./server-data
sudo chown pz:pz ./server-files/ ./server-data/
```

Then use either `docker compose` or `docker run`

> [!IMPORTANT]
> Please make sure to change the following in the .env:
> RCON_PASSWORD/ADMIN_USERNAME/ADMIN_PASSWORD

### Docker compose

Starting the server with Docker Compose (adjust user and group id as necessary):

```yaml
services:
  projectzomboid:
    image: indifferentbroccoli/projectzomboid-server-docker
    user: 1000:1000
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

Then run:

```bash
docker-compose up -d
```

### Docker Run

Starting the server with `docker run` directly (adjust user group id as necessary):

```bash
docker run -d \
    --user 1000:1000 \
    --restart unless-stopped \
    --name projectzomboid \
    --stop-timeout 30 \
    -p 16261:16261/udp \
    -p 16262:16262/udp \
    -p 27015:27015/tcp \
    --env-file .env \
    -v ./server-files:/project-zomboid \
    -v ./server-data:/project-zomboid-config \
    indifferentbroccoli/projectzomboid-server-docker
```

## Environment Variables

The following environment variables control server behaviour:

| Variable        | Default  | Info                                                                                                                                                                                                         |
| --------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| RUN_AS_ROOT     | false    | Allows running the server as root within the container. Recommended to set to `false` and provide a non-privileged user when running the container. This user needs access to the mounted storage locations. |
| ADMIN_USERNAME  | admin    | Admin username                                                                                                                                                                                               |
| ADMIN_PASSWORD  | CHANGEME | Admin password. Please change this before starting the server.                                                                                                                                               |
| RCON_PASSWORD   |          | RCON password                                                                                                                                                                                                |
| RCON_PORT       | 27015    | The port for the RCON (Remote Console)                                                                                                                                                                       |
| SERVER_NAME     | pzserver | Name of the server/map                                                                                                                                                                                       |
| DEFAULT_PORT    | 16261    |                                                                                                                                                                                                              |
| UDP_PORT        | 16262    | UDP port. Minimum=0 Maximum=65535                                                                                                                                                                            |
| MAX_PLAYERS     | 32       | Maximum number of players that can be on the server at one time.                                                                                                                                             |
| MEMORY_XMX_GB   | 8        | Server maximum memory allocation in GB. Sets -Xmx in ProjectZomboid64.json                                                                                                                                   |
| MEMORY_XMS_GB   |          | Optional: Server initial memory allocation in GB. Sets -Xms in ProjectZomboid64.json. If not specified, only -Xmx is configured                                                                              |
| VM_ARGS         |          | Optional: extra JVM args (comma-separated) appended to vmArgs in ProjectZomboid64.js                                                                                                                         |
| UPDATE_ON_START | true     | If set to false, skips downloading and validating server file.                                                                                                                                               |
| SERVER_BRANCH   | ""       | Steam branch to install (e.g. "unstable" for Build 42 Unstable, "legacy41" for Build 41). Leave empty for the default public branch.                                                                         |
| STEAM_VAC       | true     | Enable Steam VAC anti-cheat.                                                                                                                                                                                 |
| USE_STEAM       | true     | Whether the server is Steam-enabled.                                                                                                                                                                         |

## Configuration Files

These files are stored in your `server-data` volume (`./server-data` on the host), under `Server/`. They persist across container restarts and can be edited directly while the server is stopped.

### `<SERVER_NAME>.ini`

**Path:** `server-data/Server/<SERVER_NAME>.ini`

The main server settings file. Controls gameplay options such as PvP, loot respawn, safehouse rules, anti-cheat, player limits, and more. This file is generated by the server on first run. Edit it directly to configure anything not exposed as an environment variable.

### `<SERVER_NAME>_SandboxVars.lua`

**Path:** `server-data/Server/<SERVER_NAME>_SandboxVars.lua`

Controls sandbox/world settings such as zombie population, loot abundance, season, time of day, and other in-world difficulty options. Generated by the server on first run. Changes take effect on server restart.

### `<SERVER_NAME>_spawnregions.lua`

**Path:** `server-data/Server/<SERVER_NAME>_spawnregions.lua`

Defines the spawn regions available to players when they first join. Each region maps to a named area on the map. You can restrict or expand available spawn points by editing this file. A default is created on first run based on the active map.

## Developer information

### Building the image

You can build the image from the Dockerfile using the following command:

```bash
docker build -t indifferentbroccoli/projectzomboid-server-docker .
```


