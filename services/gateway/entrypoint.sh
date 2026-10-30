#!/bin/sh
# SPDX-License-Identifier: MIT
#
# God's Eye View gateway (Railway community template): writes the login block
# and the request-header rules the Caddyfile imports, validates, starts Caddy.
set -eu

fail() { printf '[gateway] ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf '[gateway] %s\n' "$*"; }

CONF_DIR=/tmp/gev-gateway
CADDYFILE=/etc/caddy/Caddyfile

upstream="${GEV_APP_UPSTREAM:-}"
case "$upstream" in
  "" | :*) fail "GEV_APP_UPSTREAM has no host ('$upstream'); it must be the private host:port of the gods-eye-view service" ;;
  *[!A-Za-z0-9.:-]*) fail "GEV_APP_UPSTREAM must be host:port (got '$upstream')" ;;
esac

public="${GEV_PUBLIC_ACCESS:-false}"
case "$public" in
  true | false) ;;
  *) fail "GEV_PUBLIC_ACCESS must be true or false (got '$public')" ;;
esac

mkdir -p "$CONF_DIR"

if [ "$public" = true ]; then
  log "GEV_PUBLIC_ACCESS=true: NO login. Anyone with the URL can use the globe; the Google Maps and Cesium ion keys in the page are visible to every visitor."
  log "Public mode keeps the proxy headers, so the app refuses its cost-bearing routes (voice, AI summary, Google place search, Mapillary, TomTom), as upstream does behind any reverse proxy."
  # A no-op handler keeps the import non-empty.
  printf 'vars gev_login off\n' > "$CONF_DIR/auth.caddy"
  cat > "$CONF_DIR/upstream.caddy" <<'EOF'
# Public mode. Caddy's X-Forwarded-* and Via headers stay, so upstream's
# same-site gate (src/localRequestGate.mjs) treats every request as proxied and
# refuses the routes that spend provider keys. Railway's edge only serves
# HTTPS; the keyless routes (terrain heights, cameras) compare a browser's
# Origin with this scheme.
header_up X-Forwarded-Proto https
EOF
else
  user="${GEV_UI_USERNAME:-}"
  pass="${GEV_UI_PASSWORD:-}"
  [ -n "$user" ] || fail "GEV_UI_USERNAME is empty (or set GEV_PUBLIC_ACCESS=true to drop the login)"
  [ -n "$pass" ] || fail "GEV_UI_PASSWORD is empty (or set GEV_PUBLIC_ACCESS=true to drop the login)"
  case "$user" in
    *[!A-Za-z0-9._@-]*) fail "GEV_UI_USERNAME may only contain letters, digits and . _ @ -" ;;
  esac
  [ "${#pass}" -ge 12 ] || fail "GEV_UI_PASSWORD must be at least 12 characters"
  # Read from stdin so the password never appears in a process list.
  hash=$(printf '%s\n' "$pass" | caddy hash-password) || fail "could not hash GEV_UI_PASSWORD"
  case "$hash" in
    '$2'*) ;;
    *) fail "unexpected output from caddy hash-password" ;;
  esac
  realm="God's Eye View"
  printf 'basic_auth bcrypt "%s" {\n\t%s %s\n}\n' "$realm" "$user" "$hash" > "$CONF_DIR/auth.caddy"
  cat > "$CONF_DIR/upstream.caddy" <<'EOF'
# Login mode. Every request reaching the app has passed the login, so it is
# delivered the way upstream expects a direct same-origin browser request:
# - without the nine forwarding headers upstream's same-site gate refuses
#   (src/localRequestGate.mjs PROXY_SIGNALS), including the Via header Caddy
#   itself adds;
# - with the browser's Origin scheme matched to the plain-HTTP hop, because
#   the gate compares Origin with "http://" + Host when the socket is not TLS.
#   The host part is untouched, so a foreign Origin still fails, and
#   Sec-Fetch-Site is passed through for the gate's cross-site check.
header_up -Forwarded
header_up -Via
header_up -X-Forwarded-For
header_up -X-Forwarded-Host
header_up -X-Forwarded-Port
header_up -X-Forwarded-Proto
header_up -X-Real-Ip
header_up -Cf-Connecting-Ip
header_up -Cf-Ray
header_up Origin ^https:// http://
EOF
  log "login enabled for user $user; app routes that spend provider keys are available to signed-in users"
fi

if ! caddy validate --config "$CADDYFILE" --adapter caddyfile >/dev/null 2>&1; then
  caddy validate --config "$CADDYFILE" --adapter caddyfile || true
  fail "the Caddyfile did not validate"
fi

log "proxying to $upstream"
exec caddy run --config "$CADDYFILE" --adapter caddyfile
