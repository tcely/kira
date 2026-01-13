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
WORKDIR /dist
WORKDIR /source
WORKDIR /build

COPY ./ ./
COPY ./ /source/

# Create and populate node_modules, but don't store it.
# The final output should only be in `dist`.
RUN deno install --npm && \
    DENO_COMPAT=1 deno task build && \
    cp -v -a -t /dist/ dist/* && \
    rm -rf node_modules && \
    deno clean

# Create a stand-alone proxy binary.
RUN deno compile --output /app/proxy \
        --allow-env=HOST,PORT --allow-net \
        --exclude package.json \
        proxy/deno.ts

# Create a stand-alone server binary.
RUN deno compile --output /app/server \
        --allow-env=HOST,PORT --allow-net --allow-read=. \
        --exclude package.json \
        --include dist \
        server/deno.ts
