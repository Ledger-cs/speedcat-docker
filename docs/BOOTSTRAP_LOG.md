# Project Bootstrap Log

This file records how the repository moved from the first import to the current validated packaging baseline.

## Repository foundation

- Initialized Git with `main` as the default branch
- Added the first project commit for the Docker image, startup script, compose files, and documentation
- Added `.gitignore` to keep runtime data, logs, caches, screenshots, and local-only notes out of version control
- Added `.gitattributes` so Linux-facing files stay on LF line endings
- Connected the local repository to `git@github.com:Ledger-cs/speedcat-docker.git`
- Standardized SSH-based GitHub usage after GitHub CLI web login proved unreliable in the local shell

## Reproducible build inputs

- Added the vendor package archives needed to reproduce the image build
- Tracked `linux.zip` with Git LFS because it exceeds GitHub's normal object size limit
- Kept runtime-generated files out of Git so account state and host-specific data do not leak into the repository
- Added build-time SHA256 verification for `scclient_1.33.12_linux_universal_amd64.tar.gz`
- Documented how to refresh the package hash when the vendor package changes

## Deployment model milestones

- Added `install-docker-ubuntu.sh` with Ubuntu repository fallback logic for Docker installation
- Kept `docker-compose.tun.yml` as a backward-compatible overlay while moving required TUN settings into the default deployment
- Standardized the default deployment around:
  - one browser-accessible management UI
  - one SOCKS5 proxy port
  - optional admin-port exposure through a separate compose overlay
- Switched away from broader host-level exposure to explicit Docker port publishing
- Kept `MODE=gui` as the default bootstrap path and preserved `MODE=core` for future pure headless operation

## Security and hardening milestones

- Added HTTP Basic Auth support in front of noVNC through Nginx
- Added optional VNC password support for the desktop session backend
- Added UI rate limiting and per-client connection limiting in Nginx
- Limited default host bindings to `127.0.0.1`
- Kept raw VNC unpublished by default
- Dropped all container capabilities by default and added back only `NET_ADMIN`
- Enabled `no-new-privileges:true`
- Pinned the Ubuntu base image by digest
- Removed unnecessary runtime packages such as `curl` and `procps`

## Runtime compatibility milestones

- Added `iptables`, `nftables`, `libglib2.0-bin`, and `dconf-cli` to satisfy the Linux client's real connection path
- Confirmed that the earlier `未连接` state was caused by incomplete system proxy integration rather than a dead proxy core
- Preserved `/dev/net/tun` and `NET_ADMIN` in the default compose deployment because the client depends on them for a successful connected state

## Remote validation baseline

The repository was validated against the remote server `einfash` after the major packaging and hardening changes.

Confirmed results:

- `docker compose build` succeeded on the remote Ubuntu host
- the package checksum verification step returned `OK`
- the default deployment published only `127.0.0.1:6080` and `127.0.0.1:6454`
- the noVNC UI returned `200 OK` when allowed and `401 Unauthorized` when Basic Auth was enabled without credentials
- repeated authenticated UI requests could be throttled with `429 Too Many Requests`
- the optional admin overlay correctly exposed `19227` and `1053`
- the Speedcat GUI changed from `未连接` to `已连接` after the dependency fix
- SOCKS5 traffic through port `6454` succeeded

## Current baseline

At this point the repository is no longer only an initial bootstrap. It now represents the current maintained baseline for:

- portable Docker packaging
- GitHub-based change tracking
- private-server deployment with safer defaults
- GUI bootstrap with verified connected-state behavior
