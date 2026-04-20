# Security Guide

This project is intended for private infrastructure and should be operated with conservative exposure and explicit trust assumptions.

## Security model summary

The current repository is hardened for a private-server deployment model, not for wide public exposure.

The intended access pattern is:

1. bind published ports to `127.0.0.1`
2. reach them through SSH local forwarding
3. protect the browser UI with HTTP Basic Auth
4. optionally protect the VNC backend with a second password layer

This model reduces accidental exposure, but it does not eliminate the risk of running a third-party GUI client with network privileges.

## Current default posture

The default deployment now does all of the following:

- publishes noVNC on `127.0.0.1` by default
- publishes the SOCKS5 proxy on `127.0.0.1` by default
- does not publish DNS or control ports unless an extra compose overlay is used
- does not publish raw VNC
- drops all Linux capabilities and adds back only `NET_ADMIN`
- enables `no-new-privileges:true`
- keeps `x11vnc` bound to localhost inside the container
- keeps the noVNC backend behind an Nginx gateway instead of exposing `websockify` directly
- supports UI authentication and Nginx-side rate limiting
- pins the base image by digest
- verifies the tracked Speedcat tarball with SHA256 before extraction

This default posture was validated on the remote server:

- only `127.0.0.1:6080` and `127.0.0.1:6454` were published in the standard deployment
- the browser UI remained reachable through the Nginx gateway
- SOCKS5 proxy traffic still worked

## Recommended access model

The safest routine access model is:

1. keep all published ports on `127.0.0.1`
2. tunnel them over SSH from your local machine
3. enable `UI_AUTH_USERNAME` and `UI_AUTH_PASSWORD`
4. optionally set `UI_PASSWORD` as a second UI layer
5. keep admin ports disabled unless you actively need them

Example SSH forwarding:

```bash
ssh -L 6080:127.0.0.1:6080 -L 6454:127.0.0.1:6454 einfash
```

If you also need the optional admin ports for testing:

```bash
ssh -L 19227:127.0.0.1:19227 -L 1053:127.0.0.1:1053 einfash
```

## UI protection layers

Two UI protection layers are available and can be used together:

- `UI_AUTH_USERNAME` and `UI_AUTH_PASSWORD`
  - adds HTTP Basic Auth in front of the browser UI
- `UI_PASSWORD`
  - adds a VNC password to the desktop backend

Recommended practice:

- for SSH-tunneled private use, Basic Auth should be considered the minimum
- for any semi-exposed deployment, use both layers

Validated behavior:

- unauthenticated UI requests returned `401 Unauthorized`
- authenticated UI requests returned `200 OK`

## UI rate limiting

The Nginx gateway applies request and connection limits before traffic reaches the noVNC backend.

Available controls:

- `UI_RATE_LIMIT_RPS`
- `UI_RATE_LIMIT_BURST`
- `UI_RATE_LIMIT_CONN`

Default values:

- `UI_RATE_LIMIT_RPS=5`
- `UI_RATE_LIMIT_BURST=20`
- `UI_RATE_LIMIT_CONN=10`

Validated behavior:

- unauthenticated requests still returned `401 Unauthorized`
- authenticated requests were accepted initially
- repeated fast authenticated requests were rejected with `429 Too Many Requests`

This is a useful protection against repeated login attempts and low-effort UI abuse, but it is not a substitute for keeping the service private.

## Optional admin ports

The DNS and control ports are intentionally excluded from the default deployment.

Only expose them when needed:

```bash
docker compose -f docker-compose.yml -f docker-compose.admin-ports.yml up -d
```

If you enable them:

- keep them bound to `127.0.0.1`
- reach them through SSH forwarding
- disable them again when the maintenance task is complete

## Privilege and trust implications

The Speedcat client currently requires a wider runtime surface than a minimal headless proxy.

Security-relevant requirements include:

- `NET_ADMIN`
- `/dev/net/tun`
- `iptables`
- `nftables`
- GNOME proxy helpers such as `gsettings` and `dconf`

Those requirements are necessary for the validated connected-state workflow, but they also increase trust in the containerized binary and in the host boundary around it.

## Supply-chain integrity

Two integrity controls are now in place:

- the Ubuntu base image is pinned by digest
- the tracked Speedcat tarball is checked with SHA256 during the build

Operational implication:

- if the vendor tarball changes without a matching checksum update, the build will fail early
- when the vendor publishes a new package, update the checksum in `Dockerfile` and re-run validation before merging

## Residual risks

Even after hardening, meaningful risk remains:

- GUI mode still has a broader attack surface than a pure headless core
- the container still needs network-affecting privileges
- the official client remains a third-party binary with limited observability
- exposing ports on `0.0.0.0` increases risk sharply
- a compromised SSH account or host weakens the protection of loopback-only bindings
- future vendor updates may change runtime behavior or dependency assumptions

The long-term security improvement path is still to extract a stable `MODE=core` workflow and reduce dependence on the GUI stack.

## Operational recommendations

- keep `.env` files with real credentials out of Git
- use strong, unique values for `UI_AUTH_PASSWORD` and `UI_PASSWORD`
- rotate UI credentials if they are ever shared
- restrict SSH key access and disable unused remote access paths
- prefer SSH tunnels over public port exposure
- do not expose `6454`, `1053`, or `19227` publicly unless protected by additional network controls
- rebuild after package or dependency updates
- re-review this document whenever ports, privileges, authentication, or build inputs change
