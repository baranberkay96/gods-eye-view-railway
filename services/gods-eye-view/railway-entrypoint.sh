#!/bin/sh
# SPDX-License-Identifier: MIT
#
# God's Eye View for Railway (community template): container entrypoint.
#
# Railway mounts volumes owned by root, while the app runs as `node` (as in
# upstream's image). As root: hand the cache volume to `node`, then drop
# privileges with setpriv (util-linux, part of Debian's base system; it keeps
# the working directory) and start gev-app.sh.
set -eu

APP_USER=node
APP_HOME=/home/node
# Upstream writes its disk cache to `.gev-cache` under the working directory.
CACHE_DIR=/app/.gev-cache
APP_SCRIPT=/opt/railway/gev-app.sh

log() { printf '[entrypoint] %s\n' "$*"; }

if [ "$(id -u)" != 0 ]; then
  log "not running as root: skipping the volume ownership fix"
  exec /bin/sh "$APP_SCRIPT" serve
fi

mkdir -p "$CACHE_DIR"
# A fresh ext4 volume carries lost+found; the app never needs it.
rm -rf "$CACHE_DIR/lost+found"
chown "$APP_USER:$APP_USER" "$CACHE_DIR"
# Only touch entries that are not already the app user's, so a large cache
# does not cost a full recursive chown on every start.
find "$CACHE_DIR" -mindepth 1 \( ! -user "$APP_USER" -o ! -group "$APP_USER" \) \
  -exec chown -h "$APP_USER:$APP_USER" {} +

cd /app
exec setpriv --reuid="$APP_USER" --regid="$APP_USER" --init-groups \
  env HOME="$APP_HOME" USER="$APP_USER" /bin/sh "$APP_SCRIPT" serve
