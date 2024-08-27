#BUILD THE RCON-CLI PACKAGE
FROM golang:1.23.0-alpine AS rcon-cli_builder

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
FROM cm2network/steamcmd:root

RUN apt-get update && apt-get install -y --no-install-recommends \
    gettext-base=0.21-12 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=rcon-cli_builder /build/gorcon /usr/bin/rcon-cli

LABEL maintainer="support@indifferentbroccoli.com" \
      name="indifferentbroccoli/projectzomboid-server-docker" \
      github="https://github.com/indifferentbroccoli/projectzomboid-server-docker" \
      dockerhub="https://hub.docker.com/r/indifferentbroccoli/projectzomboid-server-docker"

ENV HOME=/home/steam \
    CONFIG_DIR=/project-zomboid-config \
    DEFAULT_PORT=16261 \
    UDP_PORT=16262 \
    RCON_PORT=27015 \
    SERVER_NAME=indifferentbroccoli \
    STEAM_VAC=true \
    USE_STEAM=true \
    GENERATE_SETTINGS=true

COPY ./scripts /home/steam/server/

COPY branding /branding

RUN cp /home/steam/.steam/sdk64/steamclient.so /home/steam/server/steamclient.so && \
    mkdir -p /project-zomboid /project-zomboid-config && \
    chmod +x /home/steam/server/*.sh

WORKDIR /home/steam/server

ENTRYPOINT ["/home/steam/server/init.sh"]