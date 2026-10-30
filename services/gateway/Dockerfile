# God's Eye View gateway for Railway (community template): Caddy with a
# basic-auth login in front of the app. Routing is in the Caddyfile; the login
# block and the request-header rules are written at start by entrypoint.sh.
FROM caddy:2.11.7-alpine

COPY Caddyfile /etc/caddy/Caddyfile
COPY entrypoint.sh /opt/railway/entrypoint.sh

# Check the script and the Caddyfile at build time, in both modes, with
# stand-in import files (the real ones are written at start).
RUN set -eu; \
    sh -n /opt/railway/entrypoint.sh; \
    mkdir -p /tmp/gev-gateway; \
    printf 'basic_auth bcrypt "check" {\n\tadmin $2a$14$buildtimecheckonlybuildtimecheckonlybuildtimecheckonl\n}\n' > /tmp/gev-gateway/auth.caddy; \
    printf 'header_up -Via\nheader_up -X-Forwarded-For\nheader_up Origin ^https:// http://\n' > /tmp/gev-gateway/upstream.caddy; \
    GEV_APP_UPSTREAM=app.railway.internal:4173 PORT=8080 caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile; \
    printf 'vars gev_login off\n' > /tmp/gev-gateway/auth.caddy; \
    printf 'header_up X-Forwarded-Proto https\n' > /tmp/gev-gateway/upstream.caddy; \
    GEV_APP_UPSTREAM=app.railway.internal:4173 PORT=8080 caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile; \
    rm -rf /tmp/gev-gateway

ENV PORT=8080
EXPOSE 8080

CMD ["/bin/sh", "/opt/railway/entrypoint.sh"]
