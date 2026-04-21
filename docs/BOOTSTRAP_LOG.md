# Project Bootstrap Log

This file records how the repository evolved from the first bootstrap into the current deployment baseline.

## Repository foundation

- initialized Git with `main` as the default branch
- connected the repository to GitHub over SSH
- added `.gitignore` and `.gitattributes`
- documented the runtime and maintenance workflows

## Package tracking evolution

Early repository state kept multiple binary artifacts around during investigation.

The current policy is stricter:

- keep only `linux.zip` as the source vendor artifact
- track vendor archives through Git LFS
- do not keep extracted tarballs in Git when they already come from `linux.zip`
- do not keep one-off repository bundle archives as long-term project artifacts

This reduced update-consistency risk and made the artifact contract clearer.

## Deployment model evolution

Early revisions focused on local image builds directly on the target server.

The current model separates:

- operator deployment
  - pull a prebuilt image
  - run `docker compose up -d`
- maintainer publishing
  - build locally or in CI with `docker-compose.build.yml`
  - publish a tagged image

This change was made so production and work environments are not forced to run local builds during normal updates.

## Security and runtime milestones

- packaged the GUI client for headless servers with `Xvfb`, `x11vnc`, `websockify`, and noVNC
- added HTTP Basic Auth in front of the noVNC UI
- added optional VNC password support
- added Nginx-side request and connection limiting
- limited default published binds to `127.0.0.1`
- kept raw VNC unpublished
- kept only `NET_ADMIN` after dropping all other Linux capabilities
- enabled `no-new-privileges:true`

## Runtime compatibility milestones

- identified that the Linux client's connected state depends on both proxy startup and system proxy integration
- added `iptables`, `nftables`, `libglib2.0-bin`, and `dconf-cli`
- validated that the GUI now switches from `未连接` to `已连接`

## Image build milestones

- switched the Dockerfile back to the official `ubuntu:24.04` base instead of a mirror-prefixed image reference
- changed the build to extract the universal tarball directly from `linux.zip`
- added SHA256 verification for both `linux.zip` and the extracted universal tarball
- kept local rebuilds available through `docker-compose.build.yml`

## Logging milestones

- changed the default logging model to container stdout/stderr
- bounded Docker log retention through compose logging options
- made in-container file logs opt-in for debugging instead of default runtime behavior
