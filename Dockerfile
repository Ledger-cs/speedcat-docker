FROM docker.m.daocloud.io/library/ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
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
    nftables \
    novnc \
    procps \
    python3-websockify \
    tzdata \
    x11vnc \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --home-dir /home/scclient --shell /bin/bash --uid 10001 scclient \
    && mkdir -p /opt/scclient /data \
    && chown -R scclient:scclient /opt/scclient /data

COPY scclient_1.33.12_linux_universal_amd64.tar.gz /tmp/scclient.tar.gz

RUN tar -xzf /tmp/scclient.tar.gz -C /tmp \
    && cp -a /tmp/bundle/. /opt/scclient/ \
    && rm -rf /tmp/bundle /tmp/scclient.tar.gz \
    && chown -R scclient:scclient /opt/scclient

COPY --chown=scclient:scclient entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

USER scclient
WORKDIR /opt/scclient

ENV HOME=/data/home
ENV TZ=Asia/Shanghai
ENV MODE=gui
ENV ENABLE_VNC=1
ENV ENABLE_NOVNC=1
ENV VNC_PORT=5900
ENV NOVNC_PORT=6080
ENV XVFB_WHD=1280x800x24
ENV CONFIG_DIR=/data/config
ENV CONFIG_FILE=/data/config/config.yaml

VOLUME ["/data"]

EXPOSE 5900 6080 7890 7891 9090

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
