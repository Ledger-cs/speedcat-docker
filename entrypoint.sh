#!/usr/bin/env bash
set -Eeuo pipefail

export HOME="${HOME:-/data/home}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-scclient}"

mkdir -p \
  "$HOME" \
  "$XDG_CONFIG_HOME" \
  "$XDG_DATA_HOME" \
  "$XDG_CACHE_HOME" \
  "$XDG_RUNTIME_DIR" \
  /data/config \
  /data/logs

chmod 700 "$XDG_RUNTIME_DIR"

MODE="${MODE:-gui}"

if [[ "$MODE" == "core" ]]; then
  if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "CONFIG_FILE does not exist: ${CONFIG_FILE}" >&2
    echo "Mount a Mihomo-compatible config to ${CONFIG_FILE} or switch MODE back to gui." >&2
    exit 1
  fi

  echo "Starting Speedcat embedded core in headless mode..."
  exec /opt/scclient/lib/ScclientCore_amd64 -d "${CONFIG_DIR}" -f "${CONFIG_FILE}"
fi

DISPLAY_NUM="${DISPLAY:-:99}"
VNC_PORT="${VNC_PORT:-5900}"
NOVNC_PORT="${NOVNC_PORT:-6080}"
NOVNC_BACKEND_PORT="${NOVNC_BACKEND_PORT:-6081}"
XVFB_WHD="${XVFB_WHD:-1280x800x24}"
UI_PASSWORD="${UI_PASSWORD:-${VNC_PASSWORD:-}}"
UI_AUTH_USERNAME="${UI_AUTH_USERNAME:-}"
UI_AUTH_PASSWORD="${UI_AUTH_PASSWORD:-}"

PIDS=()

cleanup() {
  local code=$?
  for pid in "${PIDS[@]:-}"; do
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
  done
  exit "$code"
}

trap cleanup EXIT INT TERM

if [[ -n "${UI_AUTH_USERNAME}" || -n "${UI_AUTH_PASSWORD}" ]]; then
  if [[ -z "${UI_AUTH_USERNAME}" || -z "${UI_AUTH_PASSWORD}" ]]; then
    echo "UI_AUTH_USERNAME and UI_AUTH_PASSWORD must both be set to enable HTTP Basic Auth." >&2
    exit 1
  fi
fi

echo "Starting Xvfb on ${DISPLAY_NUM}..."
Xvfb "${DISPLAY_NUM}" -screen 0 "${XVFB_WHD}" -nolisten tcp -ac +extension GLX +render -noreset \
  >/data/logs/xvfb.log 2>&1 &
PIDS+=("$!")

echo "Starting Fluxbox..."
DISPLAY="${DISPLAY_NUM}" fluxbox >/data/logs/fluxbox.log 2>&1 &
PIDS+=("$!")

if [[ "${ENABLE_VNC:-1}" == "1" || "${ENABLE_NOVNC:-1}" == "1" ]]; then
  echo "Starting x11vnc on port ${VNC_PORT}..."
  X11VNC_ARGS=(
    -display "${DISPLAY_NUM}"
    -forever
    -localhost
    -shared
    -rfbport "${VNC_PORT}"
    -quiet
  )

  if [[ -n "${UI_PASSWORD}" ]]; then
    X11VNC_ARGS+=(-passwd "${UI_PASSWORD}")
  else
    X11VNC_ARGS+=(-nopw)
  fi

  x11vnc "${X11VNC_ARGS[@]}" >/data/logs/x11vnc.log 2>&1 &
  PIDS+=("$!")
fi

if [[ "${ENABLE_NOVNC:-1}" == "1" ]]; then
  mkdir -p /tmp/nginx/client_temp /tmp/nginx/proxy_temp /tmp/nginx/fastcgi_temp /tmp/nginx/uwsgi_temp /tmp/nginx/scgi_temp

  AUTH_DIRECTIVES=""
  if [[ -n "${UI_AUTH_USERNAME}" && -n "${UI_AUTH_PASSWORD}" ]]; then
    echo "Enabling HTTP Basic Auth for noVNC UI..."
    htpasswd -bcB /tmp/nginx/.htpasswd "${UI_AUTH_USERNAME}" "${UI_AUTH_PASSWORD}" >/dev/null
    AUTH_DIRECTIVES=$'    auth_basic "Restricted";\n    auth_basic_user_file /tmp/nginx/.htpasswd;'
  fi

  cat > /tmp/nginx/nginx.conf <<EOF
worker_processes 1;
pid /tmp/nginx/nginx.pid;
error_log /data/logs/nginx-error.log warn;

events {
  worker_connections 1024;
}

http {
  include /etc/nginx/mime.types;
  default_type application/octet-stream;
  access_log /data/logs/nginx-access.log;
  sendfile on;
  client_body_temp_path /tmp/nginx/client_temp;
  proxy_temp_path /tmp/nginx/proxy_temp;
  fastcgi_temp_path /tmp/nginx/fastcgi_temp;
  uwsgi_temp_path /tmp/nginx/uwsgi_temp;
  scgi_temp_path /tmp/nginx/scgi_temp;

  map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
  }

  server {
    listen ${NOVNC_PORT};
    server_name _;

    location / {
${AUTH_DIRECTIVES}
      proxy_pass http://127.0.0.1:${NOVNC_BACKEND_PORT};
      proxy_http_version 1.1;
      proxy_set_header Host \$host;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection \$connection_upgrade;
      proxy_buffering off;
    }
  }
}
EOF
fi

if [[ "${ENABLE_NOVNC:-1}" == "1" ]]; then
  echo "Starting noVNC backend on port ${NOVNC_BACKEND_PORT}..."
  websockify --web=/usr/share/novnc/ "127.0.0.1:${NOVNC_BACKEND_PORT}" "127.0.0.1:${VNC_PORT}" \
    >/data/logs/novnc.log 2>&1 &
  PIDS+=("$!")

  echo "Starting HTTP UI gateway on port ${NOVNC_PORT}..."
  nginx -c /tmp/nginx/nginx.conf -g 'daemon off;' >/data/logs/nginx.log 2>&1 &
  PIDS+=("$!")
fi

echo "Starting Speedcat GUI client..."
dbus-run-session -- bash -lc "
  export DISPLAY='${DISPLAY_NUM}'
  export HOME='${HOME}'
  export XDG_CONFIG_HOME='${XDG_CONFIG_HOME}'
  export XDG_DATA_HOME='${XDG_DATA_HOME}'
  export XDG_CACHE_HOME='${XDG_CACHE_HOME}'
  export XDG_RUNTIME_DIR='${XDG_RUNTIME_DIR}'
  cd /opt/scclient
  ./scclient
" >/data/logs/scclient.log 2>&1 &
APP_PID=$!
PIDS+=("${APP_PID}")

wait "${APP_PID}"
