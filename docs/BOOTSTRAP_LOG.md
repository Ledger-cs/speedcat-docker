# Project Bootstrap Log

This file records the initial repository setup so future maintenance stays understandable.

## Initial repository construction

- Initialized a Git repository with `main` as the default branch
- Added a first commit for the Docker image, startup scripts, and project documentation
- Added `.gitignore` to exclude runtime data, archives, logs, and local captures
- Added `.gitattributes` to keep Linux-facing files on LF line endings

## Repository documentation improvements

- Reworked `README.md` into a GitHub-friendly project overview
- Added `docs/GITHUB_WORKFLOW.md` for future branch, commit, push, and PR usage
- Documented that the vendor archive should be downloaded separately and not committed

## Deployment improvements

- Added `docker-compose.tun.yml` as an optional overlay for TUN mode
- Updated `install-docker-ubuntu.sh` to fall back to Ubuntu packages if the official Docker repository fails

## Repository content policy

- Included the installation package archives needed to reproduce the build
- Kept runtime screenshots, logs, caches, and database files out of Git to avoid uploading environment-specific session data

## Current GitHub status

- Local Git history was initialized successfully
- The GitHub repository was created and connected successfully
- SSH-based push was used because GitHub CLI web authentication was unreliable in the local shell environment
