# Maintenance Notes

This document records the main technical findings, failed attempts, and working hypotheses discovered during the initial Speedcat Docker packaging effort.

## Environment that was validated

- Remote target server: Ubuntu 24.04.2
- Docker was not available initially
- Speedcat package analyzed from the downloaded Linux bundle
- Official client no longer supports Clash-style direct usage and instead relies on its own client flow

## Package inspection findings

- `scclient` is the official GTK and Flutter desktop shell
- `ScclientCore_amd64` is an embedded `mihomo` core
- The embedded core reports itself as Mihomo Meta `v1.19.23`
- The GUI appears to be required for login and subscription synchronization

## Containerization decisions made

- Default mode was set to `gui`
- GUI mode runs under `Xvfb` with `x11vnc` and `noVNC`
- A lighter `core` mode was also kept in `entrypoint.sh` for future pure headless use
- The latest default deployment exposes explicit Docker ports instead of relying on host networking
- The latest default deployment exposes:
  - one management UI through `noVNC`
  - one SOCKS5 proxy port on `6454`
  - optional UI authentication through `UI_PASSWORD`

## Problems encountered and how they were handled

### Docker installation

- Installing Docker from the official Docker apt repository failed on the remote server because of repository and network issues
- The workaround was to install `docker.io`, `docker-compose-v2`, and `docker-buildx` from the Ubuntu repository
- That fallback logic is now reflected in `install-docker-ubuntu.sh`

### Image build source

- Pulling the base image directly from Docker Hub was unreliable on the remote server
- The base image was switched to `docker.m.daocloud.io/library/ubuntu:24.04`

### Desktop client on a headless server

- The target servers do not provide a desktop environment
- GUI mode was packaged with virtual display and browser-accessible remote desktop so login can still be completed
- Ports `5900` and `6080` were verified during the initial deployment

### Runtime startup failure after login

- The Speedcat account login succeeded inside the container
- Node data synchronized successfully and a node such as `新加坡-01` appeared in the GUI
- Pressing the GUI start button still failed with an operation error and the app remained in `未连接`
- The embedded core process was observed starting with:
  - `-d /data/home/.local/share/scclient/clash`
  - `-f /data/home/.local/share/scclient/clash/config.yaml`
- However, the expected `config.yaml` was not found on disk when inspected afterward
- No proxy ports such as `7890`, `7891`, or `9090` became available on the host

### Logging and diagnostics difficulty

- `app_2026-04-16.log` is not plain text and did not yield readable errors during simple inspection
- `cache.db` is not a normal SQLite database
- These two facts make the official client state harder to reverse engineer than a normal desktop app

## Root cause identified

The final root cause was more specific than "the proxy core did not start".

- The embedded `mihomo` core was already starting correctly
- SOCKS5 and DNS listeners were already present
- Real proxy traffic could already pass through
- But the GUI still showed `未连接`

The reason is that the Speedcat Linux client does not decide its "connected" state only from the embedded core. It also depends on a system proxy integration step.

The client binary was observed invoking system integration commands such as:

- `gsettings set org.gnome.system.proxy ...`
- KDE-side configuration commands such as `kwriteconfig5`

In the original container:

- `NET_ADMIN` and `/dev/net/tun` were not available by default
- `iptables` and `nftables` were not baked into the image
- the GNOME proxy integration tools were missing, especially:
  - `gsettings`
  - `dconf`

That meant:

- the core could run
- the proxy could actually work
- but the GUI-side system proxy step still failed
- and the application refused to switch its status to `已连接`

After adding:

- `libglib2.0-bin`
- `dconf-cli`

and preserving the required runtime privileges:

- `NET_ADMIN`
- `/dev/net/tun`
- `iptables`
- `nftables`

the client could complete its full connection flow and the GUI status changed normally.

## Remote validation performed

The updated deployment was re-tested on the remote Ubuntu server after syncing the new `Dockerfile` and `docker-compose.yml`.

Observed results:

- the container rebuilt successfully
- the container started with `CAP_NET_ADMIN` and `/dev/net/tun`
- `gsettings`, `dconf`, `iptables`, and `nft` were present inside the container
- the GUI initially opened in `未连接`, which is expected before pressing the main connect button
- after simulating a click on the connect button, the GUI switched to `已连接`
- listeners were present on:
  - `127.0.0.1:19227`
  - `6454`
  - `1053`
- a real SOCKS5 request through `127.0.0.1:6454` succeeded

## UI and proxy exposure validation

After updating the deployment model to match the intended usage pattern:

- the container published `6080/tcp` for the management UI
- the container published `6454/tcp` for the SOCKS5 proxy
- the published bindings were limited to `127.0.0.1`
- `http://127.0.0.1:6080/vnc.html` returned `200 OK`
- a real SOCKS5 request through `127.0.0.1:6454` succeeded

Optional UI authentication was checked by comparing the `x11vnc` startup arguments:

- with no `UI_PASSWORD`, the process started with `-nopw`
- with `UI_PASSWORD` set, the no-password flag disappeared, indicating password-protected mode

HTTP Basic Auth for noVNC was also validated:

- without credentials, the UI endpoint returned `401 Unauthorized`
- with the configured credentials, the UI endpoint returned `200 OK`

The optional admin port overlay was validated as well:

- `127.0.0.1:19227` mapped to the control port
- `127.0.0.1:1053/tcp` mapped to the DNS TCP listener
- `127.0.0.1:1053/udp` mapped to the DNS UDP listener

## Actions already taken in the repository

- Added `libglib2.0-bin` and `dconf-cli` to the image
- Added `iptables` and `nftables` to the image
- Enabled `NET_ADMIN` and `/dev/net/tun` in the default compose deployment
- Kept `docker-compose.tun.yml` only as a backward-compatible overlay
- Documented the system proxy integration requirement in `README.md`
- Preserved both GUI and future core-only startup paths
- Added GitHub maintenance documentation so future work can continue from the recorded findings
