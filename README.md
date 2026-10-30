# Deploy and Host God's Eye View with Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/gods-eye-view-v03-live-satellite-and-wor?referralCode=20H68q)

God's Eye View is an open-source 3D globe for live public data: aircraft, satellites, earthquakes, cyclones, rocket launches, weather and public traffic cameras, with optional ships, wildfires and voice control. This community template builds release v0.3.0 from source, puts it behind a generated login and keeps its feed cache on a volume. No API key is required.

## About Hosting God's Eye View

God's Eye View is a CesiumJS app with a Node server. The server is more than a file host: about thirty middleware routes fetch, cache and throttle the data feeds, and they hold any provider keys you add. This template builds the tagged release once and serves the production bundle with Vite's preview server, which runs the same data routes as upstream's Docker image. A small Caddy gateway is the only public endpoint and asks for a password, so nobody can spend your keys. The disk cache (satellite elements, launches, map queries, the TomTom daily budget) lives on a volume, which keeps restarts gentle on the public data providers.

## Common Use Cases

- Exploring live air, sea and space traffic on a 3D globe for OSINT and geospatial teaching, demos and video work
- A shared, password-protected situational view for a small team: flights, quakes, storms, launches and public cameras in one place
- Riding along with a live aircraft in cockpit view, or tracking the ISS and other satellites in real time
- A starting point for your own layers: fork the app, point a module at your own data, and deploy it the same way

## Dependencies for God's Eye View Hosting

- A browser with WebGL; nothing to install for viewers.
- A volume for the disk cache (included).
- No API keys. Optional keys add capabilities: a free Cesium ion token (photorealistic 3D cities and world terrain, eligible personal non-commercial use), AISStream (ships, free), NASA FIRMS (active fires, free), TomTom (live traffic speeds, free tier), Mapillary (street-level photos, free), OpenSky (more flight polling, free account), Google Maps (direct 3D and place search, metered), OpenAI or Gemini (voice control, metered).

### Deployment Dependencies

- [God's Eye View on GitHub](https://github.com/bilawalsidhu/gods-eye-view) (MIT for the code; data keeps its own terms)
- [Release v0.3.0](https://github.com/bilawalsidhu/gods-eye-view/releases/tag/v0.3.0)
- [Upstream data sources and their terms](https://github.com/bilawalsidhu/gods-eye-view/blob/v0.3.0/DATA_SOURCES.md) and [security model](https://github.com/bilawalsidhu/gods-eye-view/blob/v0.3.0/SECURITY.md)
- [Cesium ion](https://cesium.com/ion), [AISStream](https://aisstream.io), [NASA FIRMS map key](https://firms.modaps.eosdis.nasa.gov/api/map_key/), [TomTom keys](https://my.tomtom.com/keys), [Mapillary developers](https://www.mapillary.com/dashboard/developers), [OpenSky Network](https://opensky-network.org), [Google Maps Platform](https://console.cloud.google.com/), [OpenAI platform](https://platform.openai.com)

### Implementation Details

| Service | What it does | Public |
|---|---|---|
| gateway | Caddy with a password login; the only public domain | yes |
| gods-eye-view | The app: built bundle plus the data and API routes (`vite preview`), runs as a non-root user | no |
| Volume | `/app/.gev-cache` on gods-eye-view: cached feeds and the TomTom daily budget | — |

**First login**

1. Wait for both builds. The gods-eye-view build fetches the pinned release and compiles the bundle; it takes a few minutes.
2. Open the gateway's variables and copy `GEV_UI_PASSWORD`. The user name is `admin` (`GEV_UI_USERNAME`).
3. Open `https://{your-domain}`, sign in, and pick a first-run mission such as Live Contacts. Flights, satellites, earthquakes, cameras and launches work without keys.

**Adding keys:** set them on the **gods-eye-view** service and deploy. The in-app POWER UP panel cannot save keys on a hosted server (upstream allows it only on the local machine); Railway variables replace it. `CESIUM_ION_TOKEN`, `GOOGLE_MAPS_API_KEY` and `MAPILLARY_CLIENT_TOKEN` are built into the page, so a deploy rebuilds the bundle; they are visible to everyone who can open the page. Restrict the Google key by HTTP referrer to `https://{your-domain}/*` and give Cesium ion a public `assets:read` token with a URL restriction. All other keys stay on the server. Set budgets and usage limits at OpenAI and Google: the app's throttles are not billing caps, and behind the gateway they apply to all users together.

**Custom domain:** add it to the gateway service, then add it to `GEV_ALLOWED_HOSTS` on gods-eye-view (comma-separated). The app answers only host names on that list.

**Public access:** `GEV_PUBLIC_ACCESS=true` on the gateway removes the login. The app then refuses its paid routes (voice, AI summary, Google place search, Mapillary, TomTom), as it does behind any reverse proxy, but visitors can read the Google Maps and Cesium ion keys from the page. Leave those keys unset, or restricted, for a public globe.

**Data terms:** every feed keeps its own terms. Among them: OpenSky's licence is non-commercial and anonymous access allows 400 credits a day (each global snapshot costs 4; the app stretches its cache and falls back to adsb.lol); Launch Library 2 allows 15 anonymous calls an hour (cached); the cockpit's Google News headlines are for personal, non-commercial use; the bundled submarine-cable map (CC BY-NC-SA) and Nepal flood scene (CC BY-NC) are non-commercial; DelDOT live video needs DelDOT's agreement beyond personal viewing (`CCTV_DELDOT_ENABLED=0` turns it off). Commercial operators should read upstream's DATA_SOURCES.md and get advice before relying on any feed.

**Scaling:** keep gods-eye-view at one replica (it owns the volume, one AIS stream and the OpenSky credit budget) and give it more memory if ships are on. Raise `GEV_RATELIMIT_OPENAI_PER_MIN` or `GEV_RATELIMIT_GOOGLE_PER_MIN` for larger teams. OpenSky OAuth credentials lift the flight budget to 4,000 credits a day.

**Versions:** the source is pinned to v0.3.0 by commit (`GEV_VERSION`, `GEV_COMMIT` build args) on Node 24.22.2 and Caddy 2.11.7. To upgrade, set both variables on gods-eye-view and deploy; the build stops if the commit and version do not match.

God's Eye View shows public and third-party data that can be delayed, incomplete or wrong. Do not use it for navigation, emergency response or other safety-critical decisions.

### Why Deploy God's Eye View on Railway?

Railway builds and runs the app, its login gateway and its cache volume from one template, with HTTPS, logs and private networking included. You add keys as variables, pay for the memory and CPU the globe actually uses, and skip running a server of your own.

This is a community template. It is not made, endorsed or supported by the God's Eye View authors or Halfpixel.
