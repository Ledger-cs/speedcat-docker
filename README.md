# Speedcat Docker

This repository packages the updated Speedcat Linux client `scclient_1.33.12` into a portable Docker deployment that can be moved between headless Linux servers.

The project supports two runtime modes:

- `gui`: runs the official Speedcat desktop client inside `Xvfb` and exposes `noVNC` for remote login and subscription sync
- `core`: runs the embedded `Mihomo Meta v1.19.23` core directly after a usable `config.yaml` is available

## Project goals

- Keep the deployment portable across Linux virtual servers
- Preserve runtime data outside the container
- Make the project suitable for GitHub-based version management
- Leave room to migrate from GUI bootstrap mode to pure headless mode later

## Repository structure

- `Dockerfile`: image build definition
- `entrypoint.sh`: startup logic for `gui` and `core` modes
- `docker-compose.yml`: default deployment with explicit UI and proxy port exposure
- `docker-compose.admin-ports.yml`: optional DNS and control port exposure
- `docker-compose.tun.yml`: compatibility overlay for older deployments
- `.env.example`: example runtime configuration for UI and proxy exposure
- `install-docker-ubuntu.sh`: Docker installation helper with fallback logic
- `docs/GITHUB_WORKFLOW.md`: recommended GitHub maintenance workflow
- `docs/MAINTENANCE_NOTES.md`: technical findings and troubleshooting history
- `docs/OPEN_ISSUES.md`: unresolved follow-up work for future maintenance
- `docs/SECURITY.md`: security posture and recommended deployment model

## Included artifacts

This repository now tracks the package files used during the initial build so the environment can be reproduced later and package updates can be managed in branches.

Tracked artifacts:

- `linux.zip`: the original downloaded Speedcat Linux package bundle
- `scclient_1.33.12_linux_universal_amd64.tar.gz`: the Linux universal package used by the Docker image build
- `speedcat-docker-bundle.tar.gz`: a portable repository bundle created during the initial setup

Runtime logs, caches, screenshots, and database files are still excluded from Git because they are environment-specific and may contain session data.

`linux.zip` is tracked with Git LFS because it exceeds GitHub's regular 100 MB Git object limit.

## Standard build flow

1. Copy or clone this repository to the target Linux server.
2. If Docker is missing, install it:

```bash
chmod +x install-docker-ubuntu.sh
./install-docker-ubuntu.sh
```

3. Reconnect to the server so Docker group membership takes effect.
4. Build and start the container:

```bash
docker compose up -d --build
```

Because the package archives are tracked in the repository, a fresh clone already contains the files needed for the initial image build.

If you want to customize ports or enable UI authentication, copy the example environment file first:

```bash
cp .env.example .env
```

The default image and compose setup now also include the runtime pieces that the Speedcat Linux client expects during connection:

- `libglib2.0-bin` for `gsettings`
- `dconf-cli` for desktop proxy configuration helpers
- `iptables`
- `nftables`
- `NET_ADMIN`
- `/dev/net/tun`

## Default usage model

The default deployment is designed around this usage pattern:

1. Expose one management UI based on `noVNC`
2. Optionally protect that UI with a password
3. Expose one proxy port for client traffic

By default:

- management UI: `http://SERVER_IP:6080/vnc.html`
- proxy port: `SERVER_IP:6454`
- UI authentication: disabled unless `UI_AUTH_USERNAME` and `UI_AUTH_PASSWORD` are set
- default bind addresses: `127.0.0.1` for both UI and proxy, to encourage SSH tunneling instead of public exposure

This default exposure model was validated on the remote server:

- `http://127.0.0.1:6080/vnc.html` returned `200 OK`
- SOCKS5 traffic succeeded through `127.0.0.1:6454`
- the container published only `127.0.0.1:6080` and `127.0.0.1:6454` in the default deployment

## GUI bootstrap mode

This is the safest mode when the provider only supports login and subscription sync in the official client.

After startup:

1. Open `http://SERVER_IP:6080/vnc.html`
3. Log in to your Speedcat account
4. Select the node you want to use
5. Try enabling the proxy service

Persistent client data is stored under `./data`, so login state survives container recreation.

If `UI_PASSWORD` is set, the noVNC session will require that password before you can use the desktop.

The optional authentication behavior was also checked during testing:

- without `UI_PASSWORD`, `x11vnc` started with `-nopw`
- with `UI_PASSWORD` set, the no-password mode was removed and the VNC backend switched to password-protected mode

To add an HTTP authentication layer in front of noVNC, set both:

```text
UI_AUTH_USERNAME=admin
UI_AUTH_PASSWORD=change-me
```

When those two variables are set, the management page requires HTTP Basic Auth before the noVNC session can even load.

That behavior was also verified on the remote server:

- without credentials, `http://127.0.0.1:6080/vnc.html` returned `401 Unauthorized`
- with the configured credentials, the same endpoint returned `200 OK`

## UI and proxy configuration

The main runtime knobs are:

- `NOVNC_HOST_PORT`: host port for the management UI, default `6080`
- `NOVNC_BIND_ADDR`: bind address for the management UI, default `127.0.0.1`
- `UI_AUTH_USERNAME`: optional HTTP Basic Auth username
- `UI_AUTH_PASSWORD`: optional HTTP Basic Auth password
- `UI_PASSWORD`: optional password for the noVNC session
- `PROXY_SOCKS_HOST_PORT`: exposed SOCKS5 proxy port, default `6454`
- `PROXY_BIND_ADDR`: bind address for the SOCKS5 proxy, default `127.0.0.1`

Example:

```bash
cp .env.example .env
```

```text
NOVNC_BIND_ADDR=127.0.0.1
NOVNC_HOST_PORT=16080
UI_AUTH_USERNAME=admin
UI_AUTH_PASSWORD=change-me
UI_PASSWORD=change-me
PROXY_BIND_ADDR=127.0.0.1
PROXY_SOCKS_HOST_PORT=16454
```

Then rebuild:

```bash
docker compose up -d --build
```

## Optional DNS and control port exposure

The default deployment does not publish the internal DNS and control ports. If you really need them, use the optional overlay:

```bash
docker compose -f docker-compose.yml -f docker-compose.admin-ports.yml up -d
```

That overlay can expose:

- `19227` for the internal control interface
- `1053/tcp` and `1053/udp` for the DNS listener

These ports also default to `127.0.0.1` in `.env.example` for safety.

The optional overlay was validated on the remote server and correctly published:

- `127.0.0.1:19227 -> 19227/tcp`
- `127.0.0.1:1053 -> 1053/tcp`
- `127.0.0.1:1053 -> 1053/udp`

## Why "connected" could fail before

The Linux client does not treat "mihomo started" as the only success condition. Its GUI state also depends on a system proxy integration step.

Earlier deployments could show `未连接` even when the proxy core was already working because:

- the embedded `mihomo` process had started
- SOCKS5 and DNS ports were listening
- proxy traffic could already pass through
- but the container did not provide `gsettings` and `dconf`, so the client failed during its system proxy setup step

The image now includes the required GNOME-side tools so the client can complete that step and switch the GUI state to `已连接`.

## System proxy and TUN requirements

For the Speedcat Linux client to report a successful connection in GUI mode, the container needs both:

- proxy runtime privileges such as `NET_ADMIN` and `/dev/net/tun`
- desktop proxy integration tools such as `gsettings` and `dconf`

If you are upgrading an older deployment that still lacks these settings, rebuild and restart it. The compatibility overlay remains available:

```bash
docker compose -f docker-compose.yml -f docker-compose.tun.yml up -d --build
```

The overlay keeps the older TUN privilege patch path available, but new deployments already include those settings in `docker-compose.yml`.

## Connection verification

After login, a healthy GUI-mode connection should now satisfy all of these at once:

- the GUI switches from `未连接` to `已连接`
- the embedded `mihomo` process stays alive
- proxy ports such as SOCKS5 and DNS remain reachable inside the container or on the host
- traffic can pass through the configured proxy path

This behavior was validated on the remote Ubuntu server used during this project:

- after rebuilding with the updated image and compose file, the GUI still opened normally
- clicking the main connect button switched the app state from `未连接` to `已连接`
- host listeners remained present on `127.0.0.1:19227`, `6454`, and `1053`
- a real SOCKS5 test request succeeded through `127.0.0.1:6454`
- the noVNC UI remained reachable on `127.0.0.1:6080`

## Headless core mode

If you later obtain a stable generated `mihomo` config, place it here:

```text
./data/config/config.yaml
```

Then set:

```text
MODE=core
```

and restart:

```bash
docker compose up -d
```

## GitHub usage

This repository is designed to be managed with GitHub:

- use Issues to record bugs and future improvements
- use Pull Requests for non-trivial changes
- keep runtime data out of Git
- write small, descriptive commit messages
- install Git LFS before pulling or replacing `linux.zip`

See `docs/GITHUB_WORKFLOW.md` for the recommended daily workflow.

For project history and pending technical work, also see:

- `docs/MAINTENANCE_NOTES.md`
- `docs/OPEN_ISSUES.md`
- `docs/SECURITY.md`

## Updating the Speedcat package later

When Speedcat releases a new Linux package:

1. Create a new branch
2. Replace `linux.zip` and the extracted package archive used by the build
3. Update documentation if the version or startup behavior changes
4. Commit and open a Pull Request for review

## Build notes

- `noVNC` is the default management UI
- raw `VNC` is kept as an internal backend for noVNC and is not published by default
- the default exposed proxy port is the SOCKS5 listener on `6454`
- DNS and control ports are opt-in through `docker-compose.admin-ports.yml`
- the default deployment now uses explicit Docker port mappings instead of `network_mode: host`
- the security-first default bind target is `127.0.0.1`
- this repository tracks deployment code and documentation, not account data or vendor downloads
