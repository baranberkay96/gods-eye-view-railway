# syntax=docker/dockerfile:1
#
# God's Eye View for Railway (community template).
#
# Builds the tagged upstream release and serves the production build with
# `vite preview`. Upstream's own Dockerfile runs the Vite dev server on a
# bind-mounted checkout. The preview server runs the same data and API
# middleware (every provider in server/providers registers
# configurePreviewServer), but serves a built bundle: no on-the-fly module
# transforms, no file watcher, no HMR socket. Provider Settings (the in-app key
# form) is development-only upstream; keys are Railway variables here.
#
# Persistence: the disk cache lives on a Railway volume at /app/.gev-cache,
# declared in template.json. No VOLUME instruction (Railway rejects it).

# --- 1. Source: exactly one pinned commit -----------------------------------
FROM node:24.22.2-bookworm-slim@sha256:c86ecead9e55a5210ac1727de38a4ca840bf03dcaf34dc9749addbf383b1920c AS source

# Railway passes service variables with these names as build args, so an
# upgrade can be tried without editing this file.
ARG GEV_REPO=https://github.com/bilawalsidhu/gods-eye-view.git
ARG GEV_VERSION=v0.3.0
ARG GEV_COMMIT=72eb3fdc739991a1286b7f1251de908e9744bb2a

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates git \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src
# Fetch the commit by id and check it, so a moved tag cannot change the build.
# docs/ (71 MB of media) and CI files are not used by the build or the server.
RUN set -eu; \
    git init -q .; \
    git remote add origin "$GEV_REPO"; \
    git fetch -q --depth 1 origin "$GEV_COMMIT"; \
    git -c advice.detachedHead=false checkout -q FETCH_HEAD; \
    head="$(git rev-parse HEAD)"; \
    [ "$head" = "$GEV_COMMIT" ] || { echo "fetched $head, expected $GEV_COMMIT" >&2; exit 1; }; \
    grep -q "\"version\": \"${GEV_VERSION#v}\"" package.json \
      || { echo "package.json at $GEV_COMMIT is not version ${GEV_VERSION#v}" >&2; exit 1; }; \
    rm -rf .git .github docs

# --- 2. App: dependencies, browser bundle, runtime ---------------------------
FROM node:24.22.2-bookworm-slim@sha256:c86ecead9e55a5210ac1727de38a4ca840bf03dcaf34dc9749addbf383b1920c

# Puppeteer is only used by upstream's QA scripts; skip its Chromium download
# (upstream's Dockerfile does the same).
ENV PUPPETEER_SKIP_DOWNLOAD=1 \
    NPM_CONFIG_AUDIT=false \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_UPDATE_NOTIFIER=false

WORKDIR /app
RUN chown node:node /app
USER node

# vite and vite-plugin-cesium are devDependencies and are needed at run time
# (vite preview loads the same config), so the full lockfile is installed.
COPY --from=source --chown=node:node /src/package.json /src/package-lock.json ./
RUN npm ci && npm cache clean --force

COPY --from=source --chown=node:node /src/ ./
RUN mkdir -p .gev-cache .gev-logs

COPY railway-entrypoint.sh gev-app.sh /opt/railway/
RUN sh -n /opt/railway/railway-entrypoint.sh && sh -n /opt/railway/gev-app.sh

# The three keys Vite writes into the browser bundle (build/vite.js `define`).
# Railway passes service variables of these names as build args. They are
# browser-visible by design; restrict them at the provider (see README).
ARG GOOGLE_MAPS_API_KEY
ARG CESIUM_ION_TOKEN
ARG MAPILLARY_CLIENT_TOKEN
RUN NODE_OPTIONS=--max-old-space-size=4096 sh /opt/railway/gev-app.sh build

# Start as root only to hand the volume to the `node` user; the entrypoint
# then drops privileges with setpriv before anything else runs.
USER root
ENV PORT=4173
EXPOSE 4173
CMD ["/bin/sh", "/opt/railway/railway-entrypoint.sh"]
