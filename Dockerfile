# syntax=docker/dockerfile:1
# check=error=true

# Debian 13 = trixie
ARG DEBIAN_VERSION="13"
ARG DENO_VERSION="2.6.4"
ARG TINI_VERSION="0.19.0"

ARG DENO_DIR="/var/cache/deno/deno-dir" DENO_USER="deno"

# ++++ ---- ==== ****

FROM ghcr.io/tcely/docker-tini:main@sha256:d57e136fc426e768461935e497702f8ca8b18d6751564f8a81877538e0554080 AS tini-bin
FROM scratch AS tini
ARG TARGETARCH TINI_VERSION
COPY --from=tini-bin "/releases/v${TINI_VERSION}/tini-static-${TARGETARCH}" /tini

FROM denoland/deno:bin-${DENO_VERSION} AS deno-bin
FROM scratch AS deno
COPY --from=deno-bin /deno /deno

# ====== ------ ======

FROM "debian:${DEBIAN_VERSION}-slim" AS deno-debian

ARG DENO_DIR DENO_USER
RUN useradd --uid 1993 --user-group "${DENO_USER}" && \
    mkdir -v -p "${DENO_DIR}" && \
    chown -v "${DENO_USER}:${DENO_USER}" "${DENO_DIR}" "${DENO_DIR}"/.. && \
    chown -v root:root /
  

#COPY --from=tini /tini /tini

ARG DENO_VERSION
ENV DENO_USE_CGROUPS=1 \
    DENO_DIR="${DENO_DIR}" \
    DENO_INSTALL_ROOT='/usr/local' \
    DENO_VERSION="${DENO_VERSION}"

COPY --from=deno /deno /usr/bin/deno

#ENTRYPOINT ["/tini", "--", "/usr/bin/env"]
#CMD ["deno", "eval", "console.log('Welcome to Deno!')"]

FROM deno-debian AS kira-build

USER "${DENO_USER}"
WORKDIR "${DENO_DIR}"
WORKDIR /app
WORKDIR /dist
WORKDIR /source
WORKDIR /build

COPY ./ ./
COPY ./ /source/

# Create a stand-alone proxy binary.
RUN deno compile --output /app/proxy \
        --allow-env=HOST,PORT --allow-net \
        --exclude package.json \
        proxy/deno.ts

# Create and populate node_modules, but don't store it.
# The final output should only be in `dist`.
RUN deno install --npm && \
    DENO_COMPAT=1 deno task build && \
    cp -v -a -t /dist/ dist/* && \
    rm -rf node_modules && \
    set -x && ls -al "${DENO_DIR}"/.. && \
    deno info && (deno clean || :)

# Create a stand-alone server binary.
RUN deno compile --output /app/server \
        --allow-env=HOST,PORT,WHICH --allow-net --allow-read=. \
        --exclude package.json \
        --include dist \
        server/deno.ts

FROM "gcr.io/distroless/cc-debian${DEBIAN_VERSION}:debug" AS kira
SHELL ["/busybox/busybox", "sh", "-c"]

COPY --from=tini /tini /tini
#COPY --from=deno /deno /usr/bin/deno

ARG DEBIAN_VERSION DENO_VERSION TINI_VERSION
ARG KIRA_VERSION="0.0.1"
ENV DENO_USE_CGROUPS=1 \
    DENO_VERSION="${DENO_VERSION}" \
    DEBIAN_VERSION="${DEBIAN_VERSION}" \
    KIRA_VERSION="${KIRA_VERSION}" \
    TINI_VERSION="${TINI_VERSION}"

WORKDIR /usr/src/kira
COPY --from=kira-build /source/ ./

WORKDIR /app
COPY --from=kira-build /app/server ./

WORKDIR /dist
COPY --from=kira-build /dist/ ./

EXPOSE 8000
USER nonroot
ENTRYPOINT ["/tini", "--"]
CMD ["/app/server"]
