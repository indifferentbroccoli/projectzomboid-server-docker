<!-- markdownlint-disable-next-line -->
![marketing_assets_banner](https://github.com/user-attachments/assets/b8b4ae5c-06bb-46a7-8d94-903a04595036)
[![GitHub License](https://img.shields.io/github/license/indifferentbroccoli/projectzomboid-server-docker?style=for-the-badge&color=6aa84f)](https://github.com/indifferentbroccoli/projectzomboid-server-docker/blob/main/LICENSE)
[![GitHub Release](https://img.shields.io/github/v/release/indifferentbroccoli/projectzomboid-server-docker?style=for-the-badge&color=6aa84f)](https://github.com/indifferentbroccoli/projectzomboid-server-docker/releases)
[![GitHub Repo stars](https://img.shields.io/github/stars/indifferentbroccoli/projectzomboid-server-docker?style=for-the-badge&color=6aa84f)](https://github.com/indifferentbroccoli/projectzomboid-server-docker)
[![Docker Pulls](https://img.shields.io/docker/pulls/indifferentbroccoli/projectzomboid-server-docker?style=for-the-badge&color=6aa84f)](https://hub.docker.com/r/indifferentbroccoli/projectzomboid-server-docker)

Game server hosting

Fast RAM, high-speed internet

Eat lag for breakfast

[Try our Project Zomboid Server hosting free for 2 days!](https://indifferentbroccoli.com/project-zomboid-server-hosting)

# Project Zomboid Server Docker

> [!IMPORTANT]
> Using Docker Desktop with WSL2 on Windows will result in a very slow download!

## Server Requirements

| Resource | Minimum | Recommended                             |
|----------|---------|-----------------------------------------|
| CPU      | 4 cores | 4+ cores                                |
| RAM      | 4GB     | Recommend over 8GB for stable operation |
| Storage  | 5GB     | 10GB                                    |

## How to use

> [!IMPORTANT]
> .env settings will override the current settings in the settings.ini
> If you do not want that to happen, set GENERATE_SETTINGS=false

Copy the .env.example file to a new file called .env file. Then use either `docker compose` or `docker run`

> [!IMPORTANT]
> Please make sure to change the following in the .env:
> PASSWORD/RCON_PASSWORD/ADMIN_USERNAME/ADMIN_PASSWORD

### Docker compose

Starting the server with Docker Compose:

```yaml
services:
  projectzomboid:
    image: indifferentbroccoli/projectzomboid-server-docker
    restart: unless-stopped
    container_name: projectzomboid
    stop_grace_period: 30s
    ports:
      - 16261:16261/udp
      - 16262:16262/udp
      - 27015:27015/tcp
    environment:
      GENERATE_SETTINGS: true
    env_file:
      - .env
    volumes:
      - ./projectzomboid/server-files:/project-zomboid
      - ./projectzomboid/server-data:/project-zomboid-config
```

Then run:

```bash
docker-compose up -d
```

### Docker Run

```bash
docker run -d \
    --restart unless-stopped \
    --name projectzomboid \
    --stop-timeout 30 \
    -p 16261:16261/udp \
    -p 16262:16262/udp \
    -p 27015:27015/tcp \
    -e GENERATE_SETTINGS=true \
    --env-file .env \
    -v ./projectzomboid/server-files:/project-zomboid \
    -v ./projectzomboid/server-data:/project-zomboid-config
    indifferentbroccoli/projectzomboid-server-docker
```

## Environment Variables

You can use the following values to change the settings of the server on boot.
It is highly recommended you set the following environment values before starting the server:

* PASSWORD
* RCON_PASSWORD
* ADMIN_USERNAME
* ADMIN_PASSWORD

| Variable                                          | Default                                                                                       | Info                                                                                                                                                |
|---------------------------------------------------|-----------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------|
| PVP                                               | true                                                                                          | Players can hurt and kill other players                                                                                                             |
| PAUSE_EMPTY                                       | true                                                                                          | Game time stops when there are no players online                                                                                                    |
| GLOBAL_CHAT                                       | true                                                                                          | Toggles global chat on or off.                                                                                                                      |
| CHAT_STREAMS                                      | s,r,a,w,y,sh,f,all                                                                            | Chat streams                                                                                                                                        |
| OPEN                                              | true                                                                                          | Clients may join without already having an account in the whitelist. If set to false, administrators must manually create username/password combos. |
| SERVER_WELCOME_MESSAGE                            | Welcome to your Indifferent Broccoli Project Zomboid Docker server                            | The first welcome message visible in the chat panel.                                                                                                |
| AUTO_CREATE_USER_IN_WHITE_LIST                    | false                                                                                         | Add unknown usernames to the whitelist when players join                                                                                            |
| DISPLAY_USER_NAME                                 | true                                                                                          | Display usernames above player's heads in-game.                                                                                                     |
| SHOW_FIRST_AND_LAST_NAME                          | false                                                                                         | Display first & last name above player's heads.                                                                                                     |
| SPAWN_POINT                                       | 0,0,0                                                                                         | Force every new player to spawn at these set x,y,z world coordinates. (Ignored when 0,0,0)                                                          |
| SAFETY_SYSTEM                                     | true                                                                                          | Players can enter and leave PVP on an individual basis.                                                                                             |
| SHOW_SAFETY                                       | true                                                                                          | Display a skull icon over the head of players who have entered PVP mode                                                                             |
| SAFETY_TOGGLE_TIMER                               | 2                                                                                             | The time it takes for a player to enter and leave PVP mode\nMinimum=0 Maximum=1000 Default=2                                                        |
| SAFETY_COOLDOWN_TIMER                             | 3                                                                                             | The delay before a player can enter or leave PVP mode again, having recently done so\nMinimum=0 Maximum=1000 Default=3                              |
| SPAWN_ITEMS                                       |                                                                                               | Item types new players spawn with.\nSeparate multiple item types with commas.\nExample: Base.Axe,Base.Bag_BigHikingBag                              |
| DEFAULT_PORT                                      | 16261                                                                                         | Default starting port for player data.                                                                                                              |
| UDP_PORT                                          | 16262                                                                                         | Minimum=0 Maximum=65535 Default=16262                                                                                                               |
| RESET_ID                                          | 563979383                                                                                     | Reset ID determines if the server has undergone a soft-reset.                                                                                       |
| MODS                                              |                                                                                               | Enter the mod loading ID here. It can be found in \Steam\steamapps\workshop\modID\mods\modName\info.txt                                             |
| MAP                                               |                                                                                               | Enter the foldername of the mod found in \Steam\steamapps\workshop\modID\mods\modName\media\maps\                                                   |
| DO_LUA_CHECKSUM                                   | true                                                                                          | Kick clients whose game files don't match the server's.                                                                                             |
| DENY_LOGIN_ON_OVERLOADED_SERVER                   | false                                                                                         | Deny login on overloaded server                                                                                                                     |
| PUBLIC                                            | true                                                                                          | Shows the server on the in-game browser. (Note: Steam-enabled servers are always visible in the Steam server browser)                               |
| PUBLIC_NAME                                       | Indifferent Broccoli Project Zomboid Docker Server                                            | Name of the server displayed in the in-game browser and, if applicable, the Steam browser                                                           |
| SERVER_NAME                                       | pzserver                                                                                      | Name of the server/map                                                                                                                              |
| PUBLIC_DESCRIPTION                                | Welcome to your Indifferent Broccoli Project Zomboid Docker server                            | Description displayed in the in-game public server browser. Typing \n will create a new line in your description                                    |
| MAX_PLAYERS                                       | 32                                                                                            | Maximum number of players that can be on the server at one time. This excludes admins.                                                              |
| PING_LIMIT                                        | 400                                                                                           | Ping limit, in milliseconds, before a player is kicked from the server.                                                                             |
| HOURS_FOR_LOOT_RESPAWN                            | 0                                                                                             | After X hours, all containers in the world will respawn loot.                                                                                       |
| MAX_ITEMS_FOR_LOOT_RESPAWN                        | 4                                                                                             | Containers with a number of items greater, or equal to, this setting will not respawn                                                               |
| CONSTRUCTION_PREVENTS_LOOT_RESPAWN                | false                                                                                         | Items will not respawn in buildings that players have barricaded or built in                                                                        |
| DROP_OFF_WHITE_LIST_AFTER_DEATH                   | false                                                                                         | Remove player accounts from the whitelist after death.                                                                                              |
| NO_FIRE                                           | false                                                                                         | All forms of fire are disabled - except for campfires                                                                                               |
| ANNOUNCE_DEATH                                    | false                                                                                         | If checked, every time a player dies a global message will be displayed in the chat                                                                 |
| MINUTES_PER_PAGE                                  | 1.0                                                                                           | The number of in-game minutes it takes to read one page of a book                                                                                   |
| SAVE_WORLD_EVERY_MINUTES                          | 0                                                                                             | Loaded parts of the map are saved after this set number of real-world minutes have passed.                                                          |
| PLAYER_SAFEHOUSE                                  | false                                                                                         | Both admins and players can claim safehouses                                                                                                        |
| ADMIN_SAFEHOUSE                                   | false                                                                                         | Only admins can claim safehouses                                                                                                                    |
| SAFEHOUSE_ALLOW_TRESPASS                          | true                                                                                          | Allow non-members to enter a safehouse without being inviteds                                                                                       |
| SAFEHOUSE_ALLOW_FIRE                              | true                                                                                          | Allow fire to damage safehouses                                                                                                                     |
| SAFEHOUSE_ALLOW_LOOT                              | true                                                                                          | Allow non-members to take items from safehousest                                                                                                    |
| SAFEHOUSE_ALLOW_RESPAWN                           | false                                                                                         | Players will respawn in a safehouse that they were a member of before they died                                                                     |
| SAFEHOUSE_DAY_SURVIVED_TO_CLAIM                   | 0                                                                                             | Players must have survived this number of in-game days before they are allowed to claim a safehouse                                                 |
| SAFEHOUSE_REMOVAL_TIME                            | 144                                                                                           | Players are automatically removed from a safehouse they have not visited for this many real-world hours                                             |
| SAFEHOUSE_ALLOW_NON_RESIDENTIAL                   | false                                                                                         | Governs whether players can claim non-residential buildings.                                                                                        |
| ALLOW_DESTRUCTION_BY_SLEDGEHAMMER                 | true                                                                                          | Allow players to destroy world objects with sledgehammers                                                                                           |
| SLEDGEHAMMER_ONLY_IN_SAFEHOUSE                    | false                                                                                         | Allow players to destroy world objects only in their safehouse                                                                                      |
| KICK_FAST_PLAYERS                                 | false                                                                                         | Kick players that appear to be moving faster than is possible. May be buggy -- use with caution.                                                    |
| SERVER_PLAYER_ID                                  | 88635698                                                                                      | ServerPlayerID determines if a character is from another server, or single player.                                                                  |
| RCON_PORT                                         | 27015                                                                                         | The port for the RCON (Remote Console)                                                                                                              |
| DISCORD_ENABLE                                    | false                                                                                         | Enables global text chat integration with a Discord channel                                                                                         |
| DISCORD_TOKEN                                     |                                                                                               | Discord bot access token                                                                                                                            |
| DISCORD_CHANNEL                                   |                                                                                               | The Discord channel name.                                                                                                                           |
| DISCORD_CHANNEL_ID                                |                                                                                               | The Discord channel ID.                                                                                                                             |
| MAX_ACCOUNTS_PER_USER                             | 0                                                                                             | Limits the number of different accounts a single Steam user may create on this server.                                                              |
| ALLOW_COOP                                        | true                                                                                          | Allow co-op/splitscreen players                                                                                                                     |
| SLEEP_ALLOWED                                     | false                                                                                         | Players are allowed to sleep when their survivor becomes tired, but they do not NEED to sleep                                                       |
| SLEEP_NEEDED                                      | false                                                                                         | Players get tired and need to sleep.                                                                                                                |
| KNOCKED_DOWN_ALLOWED                              | true                                                                                          | Knocked down allowed                                                                                                                                |
| SNEAK_MODE_HIDE_FROM_OTHER_PLAYERS                | true                                                                                          | Sneak mode hide from other players                                                                                                                  |
| WORKSHOP_ITEMS                                    |                                                                                               | List Workshop Mod IDs for the server to download. Each must be separated by a semicolon.                                                            |
| STEAM_SCOREBOARD                                  | true                                                                                          | Show Steam usernames and avatars in the Players list.                                                                                               |
| STEAM_VAC                                         | true                                                                                          | Enable the Steam VAC system                                                                                                                         |
| UPNP                                              | true                                                                                          | Attempt to configure a UPnP-enabled internet gateway to automatically setup port forwarding rules.                                                  |
| VOICE_ENABLE                                      | true                                                                                          | VOIP is enabled when checked                                                                                                                        |
| VOICE_MIN_DISTANCE                                | 10.0                                                                                          | The minimum tile distance over which VOIP sounds can be heard.                                                                                      |
| VOICE_MAX_DISTANCE                                | 100.0                                                                                         | The maximum tile distance over which VOIP sounds can be heard                                                                                       |
| VOICE_3D                                          | true                                                                                          | Toggle directional audio for VOIP                                                                                                                   |
| SPEED_LIMIT                                       | 70.0                                                                                          | Minimum=10.00 Maximum=150.00 Default=70.00                                                                                                          |
| LOGIN_QUEUE_ENABLED                               | false                                                                                         | Login queue enabled                                                                                                                                 |
| LOGIN_QUEUE_CONNECT_TIMEOUT                       | 60                                                                                            | Minimum=20 Maximum=1200 Default=60                                                                                                                  |
| SERVER_BROWSER_ANNOUNCED_IP                       |                                                                                               | Set the IP from which the server is broadcast.                                                                                                      |
| PLAYER_RESPAWN_WITH_SELF                          | false                                                                                         | Players can respawn in-game at the coordinates where they died                                                                                      |
| PLAYER_RESPAWN_WITH_OTHER                         | false                                                                                         | Players can respawn in-game at a split screen / Remote Play player's location                                                                       |
| FAST_FORWARD_MULTIPLIER                           | 40.0                                                                                          | Governs how fast time passes while players sleep.                                                                                                   |
| DISABLE_SAFEHOUSE_WHEN_PLAYER_CONNECTED           | false                                                                                         | Safehouse acts like a normal house if a member of the safehouse is connected                                                                        |
| FACTION                                           | true                                                                                          | Players can create factions when true                                                                                                               |
| FACTION_DAY_SURVIVED_TO_CREATE                    | 0                                                                                             | Players must survive this number of in-game days before being allowed to create a faction                                                           |
| FACTION_PLAYERS_REQUIRED_FOR_TAG                  | 1                                                                                             | Number of players required as faction members before the faction owner can create a group tag                                                       |
| DISABLE_RADIO_STAFF                               | false                                                                                         | Disables radio transmissions from players with an access level                                                                                      |
| DISABLE_RADIO_ADMIN                               | true                                                                                          | Disables radio transmissions from players with 'admin' access level                                                                                 |
| DISABLE_RADIO_GM                                  | true                                                                                          | Disables radio transmissions from players with 'gm' access level                                                                                    |
| DISABLE_RADIO_OVERSEER                            | false                                                                                         | Disables radio transmissions from players with 'overseer' access level                                                                              |
| DISABLE_RADIO_MODERATOR                           | false                                                                                         | Disables radio transmissions from players with 'moderator' access level                                                                             |
| DISABLE_RADIO_INVISIBLE                           | true                                                                                          | Disables radio transmissions from invisible players                                                                                                 |
| CLIENT_COMMAND_FILTER                             | -vehicle.*;+vehicle.damageWindow;+vehicle.fixPart;+vehicle.installPart;+vehicle.uninstallPart | Semicolon-separated list of commands that will not be written to the cmd.txt server log.                                                            |
| CLIENT_ACTION_LOGS                                | ISEnterVehicle;ISExitVehicle;ISTakeEngineParts;                                               | Semicolon-separated list of actions that will be written to the ClientActionLogs.txt server log.                                                    |
| PERK_LOGS                                         | true                                                                                          | Track changes in player perk levels in PerkLog.txt server log                                                                                       |
| ITEM_NUMBERS_LIMIT_PER_CONTAINER                  | 0                                                                                             | Maximum number of items that can be placed in a container.                                                                                          |
| BLOOD_SPLAT_LIFESPAN_DAYS                         | 0                                                                                             | Number of days before old blood splats are removed.                                                                                                 |
| ALLOW_NON_ASCII_USERNAME                          | false                                                                                         | Allow use of non-ASCII (cyrillic etc) characters in usernames                                                                                       |
| BAN_KICK_GLOBAL_SOUND                             | true                                                                                          | Ban kick global sound                                                                                                                               |
| REMOVE_PLAYER_CORPSES_ON_CORPSE_REMOVAL           | false                                                                                         | If enabled, when HoursForCorpseRemoval triggers, it will also remove player?s corpses from the ground.                                              |
| TRASH_DELETE_ALL                                  | false                                                                                         | If true, player can use the "delete all" button on bins                                                                                             |
| PVP_MELEE_WHILE_HIT_REACTION                      | false                                                                                         | If true, player can hit again when struck by another player.                                                                                        |
| MOUSE_OVER_TO_SEE_DISPLAY_NAME                    | true                                                                                          | If true, players will have to mouse over someone to see their display name.                                                                         |
| HIDE_PLAYERS_BEHIND_YOU                           | true                                                                                          | If true, automatically hide the player you can't see (like zombies).                                                                                |
| PVP_MELEE_DAMAGE_MODIFIER                         | 30.0                                                                                          | Damage multiplier for PVP melee attacks.                                                                                                            |
| PVP_FIREARM_DAMAGE_MODIFIER                       | 50.0                                                                                          | Damage multiplier for PVP ranged attacks.                                                                                                           |
| CAR_ENGINE_ATTRACTION_MODIFIER                    | 0.5                                                                                           | Modify the range of zombie attraction to cars.                                                                                                      |
| PLAYER_BUMP_PLAYER                                | false                                                                                         | Governs whether players bump (and knock over) other players when running through them.                                                              |
| MAP_REMOTE_PLAYER_VISIBILITY                      | 1                                                                                             | Controls display of remote players on the in-game map.                                                                                              |
| BACKUPS_COUNT                                     | 5                                                                                             | Backups count                                                                                                                                       |
| BACKUPS_ON_START                                  | true                                                                                          | Backups on start                                                                                                                                    |
| BACKUPS_ON_VERSION_CHANGE                         | true                                                                                          | Backups on version change                                                                                                                           |
| BACKUPS_PERIOD                                    | 0                                                                                             | Backups period                                                                                                                                      |
| ANTI_CHEAT_PROTECTION_TYPE1                       | true                                                                                          | Anti cheat protection type 1                                                                                                                        |
| ANTI_CHEAT_PROTECTION_TYPE2                       | true                                                                                          | Anti cheat protection type 2                                                                                                                        |
| ANTI_CHEAT_PROTECTION_TYPE3                       | true                                                                                          | Anti cheat protection type 3                                                                                                                        |
| ANTI_CHEAT_PROTECTION_TYPE4                       | true                                                                                          | Anti cheat protection type 4                                                                                                                        |
| ANTI_CHEAT_PROTECTION_TYPE5                       | true                                                                                          | Anti cheat protection type 5                                                                                                                        |
| ANTI_CHEAT_PROTECTION_TYPE6                       | true                                                                                          | Anti cheat protection type 6                                                                                                                        |
| ANTI_CHEAT_PROTECTION_TYPE7                       | true                                                                                          | Anti cheat protection type 7                                                                                                                        |
| ANTI_CHEAT_PROTECTION_TYPE8                       | true                                                                                          | Anti cheat protection type 8                                                                                                                        |
| ANTI_CHEAT_PROTECTION_TYPE9                       | true                                                                                          | Anti cheat protection type 9                                                                                                                        |
| ANTI_CHEAT_PROTECTION_TYPE10                      | true                                                                                          | Anti cheat protection type 10                                                                                                                       |
| ANTI_CHEAT_PROTECTION_TYPE11                      | true                                                                                          | Anti cheat protection type 11                                                                                                                       |
| ANTI_CHEAT_PROTECTION_TYPE12                      | true                                                                                          | Anti cheat protection type 12                                                                                                                       |
| ANTI_CHEAT_PROTECTION_TYPE13                      | true                                                                                          | Anti cheat protection type 13                                                                                                                       |
| ANTI_CHEAT_PROTECTION_TYPE14                      | true                                                                                          | Anti cheat protection type 14                                                                                                                       |
| ANTI_CHEAT_PROTECTION_TYPE15                      | true                                                                                          | Anti cheat protection type 15                                                                                                                       |
| ANTI_CHEAT_PROTECTION_TYPE16                      | true                                                                                          | Anti cheat protection type 16                                                                                                                       |
| ANTI_CHEAT_PROTECTION_TYPE17                      | true                                                                                          | Anti cheat protection type 17                                                                                                                       |
| ANTI_CHEAT_PROTECTION_TYPE18                      | true                                                                                          | Anti cheat protection type 18                                                                                                                       |
| ANTI_CHEAT_PROTECTION_TYPE19                      | true                                                                                          | Anti cheat protection type 19                                                                                                                       |
| ANTI_CHEAT_PROTECTION_TYPE20                      | true                                                                                          | Anti cheat protection type 20                                                                                                                       |
| ANTI_CHEAT_PROTECTION_TYPE21                      | true                                                                                          | Anti cheat protection type 21                                                                                                                       |
| ANTI_CHEAT_PROTECTION_TYPE22                      | true                                                                                          | Anti cheat protection type 22                                                                                                                       |
| ANTI_CHEAT_PROTECTION_TYPE23                      | true                                                                                          | Anti cheat protection type 23                                                                                                                       |
| ANTI_CHEAT_PROTECTION_TYPE24                      | true                                                                                          | Anti cheat protection type 24                                                                                                                       |
| ANTI_CHEAT_PROTECTION_TYPE2_THRESHOLD_MULTIPLIER  | 3.0                                                                                           | Anti cheat protection type 2 threshold multiplier                                                                                                   |
| ANTI_CHEAT_PROTECTION_TYPE3_THRESHOLD_MULTIPLIER  | 1.0                                                                                           | Anti cheat protection type 3 threshold multiplier                                                                                                   |
| ANTI_CHEAT_PROTECTION_TYPE4_THRESHOLD_MULTIPLIER  | 1.0                                                                                           | Anti cheat protection type 4 threshold multiplier                                                                                                   |
| ANTI_CHEAT_PROTECTION_TYPE9_THRESHOLD_MULTIPLIER  | 1.0                                                                                           | Anti cheat protection type 9 threshold multiplier                                                                                                   |
| ANTI_CHEAT_PROTECTION_TYPE15_THRESHOLD_MULTIPLIER | 1.0                                                                                           | Anti cheat protection type 15 threshold multiplier                                                                                                  |
| ANTI_CHEAT_PROTECTION_TYPE20_THRESHOLD_MULTIPLIER | 1.0                                                                                           | Anti cheat protection type 20 threshold multiplier                                                                                                  |
| ANTI_CHEAT_PROTECTION_TYPE22_THRESHOLD_MULTIPLIER | 1.0                                                                                           | Anti cheat protection type 22 threshold multiplier                                                                                                  |
| ANTI_CHEAT_PROTECTION_TYPE24_THRESHOLD_MULTIPLIER | 6.0                                                                                           | Anti cheat protection type 24 threshold multiplier                                                                                                  |

## Developer information

### Building the image

You can build the image from the Dockerfile using the following command:

```bash
docker build -t indifferentbroccoli/projectzomboid-server-docker .
```

### Scripts

#### init.sh

Entrypoint of the container. This script will check if the server is installed and if not, it will install it.
Also has a term_handler function to catch SIGTERM signals to gracefully stop the server.
Features basic checks that will confirm if the server can be started.

#### start.sh

Starts the server with the settings from the .env file.
Will also call the compile-settings.sh script to generate the server settings.

#### install.scmd

Installs the server. This script will download the server files using SteamCMD and extract them to the server directory.

#### funtions.sh

Contains functions that are used in the other scripts.

#### compile-settings.sh

Generates the server settings file from the .env file.
Uses envsubst to replace the variables in the settings.ini.template file.
