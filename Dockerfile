#BUILD THE RCON-CLI PACKAGE
FROM golang:1.23.1-alpine AS rcon-cli_builder

ARG RCON_VERSION="0.10.3"
ARG RCON_TGZ_SHA1SUM=33ee8077e66bea6ee097db4d9c923b5ed390d583

WORKDIR /build

# install rcon
SHELL ["/bin/ash", "-o", "pipefail", "-c"]

ENV CGO_ENABLED=0
RUN wget -q https://github.com/gorcon/rcon-cli/archive/refs/tags/v${RCON_VERSION}.tar.gz -O rcon.tar.gz \
    && echo "${RCON_TGZ_SHA1SUM}" rcon.tar.gz | sha1sum -c - \
    && tar -xzvf rcon.tar.gz \
    && rm rcon.tar.gz \
    && mv rcon-cli-${RCON_VERSION}/* ./ \
    && rm -rf rcon-cli-${RCON_VERSION} \
    && go build -v ./cmd/gorcon

#BUILD THE SERVER IMAGE
FROM --platform=linux/amd64 debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    unzip \
    gettext-base \
    procps \
    jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install .NET 8 runtime (required for DepotDownloader)
RUN curl -sL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh && \
    chmod +x /tmp/dotnet-install.sh && \
    /tmp/dotnet-install.sh --channel 8.0 --runtime dotnet --install-dir /usr/share/dotnet && \
    ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet && \
    rm /tmp/dotnet-install.sh

# Download DepotDownloader
ARG DEPOT_DOWNLOADER_VERSION=3.4.0
RUN curl -sL \
    "https://github.com/SteamRE/DepotDownloader/releases/download/DepotDownloader_${DEPOT_DOWNLOADER_VERSION}/DepotDownloader-linux-x64.zip" \
    -o /tmp/dd.zip && \
    mkdir -p /depotdownloader && \
    unzip /tmp/dd.zip -d /depotdownloader && \
    chmod +x /depotdownloader/DepotDownloader && \
    rm /tmp/dd.zip

RUN useradd -m -s /bin/bash steam

RUN chmod 777 /home/steam/

COPY --from=rcon-cli_builder /build/gorcon /usr/bin/rcon-cli

LABEL maintainer="support@indifferentbroccoli.com" \
      name="indifferentbroccoli/projectzomboid-server-docker" \
      github="https://github.com/indifferentbroccoli/projectzomboid-server-docker" \
      dockerhub="https://hub.docker.com/r/indifferentbroccoli/projectzomboid-server-docker"

ENV HOME=/home/steam \
    CONFIG_DIR=/project-zomboid-config \
    ADMIN_USERNAME=admin \
    ADMIN_PASSWORD=admin \
    DEFAULT_PORT=16261 \
    UDP_PORT=16262 \
    RCON_PORT=27015 \
    MAX_PLAYERS=32 \
    SERVER_NAME=pzserver \
    STEAM_VAC=true \
    USE_STEAM=true \
    SERVER_BRANCH="" \
    MEMORY_XMX_GB=8 \
    MEMORY_XMS_GB="" \
    VM_ARGS=""

COPY ./scripts /home/steam/server/

RUN chmod 777 /home/steam/server/

COPY branding /branding

RUN mkdir -p /project-zomboid /project-zomboid-config && \
    chmod +x /home/steam/server/*.sh

WORKDIR /home/steam/server

HEALTHCHECK --start-period=5m \
            CMD pgrep "ProjectZomboid" > /dev/null || exit 1

ENTRYPOINT ["/home/steam/server/init.sh"]