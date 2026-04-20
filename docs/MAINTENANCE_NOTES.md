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
- Host networking was selected so proxy ports bind directly on the Linux server

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

## Most likely cause identified

The strongest working theory is that the GUI start action enables TUN mode or a similar system-level proxy mode by default. In the original deployment:

- the host had `/dev/net/tun`
- the container did not have `/dev/net/tun`
- the container also did not have `NET_ADMIN`

That combination is consistent with a start failure on a headless container even though account login and node synchronization work.

## Actions already taken in the repository

- Added `docker-compose.tun.yml`
- Documented TUN startup troubleshooting in `README.md`
- Preserved both GUI and future core-only startup paths
- Added GitHub maintenance documentation so future work can continue from the recorded findings
