ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE} AS source

ENV DEBIAN_FRONTEND=noninteractive
ARG APT_MIRROR=
ARG SPEEDCAT_LINUX_ZIP_SHA256=1E151010E1AAEF5B75881C2604A553C7134653FF5C00D2D51DD04B17D91E3976
ARG SPEEDCAT_DEB_NAME=SpeedCat-3.0.3-linux-amd64.deb
ARG SPEEDCAT_DEB_SHA256=AE2FCD43177CAE03DAF70503FAEEB73AEC92ABFE1B7F26539FA852473EB59A9C

RUN if [ -n "${APT_MIRROR}" ]; then sed -i "s|http://archive.ubuntu.com/ubuntu|${APT_MIRROR}|g; s|http://security.ubuntu.com/ubuntu|${APT_MIRROR}|g" /etc/apt/sources.list.d/ubuntu.sources; fi \
    && apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    unzip \
    && rm -rf /var/lib/apt/lists/*

COPY linux.zip /tmp/linux.zip

RUN echo "${SPEEDCAT_LINUX_ZIP_SHA256}  /tmp/linux.zip" | sha256sum -c - \
    && unzip -j /tmp/linux.zip "dist/${SPEEDCAT_DEB_NAME}" -d /tmp \
    && echo "${SPEEDCAT_DEB_SHA256}  /tmp/${SPEEDCAT_DEB_NAME}" | sha256sum -c - \
    && dpkg-deb -x "/tmp/${SPEEDCAT_DEB_NAME}" /tmp/speedcat-root \
    && mkdir -p /opt/scclient \
    && cp -a /tmp/speedcat-root/usr/share/SpeedCat/. /opt/scclient/

ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive
ARG APT_MIRROR=

# Keep only runtime dependencies in the image. Diagnostics should use
# host-side docker tooling or temporary packages in ad hoc test containers.
RUN if [ -n "${APT_MIRROR}" ]; then sed -i "s|http://archive.ubuntu.com/ubuntu|${APT_MIRROR}|g; s|http://security.ubuntu.com/ubuntu|${APT_MIRROR}|g" /etc/apt/sources.list.d/ubuntu.sources; fi \
    && apt-get update && apt-get install -y --no-install-recommends \
    apache2-utils \
    ca-certificates \
    dbus-x11 \
    dconf-cli \
    fluxbox \
    fonts-dejavu-core \
    fonts-noto-cjk \
    libasound2t64 \
    libatk1.0-0 \
    libatspi2.0-0t64 \
    libayatana-appindicator3-1 \
    libcairo-gobject2 \
    libcairo2 \
    libepoxy0 \
    libgbm1 \
    libgdk-pixbuf-2.0-0 \
    libglib2.0-0t64 \
    libglib2.0-bin \
    libgtk-3-0 \
    libharfbuzz0b \
    libjavascriptcoregtk-4.1-0 \
    libkeybinder-3.0-0 \
    libnss3 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libsecret-1-0 \
    libsoup-3.0-0 \
    libwebkit2gtk-4.1-0 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    iptables \
    nginx-light \
    nftables \
    novnc \
    python3-websockify \
    tzdata \
    x11vnc \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --home-dir /home/scclient --shell /bin/bash --uid 10001 scclient \
    && mkdir -p /opt/scclient /data \
    && chown -R scclient:scclient /opt/scclient /data

COPY --from=source --chown=scclient:scclient /opt/scclient/ /opt/scclient/
COPY --chown=scclient:scclient entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

USER scclient
WORKDIR /opt/scclient

ENV HOME=/data/home
ENV TZ=Asia/Shanghai
ENV MODE=gui
ENV ENABLE_VNC=1
ENV ENABLE_NOVNC=1
ENV ENABLE_FILE_LOGS=0
ENV LOG_DIR=/data/logs
ENV FILE_LOG_MAX_BYTES=10485760
ENV FILE_LOG_MAX_FILES=3
ENV VNC_PORT=5900
ENV NOVNC_PORT=6080
ENV XVFB_WHD=1280x800x24
ENV CONFIG_DIR=/data/config
ENV CONFIG_FILE=/data/config/config.yaml

VOLUME ["/data"]

EXPOSE 6080 6454 19227 1053/tcp 1053/udp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
