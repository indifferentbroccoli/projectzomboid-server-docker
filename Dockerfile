# syntax=docker/dockerfile:1.7

# Build rcon-cli for the final image architecture without emulating the target.
FROM --platform=$BUILDPLATFORM golang:1.23.1-alpine AS rcon-cli-builder

ARG TARGETOS
ARG TARGETARCH
ARG RCON_VERSION="0.10.3"
ARG RCON_SOURCE_SHA256="e871753e970300ff4fade6bc7e39eb086fd7a87c772657870b071b9e5f0468fe"

WORKDIR /build
SHELL ["/bin/ash", "-o", "pipefail", "-c"]

RUN wget -q \
      "https://github.com/gorcon/rcon-cli/archive/refs/tags/v${RCON_VERSION}.tar.gz" \
      -O /tmp/rcon.tar.gz \
    && echo "${RCON_SOURCE_SHA256}  /tmp/rcon.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/rcon.tar.gz --strip-components=1 -C /build \
    && CGO_ENABLED=0 GOOS="${TARGETOS}" GOARCH="${TARGETARCH}" \
      go build -trimpath -ldflags="-s -w" -o /build/rcon-cli ./cmd/gorcon

# Select and verify the self-contained DepotDownloader package for the final
# image architecture. This stage runs on the build platform because extracting
# an archive does not require target emulation.
FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS depotdownloader

ARG TARGETARCH
ARG DEPOT_DOWNLOADER_VERSION="3.4.0"
ARG DEPOT_DOWNLOADER_SHA256_AMD64="a999dec66b4850fc961bd50366696d23c2d0fad7b18790e6a5647b2f19097a53"
ARG DEPOT_DOWNLOADER_SHA256_ARM64="d9fb612ccebc1db8eeea3b4045d2221ec70431381393ce908fb72f01d4f9c812"

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl file unzip \
    && case "${TARGETARCH}" in \
      amd64) archive_arch="x64"; archive_sha256="${DEPOT_DOWNLOADER_SHA256_AMD64}"; file_arch="x86-64" ;; \
      arm64) archive_arch="arm64"; archive_sha256="${DEPOT_DOWNLOADER_SHA256_ARM64}"; file_arch="ARM aarch64" ;; \
      *) echo "Unsupported target architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && curl -fL --retry 3 \
      "https://github.com/SteamRE/DepotDownloader/releases/download/DepotDownloader_${DEPOT_DOWNLOADER_VERSION}/DepotDownloader-linux-${archive_arch}.zip" \
      -o /tmp/depotdownloader.zip \
    && echo "${archive_sha256}  /tmp/depotdownloader.zip" | sha256sum -c - \
    && mkdir -p /out/depotdownloader \
    && unzip -q /tmp/depotdownloader.zip -d /out/depotdownloader \
    && chmod 0755 /out/depotdownloader/DepotDownloader \
    && file /out/depotdownloader/DepotDownloader | grep -Fq "${file_arch}"

# This stage is reachable only from an arm64 build. It compiles a generic ARM64
# dynarec and installs the runtime binary, default rc file, and the two x86-64
# GCC runtime libraries required by Project Zomboid's native JNI libraries.
FROM --platform=$TARGETPLATFORM debian:bookworm-slim AS box64-builder-arm64

ARG TARGETARCH
ARG BOX64_COMMIT="15e065ae5dd0207fe4f6cfce565884f68567d64f"
ARG BOX64_SOURCE_SHA256="01874a88c78d165aaecbde9d57aac2ef25ce19931ed187ae42a9d76b5d6979c6"

RUN test "${TARGETARCH}" = "arm64" \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      cmake \
      curl \
      python3 \
    && curl -fL --retry 3 \
      "https://codeload.github.com/ptitSeb/box64/tar.gz/${BOX64_COMMIT}" \
      -o /tmp/box64.tar.gz \
    && echo "${BOX64_SOURCE_SHA256}  /tmp/box64.tar.gz" | sha256sum -c - \
    && mkdir -p /src /build /opt/box64-root \
    && tar -xzf /tmp/box64.tar.gz --strip-components=1 -C /src \
    && cmake -S /src -B /build \
      -DARM_DYNAREC=ON \
      -DCMAKE_BUILD_TYPE=Release \
      -DNOGIT=ON \
    && cmake --build /build --parallel "$(nproc)" \
    && install -D -m 0755 /build/box64 /opt/box64-root/usr/local/bin/box64 \
    && install -D -m 0644 /src/system/box64.box64rc /opt/box64-root/etc/box64.box64rc \
    && install -D -m 0644 /src/x64lib/libstdc++.so.6 \
      /opt/box64-root/usr/lib/box64-x86_64-linux-gnu/libstdc++.so.6 \
    && install -D -m 0644 /src/x64lib/libgcc_s.so.1 \
      /opt/box64-root/usr/lib/box64-x86_64-linux-gnu/libgcc_s.so.1 \
    && install -D -m 0644 /src/LICENSE /opt/box64-root/usr/share/doc/box64/LICENSE

# Give the final COPY a real but empty source for amd64. BuildKit prunes the
# unselected Box64 branch, so amd64 builds do not compile or contain Box64.
FROM --platform=$TARGETPLATFORM debian:bookworm-slim AS platform-assets-amd64
RUN mkdir -p /opt/box64-root

FROM box64-builder-arm64 AS platform-assets-arm64

FROM platform-assets-${TARGETARCH} AS platform-assets

# The runtime base resolves naturally to TARGETPLATFORM.
FROM debian:bookworm-slim

ARG TARGETARCH
ARG TARGETPLATFORM

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      file \
      gettext-base \
      jq \
      libgcc-s1 \
      libicu72 \
      libssl3 \
      libstdc++6 \
      procps \
      util-linux \
      zlib1g \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash steam

COPY --from=rcon-cli-builder /build/rcon-cli /usr/bin/rcon-cli
COPY --from=depotdownloader /out/depotdownloader /depotdownloader
COPY --from=platform-assets /opt/box64-root/ /

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
    VM_ARGS="" \
    PZ_EMULATOR="" \
    ARM64_JVM_PROFILE=compatibility \
    ARM64_VM_ARGS="" \
    BOX64_DYNAREC_STRONGMEM=3 \
    BOX64_DYNAREC_SAFEFLAGS=2 \
    BOX64_DYNAREC_ALIGNED_ATOMICS=1 \
    BOX64_DYNAREC_BIGBLOCK=0 \
    BOX64_DYNAREC_CALLRET=0 \
    BOX64_JVM=0 \
    BOX64_SSE42=0 \
    BOX64_MAXCPU=4 \
    IMAGE_ARCH=${TARGETARCH} \
    IMAGE_PLATFORM=${TARGETPLATFORM}

COPY ./scripts /home/steam/server/
COPY branding /branding

RUN mkdir -p /project-zomboid /project-zomboid-config \
    && chmod 0755 /home/steam/server/*.sh

WORKDIR /home/steam/server

HEALTHCHECK --interval=30s --timeout=10s --start-period=40m --retries=5 \
    CMD ["/home/steam/server/healthcheck.sh"]

ENTRYPOINT ["/home/steam/server/init.sh"]
