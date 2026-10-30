#!/bin/sh
# SPDX-License-Identifier: MIT
#
# God's Eye View for Railway (community template): builds and serves the app.
#
#   gev-app.sh build   vite build, then record which browser keys went in
#   gev-app.sh serve   rebuild if those keys changed, then exec `vite preview`
#
# Runs as the unprivileged `node` user (railway-entrypoint.sh drops root).
set -eu

APP_DIR=${GEV_APP_DIR:-/app}
STATE_DIR="$APP_DIR/.gev-build"
FINGERPRINT_FILE="$STATE_DIR/browser-keys.sha256"
VITE="$APP_DIR/node_modules/vite/bin/vite.js"
HEALTHCHECK_HOST=healthcheck.railway.app

log() { printf '[gev] %s\n' "$*"; }
fail() { printf '[gev] ERROR: %s\n' "$*" >&2; exit 1; }

# Vite writes GOOGLE_MAPS_API_KEY, CESIUM_ION_TOKEN and MAPILLARY_CLIENT_TOKEN
# into the browser bundle at build time (upstream build/vite.js `define`). A
# hash of the three lets `serve` notice a bundle built with other keys without
# storing the keys a second time. Unset and empty count as the same.
browser_key_fingerprint() {
  fp=$(printf 'GOOGLE_MAPS_API_KEY=%s\nCESIUM_ION_TOKEN=%s\nMAPILLARY_CLIENT_TOKEN=%s\n' \
    "${GOOGLE_MAPS_API_KEY:-}" "${CESIUM_ION_TOKEN:-}" "${MAPILLARY_CLIENT_TOKEN:-}" \
    | sha256sum) || return 1
  fp=${fp%% *}
  case "$fp" in
    '' | *[!0-9a-f]*) return 1 ;;
  esac
  [ "${#fp}" -eq 64 ] || return 1
  printf '%s\n' "$fp"
}

# Every step checks its own status: callers run this inside `if`, where
# `set -e` does not apply.
build_app() {
  cd "$APP_DIR" || return 1
  log "building the browser bundle (vite build)"
  node "$VITE" build || return 1
  [ -f dist/index.html ] || { log "vite build produced no dist/index.html"; return 1; }
  mkdir -p "$STATE_DIR" || return 1
  browser_key_fingerprint > "$FINGERPRINT_FILE" || return 1
  log "browser bundle ready"
}

rebuild_if_keys_changed() {
  want=$(browser_key_fingerprint) || fail "could not hash the browser keys (sha256sum)"
  have=$(cat "$FINGERPRINT_FILE" 2>/dev/null || true)
  if [ "$want" = "$have" ]; then
    log "browser bundle matches the configured map keys"
    return 0
  fi
  if [ "${GEV_REBUILD_ON_KEY_CHANGE:-true}" != true ]; then
    log "WARNING: GOOGLE_MAPS_API_KEY, CESIUM_ION_TOKEN or MAPILLARY_CLIENT_TOKEN differ from the build, and GEV_REBUILD_ON_KEY_CHANGE is not true: serving the bundle as built. Redeploy to rebuild."
    return 0
  fi
  # Railway rebuilds the image on a normal deploy, so this is a fallback for a
  # container started with keys the image was not built with.
  log "map keys differ from the ones this image was built with: rebuilding at start (a few minutes, about 2 GB of memory)"
  cd "$APP_DIR"
  rm -rf dist.previous
  if [ -d dist ]; then mv dist dist.previous; fi
  if build_app; then
    rm -rf dist.previous
  else
    log "ERROR: the rebuild failed; serving the previous bundle (built with the image's keys). Redeploy the service so Railway's builder rebuilds it, or give the service more memory."
    rm -rf dist
    if [ -d dist.previous ]; then mv dist.previous dist; fi
  fi
}

serve() {
  cd "$APP_DIR"

  port=${PORT:-4173}
  case "$port" in
    '' | *[!0-9]*) fail "PORT must be a number (got '$port')" ;;
  esac

  # Dual-stack where the container has IPv6 (Node's `::` socket also accepts
  # IPv4), IPv4 otherwise. Set HOST to override.
  if [ -z "${HOST:-}" ]; then
    if [ -s /proc/net/if_inet6 ]; then HOST='::'; else HOST='0.0.0.0'; fi
  fi
  export HOST

  # Upstream answers only Host headers on its allowlist (IP addresses,
  # localhost and GEV_ALLOWED_HOSTS). The gateway forwards the public Host;
  # Railway's healthcheck sends Host: healthcheck.railway.app.
  if [ -z "${GEV_ALLOWED_HOSTS:-}" ]; then
    log "WARNING: GEV_ALLOWED_HOSTS is empty: browsers will get 403 'host is not allowed'. Set it to the gateway's public domain (and any custom domain)."
  fi
  GEV_ALLOWED_HOSTS="${GEV_ALLOWED_HOSTS:+$GEV_ALLOWED_HOSTS,}$HEALTHCHECK_HOST"
  export GEV_ALLOWED_HOSTS

  # Provider Settings is development-only and refuses proxied requests anyway;
  # make sure no trusted-peer list from a copied .env can widen it.
  unset GEV_KEY_SETUP_TRUSTED_PEERS

  if grep -qs " $APP_DIR/.gev-cache " /proc/mounts; then
    log "disk cache: $APP_DIR/.gev-cache (volume)"
  else
    log "WARNING: $APP_DIR/.gev-cache is not a volume; cached feeds and the TomTom daily budget reset on every deploy"
  fi

  rebuild_if_keys_changed
  [ -f dist/index.html ] || fail "no browser bundle (dist/index.html is missing)"

  log "serving on [$HOST]:$port, hosts: $GEV_ALLOWED_HOSTS"
  exec node "$VITE" preview --host "$HOST" --port "$port" --strictPort
}

case "${1:-}" in
  build) build_app || fail "vite build failed" ;;
  serve) serve ;;
  *) fail "usage: gev-app.sh build|serve" ;;
esac
