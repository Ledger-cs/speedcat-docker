# Maintenance Notes

This document records the main technical findings, validated fixes, and current maintenance baseline for the Speedcat Docker packaging project.

## Current validated baseline

The repository currently represents a working baseline with these characteristics:

- official base image reference uses `ubuntu:24.04`
- default runtime path expects a prebuilt image instead of a local build
- local builds remain available through `docker-compose.build.yml`
- the Dockerfile extracts the universal package directly from `linux.zip`
- the default deployment exposes:
  - one management UI on `127.0.0.1:6080`
  - one SOCKS5 proxy port on `127.0.0.1:6454`
- DNS and control ports remain opt-in through `docker-compose.admin-ports.yml`

## Package and artifact decisions

- `linux.zip` is the single source vendor artifact tracked in the repository
- the extracted `scclient_1.33.12_linux_universal_amd64.tar.gz` is no longer kept in Git because it already comes from `linux.zip`
- `speedcat-docker-bundle.tar.gz` was a bootstrap-time helper artifact and is no longer part of the repository contract
- Git LFS is used for tracked vendor archives because they are binary, non-diff-friendly, and expensive in normal Git history

## Deployment contract changes

Earlier revisions encouraged:

- cloning the repository on the server
- building locally on the server
- optionally using a repository-shipped Docker installer

The current contract is:

- operators are expected to have Docker already installed using their own platform-appropriate method
- operators pull a prebuilt image and run it with `docker compose`
- maintainers or CI build and publish the image when package or code changes require it

This keeps deployment neutral across Ubuntu, Rocky Linux, and other distributions.

## Root cause that fixed the GUI connection state

The most important runtime finding remains unchanged:

- the embedded `mihomo` core could already start
- SOCKS5 and DNS listeners could already be present
- real proxy traffic could already pass
- but the GUI still showed `未连接`

The reason is that the Linux client does not decide its connected state only from the embedded core. It also depends on a system proxy integration step.

The client was observed invoking integration commands such as:

- `gsettings set org.gnome.system.proxy ...`
- KDE-side configuration helpers such as `kwriteconfig5`

The image therefore must include:

- `libglib2.0-bin`
- `dconf-cli`
- `iptables`
- `nftables`
- `NET_ADMIN`
- `/dev/net/tun`

After those additions, the client completed its full connection flow and the GUI switched to `已连接`.

## Logging model decisions

Earlier revisions wrote process logs into `/data/logs` by default.

That was changed because Docker deployments already have a natural logging path through container stdout/stderr, and unbounded in-container log files are easy to forget.

The current policy is:

- default to stdout/stderr
- bound container log retention via Docker logging options
- make in-container file logs opt-in with `ENABLE_FILE_LOGS=1`
- rotate oversized prior file logs on startup when file logging is enabled

## Remote validation highlights

The repository has already been validated against the remote server `einfash`.

Confirmed results include:

- the image built successfully
- the package checksum verification step returned `OK`
- the image was published to Docker Hub as `einfash/speedcat-scclient:1.33.12`
- the `latest` tag was also published
- the GUI opened through noVNC
- the client switched from `未连接` to `已连接`
- SOCKS5 traffic through `127.0.0.1:6454` succeeded
- UI authentication and rate limiting worked as expected
- the remote Docker daemon was validated pulling `einfash/speedcat-scclient:1.33.12` after adding a systemd proxy drop-in that points to `socks5://127.0.0.1:6454`
- a second container launched from the pulled image on alternate ports and exposed its authenticated UI successfully

## Remaining gaps

The project is functional, but some work remains open:

- a stable pure headless `MODE=core` workflow is still not documented end-to-end
- the official client's internal diagnostics remain hard to decode
- a full image publishing workflow should be automated if regular package refreshes become routine
- automated GUI interaction for a secondary pulled-image test container is still unreliable in the current headless verification setup, even though manual UI access and the primary validated service path both work
