# syntax=docker/dockerfile:1
# check=error=true

ARG DENO_VERSION="2.6.4"
ARG TINI_VERSION="0.19.0"

ARG DENO_DIR="/deno-dir/" DENO_USER="deno"

# ++++ ---- ==== ****

FROM ghcr.io/tcely/docker-tini:main@sha256:d57e136fc426e768461935e497702f8ca8b18d6751564f8a81877538e0554080 AS tini-bin
FROM scratch AS tini
ARG TARGETARCH TINI_VERSION
COPY --from=tini-bin "/releases/v${TINI_VERSION}/tini-static-${TARGETARCH}" /tini

FROM denoland/deno:bin-${DENO_VERSION} AS deno-bin
FROM scratch AS deno
COPY --from=deno-bin /deno /deno

# ====== ------ ======

FROM debian:13-slim AS deno-debian
# Debian 13 = trixie

ARG DENO_DIR DENO_USER
RUN useradd --uid 1993 --user-group "${DENO_USER}" \
  && mkdir -v -p "${DENO_DIR}" \
  && chown -v "${DENO_USER}:${DENO_USER}" "${DENO_DIR}"

COPY --from=tini /tini /tini

ARG DENO_VERSION
ENV DENO_USE_CGROUPS=1 \
    DENO_DIR="${DENO_DIR}" \
    DENO_INSTALL_ROOT='/usr/local' \
    DENO_VERSION="${DENO_VERSION}"

COPY --from=deno /deno /usr/bin/deno

ENTRYPOINT ["/tini", "--", "/usr/bin/env"]
CMD ["deno", "eval", "console.log('Welcome to Deno!')"]

FROM deno-debian AS kira-build

USER "${DENO_USER}"
WORKDIR "${DENO_DIR}"
WORKDIR /app
WORKDIR /build

COPY ./ ./

# Create a stand-alone proxy binary.
# Importantly, before node_modules is created.
RUN deno compile --output /app/proxy --allow-net proxy/deno.ts

# Create and populate node_modules.
RUN deno install --npm

RUN deno task build
