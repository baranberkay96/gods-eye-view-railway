# God's Eye View v0.3 Live Satellite and World Tracker — Railway template spec

## Listing

| Field | Value |
|---|---|
| Name | **God's Eye View v0.3 Live Satellite and World Tracker** (given name plus `v0.3`, the major.minor of the pinned 0.x release, per the naming rule for this project) |
| Description | Track real satellites, flights and world events on a live 3D globe. (67 chars) |
| Category | Analytics |
| Tags | gods-eye-view, 3d-globe, cesium, satellites, flight-tracking, adsb, osint, geospatial, earthquakes |
| Icon | `https://cdn.jsdelivr.net/gh/bilawalsidhu/gods-eye-view@v0.3.0/public/icons/icon-512.png` (upstream's square app icon; HTTP 200, image/png, checked 2026-10-30) |
| User input at deploy | **None.** The login password is generated; every API key is optional. |
| Repo for built services | `baranberkay96/gods-eye-view-railway` (`/services/gateway`, `/services/gods-eye-view`) |

**Listing wording check (what is live with no keys at all, read from v0.3.0 source and upstream's layer table):**

- **Satellites:** yes. CelesTrak TLEs (an 838-object catalog plus an optional Starlink shell), propagated in the browser with SGP4. Disk-cached on the volume.
- **Flights:** yes. OpenSky anonymous snapshot (OpenSky's anonymous allowance is 400 credits a day and a global snapshot costs 4; upstream's credit governor stretches its cache as the budget runs down), with an adsb.lol regional fallback around the camera, plus adsb.lol military traffic.
- **World events:** yes, keyless: USGS earthquakes (24 h), NHC/CPHC cyclone advisories and cones, WFIGS/NIFC fire perimeters (US), Launch Library 2 rocket launches (30 days), NOAA rain radar, lightning and satellite clouds, GNSS integrity anomalies.
- **3D globe:** yes. CesiumJS globe on Esri World Imagery with keyless terrain. Photorealistic 3D cities need a Cesium ion token (free for eligible personal, non-commercial use) or a metered Google Maps key; the README says so.
- **Not in the description but also keyless:** about 4,000 public traffic cameras (stills and some live video), transit vehicles in 16 regions, radio stations, bikeshare, directions.
- **Needs a free key:** ships (AISStream), active-fire detections (NASA FIRMS), live traffic speeds (TomTom), Mapillary street-level photos. **Metered:** voice control (OpenAI or Gemini), direct Google 3D and place search.

The description is deliverable as written and was kept.

## Base market templates

None. A full scan of the public marketplace API on 2026-10-30 (all templates, name and code matched against "god…eye", "satellite" and "worldview") found no God's Eye View template, and `_market/` is empty. The design follows upstream's own `Dockerfile` and `compose.yaml` at v0.3.0 and the gateway pattern of our `66-worldmonitor` template. Nothing was copied from other templates.

## Pinned versions

| Component | Source | Version | Date | Checked |
|---|---|---|---|---|
| God's Eye View | `bilawalsidhu/gods-eye-view`, tag `v0.3.0` (annotated tag object `b5cf313b`) → commit `72eb3fdc739991a1286b7f1251de908e9744bb2a`, fetched by commit id with `git fetch --depth 1` and checked (`git rev-parse HEAD`, `package.json` version) | 0.3.0 | 2026-10-28 (latest release) | 2026-10-30 (`gh api`: releases/latest, tag → commit; `main` is 237 commits ahead, so the release is pinned, not `main`) |
| npm dependencies | `package-lock.json` at the tag, `npm ci` | vite 6.4.3, cesium 1.138.0, vite-plugin-cesium 1.2.23 | — | 2026-10-30 |
| Node base | `node:24.22.2-bookworm-slim@sha256:c86ecead9e55a5210ac1727de38a4ca840bf03dcaf34dc9749addbf383b1920c` | Node 24.22.2 LTS | 2026-10-27 release, image 2026-10-28 | 2026-10-30 (Docker Hub API, amd64 present; nodejs.org index: 24.22.1 was a security release) |
| Gateway | `caddy:2.11.7-alpine` | 2.11.7 | release 2026-10-03, image rebuilt 2026-10-30 | 2026-10-30 |

Upstream's Dockerfile pins `node:24.14.0-slim` (Feb 2026) by digest and CI tests 24.14.0 and 26.x; `engines` allows `>=24.14.0 <25`. The template uses the current 24.x patch for its security fixes; same major, same Debian base. Upstream publishes no container image.

**Upgrade path.** Set `GEV_VERSION` and `GEV_COMMIT` (service variables become build args) or edit the defaults in `services/gods-eye-view/Dockerfile`. The build fails if the fetched commit or its `package.json` version does not match. Before moving, re-read upstream's `Dockerfile`, `compose.yaml`, `.env.example`, `SECURITY.md`, `build/vite.js`, `build/allowedHosts.js`, `server/standalone/vite.config.js`, `src/localRequestGate.mjs` and `server/providers/common/same-site.js` for the new tag; the gateway's header rules depend on the last two, the start script on the Host allowlist and the `define` block.

## Architecture

```
Internet --HTTPS--> Railway edge --> gateway (Caddy :8080, the only public domain)
                                      |- /gateway-health                 -> 200
                                      |- /manifest.webmanifest, /icons/* -> app (no login)
                                      '- everything else -> basic auth -> app
                                         (login mode: proxy headers removed, Origin scheme matched)
gods-eye-view (Node 24, `vite preview` on [::]:4173, runs as `node`)
   |- built browser bundle (dist/, Cesium assets)
   |- ~30 provider middlewares under /api: OpenSky, adsb.lol, CelesTrak, USGS, LL2, AISStream,
   |  FIRMS, TomTom, cameras (incl. bounded HLS relay), Overpass, terrain, weather, transit,
   |  radio, OpenAI/Gemini token minting, Google Places, Mapillary, GhostMaps (SSE)
   '- disk cache /app/.gev-cache (volume): TLEs, launches, FIRMS, terrain heights, Overpass,
      adsbdb, TomTom tiles and daily budget, GhostMaps files
```

### Deviations from upstream's Docker setup (v0.3.0) and why

1. **Built bundle served by `vite preview`, not the dev server.** Upstream's image runs `vite` (dev) on a bind-mounted checkout for hot reload. Every provider plugin registers `configurePreviewServer`, and upstream documents that preview "serves the built app with the same data provider routes as development" (`docs/CURRENT-STATE.md`, `CONTRIBUTING.md`). Preview serves a minified bundle without on-the-fly module transforms, a file watcher or an HMR socket, which is lighter per page load and keeps Vite's dev-only endpoints off the network. Upstream calls both modes "not a production server"; that is why a login is in front.
2. **Provider Settings (POWER UP) is not available.** It is development-only upstream (`apply: … !isPreview`) and refuses proxied or non-loopback requests anyway. Keys are Railway variables on the `gods-eye-view` service.
3. **Browser keys are build-time.** `GOOGLE_MAPS_API_KEY`, `CESIUM_ION_TOKEN` and `MAPILLARY_CLIENT_TOKEN` are written into the bundle by Vite's `define` (upstream: "rebuild after changing a browser key"). The Dockerfile declares them as build args, which Railway fills from service variables. `gev-app.sh` stores a SHA-256 of the three and, if the running container's values differ from the build (a fallback; a normal deploy rebuilds), rebuilds at start, keeping the previous bundle if that fails (`GEV_REBUILD_ON_KEY_CHANGE`).
4. **A login gateway in front.** Upstream's server is a key broker and its docs say to put any non-local instance "behind your own auth/proxy". See "Security model".
5. **Proxy headers.** Upstream refuses its cost-bearing routes when a request carries any of nine forwarding headers, and compares `Origin` with `http://` + Host when the socket is plain HTTP. The gateway handles this per mode (see "Security model"); without it, voice, AI summary, Google place search, Mapillary and TomTom would answer 403 behind Railway's edge.
6. **Host allowlist.** Upstream accepts only IP addresses, `localhost` and `GEV_ALLOWED_HOSTS`. The template sets it to the gateway's public domain; the start script appends `healthcheck.railway.app` (Railway's healthcheck Host). Custom domains must be added.
7. **Cache on a volume.** Compose bind-mounts the whole checkout so `.env`, `.gev-cache` and `.gev-logs` survive. Here configuration is in variables, `.gev-cache` is a volume, and `.gev-logs` (voice debug log, transcripts off by default) stays ephemeral.
8. **Non-root with a volume.** Compose runs as the host user. Railway mounts volumes as root, so the entrypoint starts as root, fixes ownership of the cache (only entries that need it), removes `lost+found`, and drops to `node` with `setpriv` (Rule 8.3/8.4: no reliance on PID 1, working directory kept).
9. **No `scripts/docker-start.mjs`.** Its only job is to trust the Docker bridge gateway for Provider Settings, which must not happen on a shared network. `GEV_KEY_SETUP_TRUSTED_PEERS` is unset at start.
10. **Dual-stack listener** (`HOST=::` when the container has IPv6, else `0.0.0.0`); Node's `::` socket accepts IPv4 too (Rule 8.14).
11. **`GEV_RATELIMIT_GOOGLE_PER_MIN=60`**, upstream's own advice "whenever HOST is not localhost" (default 120).
12. **Smaller image.** `docs/` (71 MB of media) and `.github/` are dropped after checkout; nothing in the build or server reads them (checked: only tests reference `docs/`).

## Security model

- **One public domain: `gateway`.** `gods-eye-view` has no public domain and no TCP proxy.
- **Login (default):** HTTP basic auth on everything except `/gateway-health`, `/manifest.webmanifest` and `/icons/*` (public static files browsers fetch without credentials). The password is generated (`secret(24)`, 56-character alphabet), bcrypt-hashed inside the container at start, and the `Authorization` header is stripped before proxying.
- **Login mode, request headers to the app.** Every request that reaches the app has passed the login, so the gateway delivers it the way upstream expects a direct same-origin browser request: it removes `Forwarded`, `Via`, `X-Forwarded-For/-Host/-Port/-Proto`, `X-Real-Ip`, `Cf-Connecting-Ip` and `Cf-Ray` (upstream's `PROXY_SIGNALS`; Caddy adds `Via` and `X-Forwarded-*` itself, and its user header ops run after that, checked in Caddy 2.11.7 `reverseproxy.go`), and rewrites a leading `https://` in `Origin` to `http://`. Upstream's other checks stay in force: Host allowlist first, `Sec-Fetch-Site` must be `same-origin`/`none`, and `Origin`'s host must equal the request Host exactly, so cross-site pages are still refused even though the browser holds basic-auth credentials.
- **What the login protects:** the server-side keys (OpenAI, Gemini, Google server key, AISStream, FIRMS, TomTom, OpenSky, LL2, Ontario 511) are spent by the app's routes for whoever reaches them, and the Google Maps and Cesium ion keys are in the page. Only signed-in users see or use them.
- **Public mode (`GEV_PUBLIC_ACCESS=true`):** no login. The gateway keeps the proxy headers, so the app refuses its cost-bearing routes (`/api/realtime/token`, `/api/openai/hud-summary`, Gemini, `/api/google/*` Places, `/api/mapillary/*`, `/api/tomtom/*`), exactly as upstream does behind any reverse proxy, and the camera Street View fallback is skipped. It sets `X-Forwarded-Proto: https` so keyless routes that check `Origin` (terrain heights, cameras) keep working. Visitors can still read the Google Maps and Cesium ion keys from the page and drive the cached keyed feeds (AISStream, FIRMS, OpenSky). Leave those browser keys unset in public mode, or restrict them tightly at the provider.
- **Throttles:** upstream's per-IP throttles key on the socket address, which is the gateway's for every user. They therefore act as deployment-wide caps (OpenAI 30/min, Google 60/min, Gemini 30/min; OSRM, Nominatim and terrain per-client limits are shared too). They are not billing caps.
- **Unreachable by design:** `/mcp` (answers loopback only), Provider Settings (`/api/setup/*`, absent in preview), arbitrary upstream URLs (all proxies use fixed or registered hosts; see upstream `SECURITY.md`).
- **Provider-side budgets are the real backstop:** OpenAI usage limits, Google Cloud budgets and per-API quotas, HTTP-referrer restriction on the browser Google key (`https://{your-domain}/*`), URL restriction on the Cesium ion token.

## Services

2 services, 1 volume. Railway limit is 25.

### gateway

| Setting | Value |
|---|---|
| Source | repo `/services/gateway` (`FROM caddy:2.11.7-alpine`, Caddyfile + entrypoint; the Caddyfile is validated in both modes during the image build) |
| Public domain | **yes**, target port 8080 |
| Healthcheck | `/gateway-health`, 120 s |
| Restart | ON_FAILURE ×10 |
| Variables | `PORT=8080`, `GEV_APP_UPSTREAM=${{gods-eye-view.RAILWAY_PRIVATE_DOMAIN}}:${{gods-eye-view.PORT}}`, `GEV_UI_USERNAME=admin`, `GEV_UI_PASSWORD=${{secret(24, …)}}`, `GEV_PUBLIC_ACCESS=false` |

### gods-eye-view

| Setting | Value |
|---|---|
| Source | repo `/services/gods-eye-view`: 2-stage build (pinned commit checkout → `npm ci`, `vite build`), runtime `vite preview` |
| Public domain | no (reached through the gateway) |
| Volume | `/app/.gev-cache` |
| Healthcheck | `/` (the built `index.html`, through upstream's Host check), 900 s (covers the rare rebuild-at-start fallback) |
| Restart | ALWAYS |
| Wiring | `PORT=4173`, `GEV_ALLOWED_HOSTS=${{gateway.RAILWAY_PUBLIC_DOMAIN}}` |
| Browser keys (build args) | `CESIUM_ION_TOKEN`, `GOOGLE_MAPS_API_KEY`, `MAPILLARY_CLIENT_TOKEN` |
| Server keys | `GOOGLE_MAPS_SERVER_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`, `AISSTREAM_API_KEY`, `FIRMS_MAP_KEY`, `TOMTOM_API_KEY`, `OPENSKY_CLIENT_ID`, `OPENSKY_CLIENT_SECRET`, `LL2_API_TOKEN`, `ONTARIO_511_API_KEY`, `GITHUB_TOKEN`, `OVERPASS_UPSTREAMS` (all empty by default) |
| Tuning | `GEV_RATELIMIT_OPENAI_PER_MIN=30`, `GEV_RATELIMIT_GOOGLE_PER_MIN=60`, `TOMTOM_DAILY_TILE_BUDGET=6000`, `GEV_REBUILD_ON_KEY_CHANGE=true` |

Other upstream variables work when added to this service, for example `CCTV_DELDOT_ENABLED=0`, `CCTV_TXDOT_DISTRICTS`, `CCTV_MAX_SOURCES`, `AISSTREAM_BOUNDING_BOXES`, `OPENAI_REALTIME_MODEL`, `GEV_EMBED_FRAME_ANCESTORS` (see upstream `.env.example`). Model names have code defaults, so none is set here.

## Data sources and API keys

| Layer | Source | Key | Template default |
|---|---|---|---|
| Basemap | Esri World Imagery + Re:Earth terrain, OSM fallback | none | on |
| Photorealistic 3D, world terrain | Google 3D Tiles via Cesium ion | `CESIUM_ION_TOKEN` (free Community plan, personal non-commercial) | off until set |
| Direct Google 3D, place search, Street View | Google Maps Platform | `GOOGLE_MAPS_API_KEY` (metered; billing required) | off until set |
| Flights, military flights, GNSS integrity | OpenSky (anonymous), adsb.lol | optional `OPENSKY_CLIENT_ID/SECRET` (4,000 credits/day instead of 400) | on |
| Satellites | CelesTrak | none | on |
| Earthquakes, cyclones, fire perimeters, weather | USGS, NOAA NHC/CPHC, WFIGS/NIFC, NOAA nowCOAST, GFS/ECMWF | none | on |
| Rocket launches | Launch Library 2 | optional `LL2_API_TOKEN` (paid) | on (15 calls/hour public, cached 15 min) |
| Public cameras | ~20 city/agency feeds | `ONTARIO_511_API_KEY` for Ontario only | on (NYC, Florida, Lithuania off, as upstream) |
| Ships | AISStream | `AISSTREAM_API_KEY` (free) | off until set |
| Active fires | NASA FIRMS | `FIRMS_MAP_KEY` (free) | off until set |
| Traffic | simulated on OSM roads; TomTom flow | `TOMTOM_API_KEY` (free tier) | simulation on |
| Street Level | KartaView, Panoramax; Mapillary; Google | `MAPILLARY_CLIENT_TOKEN`, Google key | keyless providers on |
| Voice, AI HUD summary | OpenAI Realtime, Gemini Live | `OPENAI_API_KEY`, `GEMINI_API_KEY` | off until set |
| GhostMaps | public GitHub repository (S2 Underground) | optional `GITHUB_TOKEN` | on |

ChatGPT OAuth voice and the local MCP server need a desktop install and are not available in a hosted deployment.

## Data terms the operator must review

Practical guidance from upstream's `DATA_SOURCES.md` and `LICENSE`, not legal advice; check current provider terms and get professional advice for commercial use.

- **OpenSky Network:** non-commercial licence; upstream notes that operational use in a live product can need a written agreement, even non-commercially.
- **Google News RSS** (cockpit regional headlines): personal, non-commercial use only; commercial deployments must disable or replace it.
- **Bundled data under non-commercial licences:** TeleGeography submarine cables (CC BY-NC-SA 3.0) and the Bhote Koshi flood scene (CC BY-NC 4.0). Commercial users must remove them or license them. Datacenters and dams are ODbL; 3D models carry individual licences (`public/models/README.md`).
- **Cesium ion Community plan:** eligible personal, non-commercial use; **Google Maps Platform:** own key and billing, no caching (the app uses tiles live).
- **Launch Library 2:** 15 anonymous calls per hour; **adsb.lol:** ODbL, future access may need a feeder key; **adsbdb:** route data may not be republished.
- **Cameras:** DelDOT live video needs confirmation of DelDOT's terms beyond personal viewing (`CCTV_DELDOT_ENABLED=0` turns it off); NYC, Florida and Lithuania packs stay off as upstream ships them.
- **Fair-use public services** (Nominatim, Photon, OSRM on FOSSGIS, Radio Browser, CelesTrak, Esri World Imagery): fine for interactive use; heavy or large public deployments should run or license their own.
- The app is not for navigation, emergency response or other safety-critical use (upstream disclaimer, repeated in the README).

## Improvements over market templates

No market template exists. Compared with following upstream's documented Docker path on a hosted server:

| Upstream Docker path | This template |
|---|---|
| Dev server, source mounted from the host | Pinned release built once; production bundle served by `vite preview` |
| Loopback-only publish; "use a separately reviewed authentication proxy" for remote access | Caddy gateway with a generated bcrypt login by default |
| Behind a reverse proxy, voice, place search, Mapillary and TomTom answer 403 | Login mode delivers authenticated requests as same-origin; public mode keeps upstream's refusal |
| Keys typed into Provider Settings, saved to `.env` | Keys as Railway variables; browser keys rebuilt automatically |
| Cache in the checkout | Cache on a volume (TLE, launch, Overpass and FIRMS caches and the TomTom daily budget survive deploys, which also respects provider limits) |
| No healthcheck target on a shared host | Host allowlist plus `healthcheck.railway.app`, healthchecks on both services |

## Scaling

- `gods-eye-view` stays at **one replica**: it owns a volume, one AISStream socket, the OpenSky credit governor and in-memory caches. Scale it vertically; with ships enabled the AIS cache can hold up to 50,000 vessels.
- The gateway is stateless and tiny; one replica is enough.
- For more users: raise `GEV_RATELIMIT_*` (deployment-wide caps behind the gateway), add OpenSky OAuth credentials, and set provider budgets.

## Resource estimate

Prices: RAM $10/GB-month, vCPU $20/vCPU-month, volume $0.15/GB-month, egress billed by Railway per GB. **Not measured** (nothing was run); based on the process layout (one Node process with in-memory feed caches, bounded HLS buffers of 2 × 24 MiB) and typical Caddy and Node footprints.

| Service | Idle RAM | Typical RAM | Idle vCPU | Typical vCPU | Volume |
|---|---|---|---|---|---|
| gateway | 25 MB | 45 MB | 0.005 | 0.03 | — |
| gods-eye-view | 300 MB | 700 MB (ships and cameras on) | 0.02 | 0.3 | 0.1–1 GB |
| **Total** | **≈ 0.33 GB** | **≈ 0.75 GB** | **≈ 0.03** | **≈ 0.33** | **≈ 0.5 GB** |

- **Idle** (nobody viewing): 0.33 × $10 + 0.03 × $20 + $0.08 ≈ **$4/month**.
- **Typical** (a few users daily, ships on): 0.75 × $10 + 0.33 × $20 + $0.08 ≈ **$14/month**, plus egress: a first page load is several MB (Cesium), and an open tab polls flight and vessel snapshots (the gateway compresses JSON).
- The rebuild-at-start fallback needs about 2 GB for a few minutes; a normal deploy builds in Railway's builder instead.
- Provider costs (OpenAI, Gemini, Google) are billed by those providers.
- **Minimum plan: Hobby.** Each service fits Trial's 1 GB at idle, but ships plus several users can approach it and Trial credit would not cover a month. Pro only for heavy use.

## Static verification (2026-10-30, no Docker)

- Upstream: latest release `v0.3.0` → commit `72eb3fd`; the full v0.3.0 tree (2,319 files) compared with the local reference copy by git blob SHA. The copy is `main`; every file under `server/`, `build/` and the files used for the design matched the tag except `server/providers/terrain.js` (main adds a 429 pause), `server/providers/openai/hud-summary.js` (main adds a status probe), `firePerimeters.js` and `openai/instructions.js` (behaviour unrelated to deployment). `package.json`/`package-lock.json` were read at the tag (vite 6.4.3).
- Preview path read in source: every provider plugin has `configurePreviewServer`; only `key-setup.js` is dev-only. Vite 6.4.3 `resolvePreviewOptions` (read from vitejs/vite at that tag): preview inherits `host` and `allowedHosts` from `server`, not `port` (passed with `--port`); preview adds compression after plugin middleware (API routes are not compressed, hence the gateway `encode` for JSON).
- Gate logic read in `src/localRequestGate.mjs`, `server/providers/common/same-site.js`, `server/providers/gemini/request.js`, `server/providers/common/rate-limit.js` (socket address as client key).
- Caddy 2.11.7 source: `prepareRequest` adds `X-Forwarded-*` and `Via` before the retry loop applies user `header_up` ops (deletions win); Caddyfile 3-argument `header_up` is a regex replace; `basic_auth` accepts `$`-prefixed hashes without base64.
- vite-plugin-cesium 1.2.23 copies Cesium assets into the configured `outDir`; the template rebuilds into `dist` (with a backup) instead of a second directory.
- `sh -n`, `dash -n`, `bash -n` on all three scripts; gateway entrypoint run with dash and a mock `caddy` (login file, realm quoting, public mode, both header files, missing or bad upstream, short or empty password, invalid user name, invalid mode, failed validation); `gev-app.sh` run with dash and a stub `node` against a scratch app directory (image build, fingerprint match, empty equals unset, rebuild on change, failed rebuild restores the old bundle, `GEV_REBUILD_ON_KEY_CHANGE=false`, allowed-host append, empty-host warning, `HOST` override, bad `PORT`, missing bundle, missing `sha256sum` fails loudly instead of "matching"). `railway-entrypoint.sh` (root, `setpriv`) was only syntax-checked.
- `template.json` parses; `to_serialized.py` converts it (2 services, 1 volume); every `${{service.VAR}}` reference resolves; every variable has a description; both healthchecked services set `PORT`; no `VOLUME` in any Dockerfile; `ship.py review` clean.
- Registry and URLs: `node:24.22.2-bookworm-slim` digest and `caddy:2.11.7-alpine` exist (Docker Hub API); the icon URLs answer 200; `setpriv` is in Debian bookworm's essential `util-linux`.

## Verification checklist (first deploy)

1. Builds: `gods-eye-view` (fetch commit, `npm ci`, `vite build`; the slow one) and `gateway` (its build runs `caddy validate` in both modes) succeed on `linux/amd64`.
2. Logs, gods-eye-view: `[gev] browser bundle matches the configured map keys`, `disk cache: /app/.gev-cache (volume)`, `serving on [::]:4173, hosts: {gateway-domain},healthcheck.railway.app`; no `Start refused`.
3. Health: gateway `/gateway-health` 200; gods-eye-view `/` 200 (proves the Host allowlist includes Railway's healthcheck host).
4. Login: `https://{your-domain}` prompts; `admin` and `GEV_UI_PASSWORD` from the gateway variables open the globe; a wrong password gets 401. `/manifest.webmanifest` loads without a prompt.
5. Keyless layers: turn on Flights, Satellites, Earthquakes, Cameras (Austin or London), Space Missions; each populates. `curl -su admin:{password} https://{your-domain}/api/flights -o /dev/null -w '%{http_code} %{size_download}\n'` → 200 (gzip when `--compressed`).
6. Same-origin gate behind the gateway: with `OPENAI_API_KEY` set, the AI HUD summary appears and voice starts (no 403 in DevTools on `/api/realtime/token` or `/api/openai/hud-summary`). Without a key these answer the app's keyless response, not 403.
7. Terrain: `/api/terrain/heights` requests return 200 in DevTools (keyless Origin check with the rewritten scheme).
8. Browser key path: set `CESIUM_ION_TOKEN`, deploy; the build log shows a fresh `vite build`, the start log says the bundle matches, and Photorealistic 3D appears in the map tray.
9. Persistence: after a redeploy, `.gev-cache` keeps `celestrak-*.json`, `firms.json`, `tomtom/budget.json` (log line shows the volume; CelesTrak is not re-downloaded at once).
10. Public mode: set `GEV_PUBLIC_ACCESS=true` on the gateway; no prompt; keyless layers work; `/api/realtime/token` answers 403 "Proxied requests are not accepted".
11. Custom domain: add it to the gateway and to `GEV_ALLOWED_HOSTS`; without the second step the app answers 403 "host is not allowed".

## Open questions

- **Nothing has run yet** (no Docker by instruction). Unverified until the Railway deploy test: both image builds (time and memory of `vite build` on Railway's builder; `NODE_OPTIONS=--max-old-space-size=4096` is set for it), `git fetch` of a commit by id from GitHub, the setpriv hand-off, and all runtime paths.
- **Railway passing build args on variable changes:** expected on every deploy of a repo service; if a deploy ever reuses an image, the start-time fingerprint rebuild covers it (needs about 2 GB).
- **Edge headers:** the header list covers upstream's nine signals; if Railway's edge added a different signal in future, cost routes would 403 again (visible in DevTools).
- **Basic auth on every asset:** browsers resend cached credentials on same-origin fetches, worker scripts and the Cesium assets; Safari and Firefox behaviour with Cesium's blob workers was not tested.
- **OpenSky from Railway IPs:** anonymous access is per IP; shared cloud egress may exhaust the 400-credit allowance or be throttled. The app then serves stale data and falls back to adsb.lol around the camera. OAuth credentials raise the allowance.
- **Third-party APIs from cloud IPs:** some camera agencies, CelesTrak and Nominatim may throttle datacenter ranges; each pack fails on its own.
- **GitHub API for GhostMaps** from shared IPs without `GITHUB_TOKEN` may hit the anonymous limit; only that layer is affected.
- **Memory figures** are estimates; watch the service metrics with ships on.
