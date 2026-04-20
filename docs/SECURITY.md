# Security Guide

This project is intended for private infrastructure and should be run with conservative defaults.

## Default security posture

The current default deployment aims to reduce accidental exposure:

- noVNC binds to `127.0.0.1` by default
- the SOCKS5 proxy binds to `127.0.0.1` by default
- DNS and control ports are not published by default
- raw VNC is not published by default
- Linux capabilities are reduced with `cap_drop: [ALL]` and only `NET_ADMIN` is added back
- `no-new-privileges:true` is enabled
- x11vnc listens only on localhost inside the container

This default posture was validated on the remote server:

- only `127.0.0.1:6080` and `127.0.0.1:6454` were published by default
- noVNC was reachable through the Nginx gateway
- proxy traffic continued to work through the SOCKS5 listener

## Recommended access model

The safest access model is:

1. keep all published ports on `127.0.0.1`
2. access them through SSH local forwarding
3. enable HTTP Basic Auth for noVNC
4. optionally enable a second password layer with `UI_PASSWORD`

Example SSH forwarding:

```bash
ssh -L 6080:127.0.0.1:6080 -L 6454:127.0.0.1:6454 einfash
```

## UI protection

Two UI protection layers are available:

- `UI_AUTH_USERNAME` and `UI_AUTH_PASSWORD`: HTTP Basic Auth in front of noVNC
- `UI_PASSWORD`: VNC session password for the backend desktop

For a private but internet-facing server, enabling both is recommended.

The Basic Auth layer was verified with real requests:

- unauthenticated requests returned `401 Unauthorized`
- authenticated requests returned `200 OK`

## Optional admin ports

The DNS and control ports are intentionally kept out of the default deployment.

Only expose them when needed:

```bash
docker compose -f docker-compose.yml -f docker-compose.admin-ports.yml up -d
```

Even then, prefer binding them to `127.0.0.1` and forwarding them over SSH rather than exposing them publicly.

## Residual risks

Even after hardening, this setup still has meaningful risk areas:

- GUI mode requires a broader runtime surface than a pure headless proxy
- the container still needs `NET_ADMIN` and `/dev/net/tun`
- the official client remains a third-party binary with limited observability
- if you intentionally change bind addresses to `0.0.0.0`, your exposure increases sharply
- if SSH access to the server is compromised, loopback-only binding is no longer a strong barrier

For the smallest attack surface, the long-term direction is still to extract a stable `MODE=core` workflow and minimize the GUI dependency.

## Operational recommendations

- Rotate UI passwords if they were ever shared
- Do not commit `.env` files with real credentials
- Keep SSH key access restricted
- Avoid exposing `6454`, `1053`, or `19227` to the public internet unless you also restrict by firewall
- Rebuild after package or dependency updates
- Review `docs/MAINTENANCE_NOTES.md` before making runtime changes
