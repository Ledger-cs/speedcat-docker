# Security Guide

This project is intended for private infrastructure and should be operated with conservative defaults.

## Security model summary

The repository is designed around this assumption:

- operators should not need to build images on production servers
- runtime environments should pull a prebuilt image
- the management UI should stay private unless there is a strong reason to expose it

## Current default posture

The default deployment now does all of the following:

- publishes the noVNC UI on `127.0.0.1` by default
- publishes the SOCKS5 proxy on `127.0.0.1` by default
- does not publish DNS or control ports unless an extra compose overlay is used
- does not publish raw VNC
- drops all Linux capabilities and adds back only `NET_ADMIN`
- enables `no-new-privileges:true`
- keeps the noVNC backend behind an Nginx gateway
- supports optional HTTP Basic Auth
- supports optional VNC password protection
- supports Nginx-side request and connection limiting
- bounds Docker log retention with `max-size` and `max-file`
- disables in-container file logs by default

## Recommended access model

The safest routine access model is:

1. keep published ports on `127.0.0.1`
2. tunnel them over SSH from your client device
3. enable `UI_AUTH_USERNAME` and `UI_AUTH_PASSWORD`
4. optionally set `UI_PASSWORD`
5. keep admin ports disabled unless actively needed

Example:

```bash
ssh -L 6080:127.0.0.1:6080 -L 6454:127.0.0.1:6454 your-server
```

## UI protection layers

Two UI protection layers are available:

- `UI_AUTH_USERNAME` and `UI_AUTH_PASSWORD`
  - HTTP Basic Auth in front of the browser UI
- `UI_PASSWORD`
  - VNC password for the backend desktop session

These layers are intentionally optional because some deployments place a stronger external reverse proxy in front of the container and do not want duplicate login prompts.

Recommended practice:

- if the container is directly accessed or only SSH-tunneled, enable at least Basic Auth
- if the UI is exposed through another reverse proxy with strong access control, internal UI auth can be disabled deliberately
- if you are unsure, leave internal auth enabled

## Logging controls

The repository now treats Docker-managed logs as the default control plane for runtime logs.

Default protections:

- `DOCKER_LOG_MAX_SIZE=10m`
- `DOCKER_LOG_MAX_FILE=3`
- `ENABLE_FILE_LOGS=0`

This means:

- container logs are retained with bounded size
- process logs do not silently accumulate in `/data/logs` unless you opt in

If you enable file logs for debugging:

- keep them temporary
- use `FILE_LOG_MAX_BYTES` and `FILE_LOG_MAX_FILES` to bound retained history across restarts

## Optional admin ports

The DNS and control ports are intentionally excluded from the default deployment.

Only expose them when needed:

```bash
docker compose -f docker-compose.yml -f docker-compose.admin-ports.yml up -d
```

Even then:

- keep them bound to `127.0.0.1`
- reach them through SSH forwarding
- disable them again after the maintenance task is complete

## Privilege and trust implications

The Speedcat client still requires a broader runtime surface than a minimal headless proxy.

Security-relevant requirements include:

- `NET_ADMIN`
- `/dev/net/tun`
- `iptables`
- `nftables`
- GNOME proxy helpers such as `gsettings` and `dconf`

These are necessary for the validated connected-state workflow, but they also mean the container is not a trivial least-privilege service.

## Supply-chain integrity

The build path now includes:

- the official `ubuntu:24.04` base image
- SHA256 verification of `linux.zip`
- SHA256 verification of the extracted universal tarball inside that zip

Operational implication:

- if the vendor archive changes without a matching checksum update, the build fails early

## Residual risks

Even after hardening, meaningful risk remains:

- GUI mode has a broader attack surface than a pure headless core
- the container still needs network-affecting privileges
- the official client remains a third-party binary with limited observability
- exposing binds on `0.0.0.0` sharply increases risk
- if an external reverse proxy is misconfigured, disabling internal auth removes an extra safety layer

The long-term security improvement path is still to extract a stable `MODE=core` workflow and reduce dependence on the GUI stack.
