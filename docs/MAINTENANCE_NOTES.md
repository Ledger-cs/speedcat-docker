# Maintenance Notes

This document records the main technical findings, failed attempts, validated fixes, and current maintenance baseline for the Speedcat Docker packaging project.

## Current validated baseline

The repository currently represents a working and re-tested baseline with these characteristics:

- target platform validated on a remote Ubuntu 24.04 server
- Docker image built from Ubuntu 24.04 pinned by digest
- default runtime mode is `gui`
- GUI mode runs through `Xvfb` + `x11vnc` + `noVNC`
- default published ports are:
  - `127.0.0.1:6080` for the browser UI
  - `127.0.0.1:6454` for the SOCKS5 proxy
- optional admin overlay can additionally expose:
  - `127.0.0.1:19227`
  - `127.0.0.1:1053/tcp`
  - `127.0.0.1:1053/udp`
- build-time package integrity is enforced through SHA256 verification of the tracked Speedcat tarball

## Package inspection findings

- `scclient` is the official desktop client shell
- `ScclientCore_amd64` is the embedded proxy core
- the embedded core identifies itself as Mihomo Meta `v1.19.23`
- the official Linux flow no longer behaves like the earlier Clash-style package model
- login and subscription synchronization still appear to depend on the official GUI path

## Key design decisions

- keep `MODE=gui` as the operational default because it is the only fully validated bootstrap path
- keep `MODE=core` available for future headless use once a stable config extraction path exists
- expose only one management UI and one proxy port by default
- keep DNS and control ports opt-in through `docker-compose.admin-ports.yml`
- default all published ports to `127.0.0.1` so SSH tunneling remains the recommended access pattern
- keep the image focused on runtime dependencies rather than general debugging tooling

## Problems encountered and how they were resolved

### Docker installation on the remote server

Problem:

- Docker was not installed on the target server
- installing from the official Docker apt repository was unreliable because of repository or network issues

Resolution:

- switched the installation helper to use Ubuntu-packaged `docker.io`, `docker-compose-v2`, and `docker-buildx` as a fallback path

Repository impact:

- `install-docker-ubuntu.sh` now reflects the fallback logic

### Base image pull reliability

Problem:

- pulling directly from Docker Hub was unreliable on the remote host

Resolution:

- switched the image source to `docker.m.daocloud.io/library/ubuntu:24.04`
- later pinned the exact digest for stronger reproducibility

Repository impact:

- `Dockerfile` now uses a digest-pinned Ubuntu base image

### Running a desktop-only client on a headless server

Problem:

- the target Linux virtual servers are headless
- the Speedcat provider flow still requires the official GUI for login and node sync

Resolution:

- packaged the desktop client into a virtual display environment
- exposed browser-based access through noVNC
- kept raw VNC internal and unpublished by default

Repository impact:

- `entrypoint.sh` starts `Xvfb`, `fluxbox`, `x11vnc`, `websockify`, and the Nginx UI gateway in GUI mode

### "Operation failed" / GUI stuck at `未连接`

Problem:

- login succeeded
- nodes synchronized
- the embedded core was starting
- SOCKS5 and DNS listeners were already coming up
- real proxy traffic could pass
- but the GUI still showed `未连接`

Root cause:

- the Linux client does not treat "core started" as the only success condition
- it also attempts system proxy integration before changing the GUI state
- the binary was observed invoking system integration commands such as:
  - `gsettings set org.gnome.system.proxy ...`
  - KDE-side configuration helpers such as `kwriteconfig5`
- the earlier container lacked the required support chain:
  - `libglib2.0-bin` for `gsettings`
  - `dconf-cli`
  - `iptables`
  - `nftables`
  - required privileges such as `NET_ADMIN` and `/dev/net/tun`

Resolution:

- added `libglib2.0-bin` and `dconf-cli` to the image
- added `iptables` and `nftables` to the image
- enabled `NET_ADMIN`
- mounted `/dev/net/tun`

Repository impact:

- the default compose deployment now includes the privileges needed for the validated connection path
- `docker-compose.tun.yml` remains only as a backward-compatible overlay

### UI hardening and exposure control

Problem:

- the initial browser-accessible GUI path needed stronger protection for private-server use

Resolution:

- added HTTP Basic Auth support in front of noVNC
- added optional VNC password support
- added request rate limiting and concurrent connection limiting in Nginx
- limited default host exposure to loopback addresses
- moved DNS and control ports into an optional compose overlay

Repository impact:

- the default deployment is now safer for SSH-tunneled private use

### Build-input integrity

Problem:

- replacing the tracked Speedcat tarball without any guard could silently change the build contents

Resolution:

- added `SCCLIENT_TARBALL_SHA256` to `Dockerfile`
- verified the archive with `sha256sum -c` before extraction

Repository impact:

- image builds now fail early if the tracked tarball does not match the expected checksum

## Validation performed on the remote server

The current baseline was re-tested on the remote host `einfash`.

Observed results:

- `docker compose build` succeeded
- the SHA256 verification step returned `OK`
- the container started with `CAP_NET_ADMIN` and `/dev/net/tun`
- `gsettings`, `dconf`, `iptables`, and `nft` were available inside the container
- the GUI opened normally through noVNC
- after pressing the connect action, the client changed from `未连接` to `已连接`
- host listeners were observed on:
  - `127.0.0.1:6080`
  - `127.0.0.1:6454`
  - `127.0.0.1:19227` when the admin overlay was enabled
  - `127.0.0.1:1053` for TCP and UDP when the admin overlay was enabled
- a real SOCKS5 request through `127.0.0.1:6454` succeeded
- HTTP Basic Auth returned `401 Unauthorized` when credentials were missing and `200 OK` when they were correct
- the UI limiter could reject repeated requests with `429 Too Many Requests`

## Current repository status

The following maintenance work is already reflected in the repository:

- GUI bootstrap path packaged for headless Linux servers
- future `MODE=core` path preserved but not yet fully operationally documented
- Docker installation helper with Ubuntu fallback
- explicit port-publishing compose model
- optional admin-port overlay
- compatibility TUN overlay for older deployments
- image hardening and runtime package trimming
- package checksum verification
- GitHub workflow documentation
- maintenance, security, and open-issue tracking in `docs/`

## Remaining gaps

The project is functional, but a few important areas remain open:

- a repeatable pure headless `MODE=core` workflow is still not extracted
- the official client's internal logs remain hard to decode
- long-term package update testing will need to confirm whether future vendor releases preserve the same connection assumptions
