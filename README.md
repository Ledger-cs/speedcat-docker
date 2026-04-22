# Speedcat Docker

This repository packages the updated Speedcat Linux client `scclient_1.33.12` into a portable Docker deployment for headless Linux servers.

The project supports two runtime modes:

- `gui`: runs the official Speedcat desktop client under `Xvfb` and exposes a browser-based management UI through noVNC
- `core`: runs the embedded `Mihomo Meta v1.19.23` core directly after a usable `config.yaml` is available

## Project goals

- Keep deployment portable across Linux servers
- Keep runtime data outside the container
- Make runtime updates work through prebuilt image pulls instead of mandatory local builds
- Keep local image rebuilds available only for maintainers or custom forks

## Runtime prerequisites

This repository assumes the target server already has a working Docker and Docker Compose environment.

That is an operator prerequisite, not part of the project contract. The repository no longer ships an OS-specific Docker installer because deployment hosts may be Ubuntu, Rocky Linux, or other distributions with different installation flows.

## Repository structure

- `docker-compose.yml`: default deployment for a prebuilt image
- `docker-compose.build.yml`: optional maintainer overlay that re-enables local image builds
- `docker-compose.admin-ports.yml`: optional DNS and control port exposure
- `docker-compose.tun.yml`: backward-compatible TUN overlay for older deployments
- `Dockerfile`: maintainer build definition for publishing the image
- `entrypoint.sh`: startup logic for `gui` and `core` modes
- `.env.example`: example runtime configuration
- `docs/GITHUB_WORKFLOW.md`: GitHub maintenance workflow
- `docs/MAINTENANCE_NOTES.md`: technical findings and troubleshooting history
- `docs/OPEN_ISSUES.md`: unresolved follow-up work
- `docs/SECURITY.md`: security posture and deployment guidance


## Preferred deployment model

The default deployment path is now:

1. Pull a prebuilt image from Docker Hub
2. Copy `.env.example` to `.env`
3. Adjust runtime settings
4. Start the container with `docker compose up -d`

This avoids forcing production or work servers to run a local `docker build` unless you are intentionally rebuilding or customizing the image.

## Default usage model

The default deployment is designed around this usage pattern:

1. expose one browser-based management UI
2. optionally protect that UI with authentication
3. expose one SOCKS5 proxy port for client traffic

By default:

- management UI bind: `127.0.0.1:6080`
- proxy bind: `127.0.0.1:6454`
- admin ports: not published
- UI HTTP authentication: disabled unless both `UI_AUTH_USERNAME` and `UI_AUTH_PASSWORD` are set
- VNC session password: disabled unless `UI_PASSWORD` is set

This default exposure model keeps the service aligned with SSH tunneling and private-server use.

## Quick start for operators

1. Pull the image you want to run:

```bash
docker pull einfash/speedcat-scclient:1.33.12
```

2. Copy the example environment file:

```bash
cp .env.example .env
```

3. Set the image reference and your runtime values in `.env`:

```text
SPEEDCAT_IMAGE=einfash/speedcat-scclient:1.33.12
NOVNC_BIND_ADDR=127.0.0.1
NOVNC_HOST_PORT=6080
PROXY_BIND_ADDR=127.0.0.1
PROXY_SOCKS_HOST_PORT=6454
UI_AUTH_USERNAME=admin
UI_AUTH_PASSWORD=change-me
UI_PASSWORD=change-me
```

4. Start the container:

```bash
docker compose up -d
```

5. Open the management UI through SSH forwarding:

```bash
ssh -L 6080:127.0.0.1:6080 -L 6454:127.0.0.1:6454 your-server
```

Then browse to:

- [http://127.0.0.1:6080/vnc.html](http://127.0.0.1:6080/vnc.html)

## Pure `docker run` deployment

If you do not want to clone this repository on the server, you can deploy directly from the published image:

```bash
mkdir -p ~/speedcat-data
sudo chown -R 10001:10001 ~/speedcat-data

docker run -d \
  --name speedcat-scclient \
  --restart unless-stopped \
  --cap-drop ALL \
  --cap-add NET_ADMIN \
  --device /dev/net/tun:/dev/net/tun \
  --security-opt no-new-privileges:true \
  --shm-size 512m \
  -p 127.0.0.1:6080:6080 \
  -p 127.0.0.1:6454:6454 \
  -e TZ=Asia/Shanghai \
  -e MODE=gui \
  -e ENABLE_VNC=1 \
  -e ENABLE_NOVNC=1 \
  -e ENABLE_FILE_LOGS=0 \
  -e LOG_DIR=/data/logs \
  -e FILE_LOG_MAX_BYTES=10485760 \
  -e FILE_LOG_MAX_FILES=3 \
  -e VNC_PORT=5900 \
  -e NOVNC_PORT=6080 \
  -e NOVNC_BACKEND_PORT=6081 \
  -e UI_AUTH_USERNAME=admin \
  -e UI_AUTH_PASSWORD=change-me \
  -e UI_PASSWORD=change-me \
  -e UI_RATE_LIMIT_RPS=5 \
  -e UI_RATE_LIMIT_BURST=20 \
  -e UI_RATE_LIMIT_CONN=10 \
  -e XVFB_WHD=1280x800x24 \
  -e CONFIG_DIR=/data/config \
  -e CONFIG_FILE=/data/config/config.yaml \
  -v "$HOME/speedcat-data:/data" \
  --log-driver json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  einfash/speedcat-scclient:1.33.12
```

If the host uses SELinux, change the bind mount to:

```bash
-v "$HOME/speedcat-data:/data:Z"
```

## Image updates

Once you are using a published image, upgrades should look like this:

```bash
docker compose pull
docker compose up -d
```

That is the intended update path for normal runtime environments.

## Maintainer build flow

Local builds are still supported, but they are now explicitly a maintainer path instead of the default runtime path.

The maintainer build flow is:

1. clone the repository with Git LFS enabled
2. keep `linux.zip` available in the repository root
3. build with the extra build overlay:

```bash
docker compose -f docker-compose.yml -f docker-compose.build.yml build
```

The default maintainer build uses the official base image reference `ubuntu:24.04`.

If a maintainer is in a restricted network environment and cannot reach Docker Hub, the build path can override the base image explicitly without changing the Dockerfile:

```bash
BASE_IMAGE=docker.m.daocloud.io/library/ubuntu:24.04 \
docker compose -f docker-compose.yml -f docker-compose.build.yml build
```

That override is intentionally optional. The repository default remains the official image reference.

The `Dockerfile` now extracts the universal Linux tarball directly from `linux.zip` during the build, then verifies:

- the SHA256 of `linux.zip`
- the SHA256 of the extracted universal tarball

This keeps one source artifact in Git while still protecting build integrity.

## UI and proxy configuration

The main runtime knobs are:

- `SPEEDCAT_IMAGE`: image reference to run
- `SPEEDCAT_PULL_POLICY`: compose pull policy for the image
- `NOVNC_BIND_ADDR`: host bind address for the management UI
- `NOVNC_HOST_PORT`: host port for the management UI
- `PROXY_BIND_ADDR`: host bind address for the SOCKS5 proxy
- `PROXY_SOCKS_HOST_PORT`: host port for the SOCKS5 proxy
- `UI_AUTH_USERNAME`: optional HTTP Basic Auth username
- `UI_AUTH_PASSWORD`: optional HTTP Basic Auth password
- `UI_PASSWORD`: optional password for the noVNC/VNC session
- `UI_RATE_LIMIT_RPS`: UI request rate limit
- `UI_RATE_LIMIT_BURST`: short burst allowance
- `UI_RATE_LIMIT_CONN`: per-client concurrent UI connections

Example:

```text
SPEEDCAT_IMAGE=einfash/speedcat-scclient:1.33.12
NOVNC_BIND_ADDR=127.0.0.1
NOVNC_HOST_PORT=16080
PROXY_BIND_ADDR=127.0.0.1
PROXY_SOCKS_HOST_PORT=16454
UI_AUTH_USERNAME=admin
UI_AUTH_PASSWORD=change-me
UI_PASSWORD=change-me
```

Then restart:

```bash
docker compose up -d
```

## Bind-mount permissions

The runtime image does not run as `root`. That means a host bind mount such as:

```bash
-v "$HOME/speedcat-data:/data"
```

must be writable by the container runtime user.

This is a general Linux container rule, not a quirk of one specific server:

- if a container runs as a non-root user
- and a host directory is bind-mounted into it
- then that host directory must be writable by the container user

For the current published image, the runtime user resolves to `UID/GID 10001`, so the practical fix is:

```bash
sudo chown -R 10001:10001 ~/speedcat-data
```

If you switch to a future image that uses a different runtime user, inspect that image first instead of assuming `10001` forever:

```bash
docker image inspect einfash/speedcat-scclient:1.33.12 --format '{{.Config.User}}'
docker run --rm --entrypoint sh einfash/speedcat-scclient:1.33.12 -c 'id -u scclient && id -g scclient'
```

If this is not handled, the container may restart with errors creating `/data/home` or `/data/config`.

## Proxy model and TUN expectations

The validated operator-facing runtime model for this project is:

- one authenticated browser UI
- one explicit SOCKS5 proxy port on `127.0.0.1:6454`

The image still includes `NET_ADMIN`, `/dev/net/tun`, `iptables`, `nftables`, `gsettings`, and `dconf` because the official Linux client depends on those pieces during its connection workflow and connected-state handling.

However, that does not mean the host is automatically running in a transparent whole-machine TUN mode.

The currently validated usage pattern is:

- connect the Speedcat client in the UI
- let the embedded core expose the SOCKS5 endpoint on `6454`
- point host applications or services at that SOCKS5 proxy explicitly

In other words:

- validated: explicit per-application proxying through `127.0.0.1:6454`
- not yet validated as a project contract: host-wide transparent traffic capture for every service on the server

## Published image

The maintained prebuilt image is currently published as:

- `einfash/speedcat-scclient:1.33.12`
- `einfash/speedcat-scclient:latest`

Operators should prefer the pinned version tag for predictable rollouts.

## Constrained-network pulls

If the host cannot reach Docker Hub directly, the Docker daemon itself may need a proxy.

One validated pattern on the remote server was to point Docker's systemd service at an already-working local SOCKS5 proxy:

```ini
[Service]
Environment="HTTP_PROXY=socks5://127.0.0.1:6454"
Environment="HTTPS_PROXY=socks5://127.0.0.1:6454"
Environment="NO_PROXY=localhost,127.0.0.1"
```

After adding a drop-in like `/etc/systemd/system/docker.service.d/http-proxy.conf`, reload and restart Docker:

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

Then `docker pull einfash/speedcat-scclient:1.33.12` was validated successfully on the remote host.

## Optional DNS and control port exposure

The default deployment does not publish the internal DNS and control ports. If you really need them, use the optional overlay:

```bash
docker compose -f docker-compose.yml -f docker-compose.admin-ports.yml up -d
```

That overlay can expose:

- `19227` for the internal control interface
- `1053/tcp` and `1053/udp` for the DNS listener

These ports still default to `127.0.0.1` in `.env.example` for safety.

## Logging policy

The repository now treats Docker logging as the default logging path.

By default:

- in-container file logs are disabled with `ENABLE_FILE_LOGS=0`
- process logs go to container stdout/stderr
- Docker log retention is bounded through compose options:
  - `DOCKER_LOG_MAX_SIZE`
  - `DOCKER_LOG_MAX_FILE`

If you need persistent debug logs inside the mounted data directory, you can opt in:

```text
ENABLE_FILE_LOGS=1
LOG_DIR=/data/logs
FILE_LOG_MAX_BYTES=10485760
FILE_LOG_MAX_FILES=3
```

When file logging is enabled, the entrypoint rotates oversized previous log files on startup.


## System proxy and TUN requirements

For the Speedcat Linux client to report a successful connection in GUI mode, the container needs both:

- proxy runtime privileges such as `NET_ADMIN` and `/dev/net/tun`
- desktop proxy integration tools such as `gsettings` and `dconf`

The compatibility overlay remains available:

```bash
docker compose -f docker-compose.yml -f docker-compose.tun.yml up -d
```

New deployments already include those settings in `docker-compose.yml`.

## Connection verification

After login, a healthy GUI-mode connection should now satisfy all of these at once:

- the GUI switches from `未连接` to `已连接`
- the embedded `mihomo` process stays alive
- proxy ports such as SOCKS5 and DNS remain reachable
- traffic can pass through the configured proxy path

Minimal verification example:

```bash
curl --socks5-hostname 127.0.0.1:6454 https://api.ipify.org
```

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

## Updating the vendor package later

When Speedcat releases a new Linux package:

1. create a dedicated branch
2. replace `linux.zip`
3. recalculate the SHA256 of `linux.zip`
4. update `SPEEDCAT_LINUX_ZIP_SHA256` in `Dockerfile`
5. recalculate the SHA256 of the extracted universal tarball inside `linux.zip`
6. update `SCCLIENT_TARBALL_NAME` and `SCCLIENT_TARBALL_SHA256` in `Dockerfile`
7. rebuild with the maintainer build overlay
8. publish the new image tag
9. update runtime documentation if behavior changed

Example SHA256 commands:

Windows PowerShell:

```powershell
Get-FileHash .\linux.zip -Algorithm SHA256
```

Linux:

```bash
sha256sum ./linux.zip
```

The build now fails early if either the tracked zip or the extracted universal tarball does not match the expected checksum.


See:

- `docs/GITHUB_WORKFLOW.md`
- `docs/MAINTENANCE_NOTES.md`
- `docs/OPEN_ISSUES.md`
- `docs/SECURITY.md`
