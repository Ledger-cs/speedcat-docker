# GitHub Maintenance Workflow

This project is maintained through GitHub so deployment code, image build inputs, and runtime changes remain traceable.

## Two distinct workflows

The repository now intentionally separates:

- operator workflow
  - pull a published image and run it
- maintainer workflow
  - update `linux.zip`, rebuild the image, publish a new tag

Operators should not need to build locally just to deploy or update the service.

## Operator workflow

Use this path for normal runtime usage:

1. pull the latest repository changes
2. update `.env` if runtime settings changed
3. pull the published image
4. restart the stack

Typical flow:

```bash
git pull
docker compose pull
docker compose up -d
```

## Maintainer workflow

Use this path only when you are changing image contents, startup logic, or vendor package inputs.

Recommended flow:

1. pull the latest `main`
2. create a dedicated branch
3. install Git LFS if needed
4. update code, docs, or `linux.zip`
5. build with `docker-compose.build.yml`
6. validate on a real Linux server
7. publish the new image tag
8. update `.env.example` or docs if runtime usage changed
9. push and open a Pull Request

Example:

```bash
git pull
git checkout -b feature/update-speedcat-package
git lfs install
docker compose -f docker-compose.yml -f docker-compose.build.yml build
git status
git add .
git commit -m "Update Speedcat package to 1.33.12"
git push -u origin feature/update-speedcat-package
gh pr create --fill
```

If your build environment cannot reach Docker Hub, you may override the base image at build time:

```bash
BASE_IMAGE=docker.m.daocloud.io/library/ubuntu:24.04 \
docker compose -f docker-compose.yml -f docker-compose.build.yml build
```

That is an operator-side compatibility override, not the default repository contract.

## Why Git LFS is required

Git LFS is used for vendor archives such as `linux.zip`.

This is necessary not only because GitHub has a 100 MB regular object limit, but also because:

- vendor archives are opaque binary blobs
- normal Git diffs are not useful for them
- repeated binary updates bloat repository history quickly

Use Git LFS whenever the repository intentionally tracks vendor package archives, even if a specific file is below 100 MB.

## Package update workflow

When Speedcat releases a new Linux package:

1. replace `linux.zip`
2. update `SPEEDCAT_LINUX_ZIP_SHA256` in `Dockerfile`
3. inspect the zip and confirm the universal tarball name
4. update `SCCLIENT_TARBALL_NAME` if the versioned filename changed
5. update `SCCLIENT_TARBALL_SHA256`
6. rebuild with the maintainer build overlay
7. validate on a Linux server
8. publish the image tag
9. document any behavior change

Example hash commands:

Windows PowerShell:

```powershell
Get-FileHash .\linux.zip -Algorithm SHA256
```

Linux:

```bash
sha256sum ./linux.zip
```

## Remote validation workflow

For image or runtime changes, validate on the Linux host before merging.

Typical flow:

```bash
scp Dockerfile entrypoint.sh docker-compose.yml docker-compose.build.yml einfash:~/speedcat-docker/
ssh einfash
cd ~/speedcat-docker
docker compose -f docker-compose.yml -f docker-compose.build.yml build
docker compose up -d
```

If the change affects optional admin ports or compatibility overlays, test those explicitly too.

## Commit message style

Use short messages that describe the concrete change:

- `Default compose to prebuilt images`
- `Build image from linux.zip only`
- `Switch Dockerfile to official Ubuntu base`
- `Bound runtime logs and disable file logs by default`

## Documentation discipline

- put operator instructions in `README.md`
- keep reusable maintenance knowledge in `docs/`
- keep `docs/OPEN_ISSUES.md` limited to unresolved work
- update `docs/SECURITY.md` whenever privileges, port exposure, logging, or image trust assumptions change
- update docs whenever the deployment contract changes from `build` to `pull`, or vice versa
