# Notice

## Upstream software

| Component | Source | License |
|---|---|---|
| God's Eye View (browser app, data and API server middleware) | [bilawalsidhu/gods-eye-view](https://github.com/bilawalsidhu/gods-eye-view), tag `v0.3.0`, commit `72eb3fdc739991a1286b7f1251de908e9744bb2a` | MIT License, Copyright (c) 2026 Bilawal Sidhu. Covers the source code only (see "Data and assets") |
| npm dependencies (CesiumJS, Vite, vite-plugin-cesium, MapillaryJS, hls.js, satellite.js and others) | `package-lock.json` at the same commit, installed with `npm ci` | Each package's own license (CesiumJS: Apache-2.0; Vite: MIT; `@jtarrio/webrtlsdr` and `@jtarrio/signals`: Apache-2.0; see upstream `THIRD_PARTY_NOTICES.md`) |
| Node.js base image | `node:24.22.2-bookworm-slim` (Docker official image, pinned by digest) | MIT (Node.js) and the licenses of the Debian packages |
| Caddy | `caddy:2.11.7-alpine` (Docker official image) | Apache-2.0 |

The image is built at deploy time from the pinned commit. This repository contains no God's Eye View source code. Upstream's MIT license text and copyright notice ship inside the built image with the source (`/app/LICENSE`).

## Data and assets

Upstream's `LICENSE` states that the MIT grant does **not** cover third-party data or assets. They keep their own terms, including:

- TeleGeography submarine cable map (`src/data/local_data/telegeography_submarine_cables/`): CC BY-NC-SA 3.0, non-commercial.
- Bhote Koshi flood scene imagery and river path: Vantor / GeoPera, CC BY-NC 4.0, non-commercial.
- Datacenters and dams (OpenStreetMap / Open Infrastructure Map extracts): ODbL 1.0.
- 3D models under `public/models/`: individual licenses (`public/models/README.md`).
- Live feeds (OpenSky, adsb.lol, AISStream, CelesTrak, USGS, NOAA, Esri, Google, Cesium ion, Launch Library 2, city camera agencies and others): each provider's terms, summarised in upstream `DATA_SOURCES.md`.

The template does not remove or change any of them. Operators decide which feeds and datasets fit their use; commercial users in particular must review the non-commercial items. This is practical guidance, not legal advice.

## Verified against

Checked on 2026-10-30 against the current stable release, **v0.3.0** (published 2026-10-28; `main` was 237 commits ahead and is not used):

- `Dockerfile`, `compose.yaml`, `.dockerignore`, `.env.example`, `package.json`, `package-lock.json`, `vite.config.js`
- `server/standalone/vite.config.js`, `build/vite.js`, `build/allowedHosts.js`, `build/panel.js`, `scripts/docker-start.mjs`
- `server/providers/local.js` and the provider plugins (preview hooks), `server/standalone/key-setup.js` (dev-only), `server/mcp/plugin.js` (loopback-only)
- `src/localRequestGate.mjs`, `server/providers/common/same-site.js`, `server/providers/common/rate-limit.js`, `server/providers/gemini/request.js`
- Cache paths in `server/providers/*` (`.gev-cache` under the working directory), `server/providers/vessels/ais-live.js`, `server/providers/aircraft/opensky.js`
- `README.md`, `SECURITY.md`, `DATA_SOURCES.md`, `LICENSE`, `THIRD_PARTY_NOTICES.md`, `CONTRIBUTING.md`, `docs/CURRENT-STATE.md`, `docs/opensky-auth.md`

Tag and commit came from the GitHub API; the local reference copy was compared with the tag's tree by git blob SHA. Also read: Vite 6.4.3 `preview.ts`, Caddy 2.11.7 `reverseproxy.go`, `headers/caddyfile.go` and `caddyauth/basicauth.go`, vite-plugin-cesium 1.2.23 `src/index.ts`.

## Written for this template

Everything in this repository was written for this template, using upstream's source and documentation as reference, and is offered under the MIT License, the same terms as God's Eye View:

- `services/gods-eye-view/Dockerfile`: follows upstream's `Dockerfile` (Node 24 slim, `PUPPETEER_SKIP_DOWNLOAD`, `npm ci`, non-root `node` user, port 4173) but fetches a pinned commit and serves the built app with `vite preview`.
- `services/gods-eye-view/railway-entrypoint.sh`, `services/gods-eye-view/gev-app.sh`: volume ownership, privilege drop, build-key fingerprint, start.
- `services/gateway/*`: Caddy login gateway. The list of headers it removes mirrors the header names in upstream's `PROXY_SIGNALS` (facts about the protocol, not copied code).
- `TEMPLATE.md`, `template.json`, `README.md`, this file.

## Reference only (not copied)

- `templates/66-worldmonitor` (our own earlier template): gateway pattern.
- No Railway marketplace template for God's Eye View existed on 2026-10-30.

## Trademarks

"God's Eye View" and its logo belong to their owners. The template icon is upstream's app icon, loaded from the upstream repository at the pinned tag. Google, Cesium, OpenSky, OpenAI and other names belong to their respective owners. This is a community template, not affiliated with, made, endorsed or supported by the God's Eye View authors, Halfpixel, Railway, or any data provider.
