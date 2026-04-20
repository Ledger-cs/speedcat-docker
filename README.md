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
- `docker-compose.yml`: default deployment
- `docker-compose.tun.yml`: optional TUN capability overlay
- `install-docker-ubuntu.sh`: Docker installation helper with fallback logic
- `docs/GITHUB_WORKFLOW.md`: recommended GitHub maintenance workflow
- `docs/MAINTENANCE_NOTES.md`: technical findings and troubleshooting history
- `docs/OPEN_ISSUES.md`: unresolved follow-up work for future maintenance

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

## GUI bootstrap mode

This is the safest mode when the provider only supports login and subscription sync in the official client.

After startup:

1. Forward or open port `6080`
2. Visit `http://SERVER_IP:6080/vnc.html`
3. Log in to your Speedcat account
4. Select the node you want to use
5. Try enabling the proxy service

Persistent client data is stored under `./data`, so login state survives container recreation.

## TUN mode troubleshooting

On headless Linux servers, Speedcat may fail with an operation error if the client tries to enable TUN mode but the container does not have TUN access.

If startup fails after login, start the container with the TUN overlay:

```bash
docker compose -f docker-compose.yml -f docker-compose.tun.yml up -d --build
```

This adds:

- `NET_ADMIN`
- `/dev/net/tun:/dev/net/tun`

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

## Updating the Speedcat package later

When Speedcat releases a new Linux package:

1. Create a new branch
2. Replace `linux.zip` and the extracted package archive used by the build
3. Update documentation if the version or startup behavior changes
4. Commit and open a Pull Request for review

## Build notes

- `noVNC` listens on port `6080`
- raw `VNC` listens on port `5900`
- proxy ports are controlled by Speedcat itself
- the default deployment uses `network_mode: host`
- this repository tracks deployment code and documentation, not account data or vendor downloads
