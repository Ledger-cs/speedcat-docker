# Manual Validation for SpeedCat 3.0.3

This checklist validates the Docker packaging update for SpeedCat 3.0.3.

## Scope

- Vendor package: `linux.zip`
- Expected client package inside zip: `dist/SpeedCat-3.0.3-linux-amd64.deb`
- Expected image tag: `einfash/speedcat-scclient:3.0.3`
- Optional rolling tag: `einfash/speedcat-scclient:latest`

## Package Integrity

Run from the repository root:

```bash
sha256sum linux.zip
unzip -l linux.zip
unzip -j linux.zip dist/SpeedCat-3.0.3-linux-amd64.deb -d /tmp
sha256sum /tmp/SpeedCat-3.0.3-linux-amd64.deb
```

Expected hashes:

```text
1e151010e1aaef5b75881c2604a553c7134653ff5c00d2d51dd04b17d91e3976  linux.zip
ae2fcd43177cae03daf70503faeeb73aec92abfe1b7f26539fa852473eb59a9c  /tmp/SpeedCat-3.0.3-linux-amd64.deb
```

## Build

Default build:

```bash
docker compose -f docker-compose.yml -f docker-compose.build.yml build
```

Restricted-network build:

```bash
BASE_IMAGE=docker.m.daocloud.io/library/ubuntu:24.04 \
APT_MIRROR=http://mirrors.tuna.tsinghua.edu.cn/ubuntu \
docker compose -f docker-compose.yml -f docker-compose.build.yml build
```

Expected result:

```text
einfash/speedcat-scclient:3.0.3  Built
```

## Image File Checks

```bash
docker run --rm --entrypoint /usr/bin/id einfash/speedcat-scclient:3.0.3

docker run --rm --entrypoint /bin/ls einfash/speedcat-scclient:3.0.3 \
  -l /opt/scclient/SpeedCat \
     /opt/scclient/SpeedCatCore \
     /usr/local/bin/entrypoint.sh

docker run --rm --entrypoint /usr/bin/ldd einfash/speedcat-scclient:3.0.3 \
  /opt/scclient/SpeedCat
```

Expected:

- runtime user is `uid=10001(scclient)`
- `/opt/scclient/SpeedCat` exists and is executable
- `/opt/scclient/SpeedCatCore` exists and is executable
- `/usr/local/bin/entrypoint.sh` exists and is executable
- `ldd /opt/scclient/SpeedCat` does not show `not found`

`SpeedCatCore` may report `not a dynamic executable`; that is acceptable.

## Short Startup Smoke Test

This smoke test avoids host bind-mount permission issues by using the image volume.

```bash
docker rm -f speedcat-303-smoke >/dev/null 2>&1 || true

docker run -d \
  --name speedcat-303-smoke \
  --cap-add NET_ADMIN \
  --device /dev/net/tun:/dev/net/tun \
  --security-opt no-new-privileges:true \
  --shm-size 512m \
  -e NOVNC_PORT=16080 \
  -e VNC_PORT=15900 \
  -e NOVNC_BACKEND_PORT=16081 \
  -e ENABLE_NOVNC=1 \
  -e ENABLE_VNC=1 \
  -e UI_AUTH_USERNAME=smoke \
  -e UI_AUTH_PASSWORD=smoke \
  -e UI_PASSWORD=smoke \
  -e ENABLE_FILE_LOGS=0 \
  einfash/speedcat-scclient:3.0.3

sleep 12
docker ps --filter name=speedcat-303-smoke
docker logs --tail 120 speedcat-303-smoke
docker rm -f speedcat-303-smoke
```

Expected:

- container remains `Up` during the smoke window
- logs show Xvfb, Fluxbox, x11vnc, noVNC, Nginx, and SpeedCat startup
- first-run application logs may mention missing or invalid account/config state before login; that does not indicate Docker packaging failure

## Operator Deployment Check

After the image is published:

```bash
docker pull einfash/speedcat-scclient:3.0.3
docker compose pull
docker compose up -d
```

Then open the UI through SSH forwarding:

```bash
ssh -L 6080:127.0.0.1:6080 -L 6454:127.0.0.1:6454 your-server
```

Browse to:

```text
http://127.0.0.1:6080/vnc.html
```

Expected after login and connection:

- the GUI loads in noVNC
- the SpeedCat client can log in
- the connection state can switch to connected
- SOCKS5 traffic works through `127.0.0.1:6454`

Example proxy check:

```bash
curl --socks5-hostname 127.0.0.1:6454 https://api.ipify.org
```

## Notes

- Host bind mounts must be writable by `UID/GID 10001`.
- If Docker Hub access is slow or blocked, configure the Docker daemon proxy before pushing or pulling images.
