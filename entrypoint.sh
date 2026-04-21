#!/usr/bin/env bash
set -Eeuo pipefail

export HOME="${HOME:-/data/home}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-scclient}"

MODE="${MODE:-gui}"
ENABLE_FILE_LOGS="${ENABLE_FILE_LOGS:-0}"
LOG_DIR="${LOG_DIR:-/data/logs}"
FILE_LOG_MAX_BYTES="${FILE_LOG_MAX_BYTES:-10485760}"
FILE_LOG_MAX_FILES="${FILE_LOG_MAX_FILES:-3}"

mkdir -p \
  "$HOME" \
  "$XDG_CONFIG_HOME" \
  "$XDG_DATA_HOME" \
  "$XDG_CACHE_HOME" \
  "$XDG_RUNTIME_DIR" \
  /data/config

chmod 700 "$XDG_RUNTIME_DIR"

log_target() {
  local name="$1"

  if [[ "$ENABLE_FILE_LOGS" == "1" ]]; then
    echo "${LOG_DIR}/${name}.log"
  else
    echo "/proc/1/fd/1"
  fi
}

rotate_log_file() {
  local file="$1"
  local size
  local limit="$FILE_LOG_MAX_BYTES"
  local keep="$FILE_LOG_MAX_FILES"
  local i

  if [[ ! -f "$file" || ! "$limit" =~ ^[0-9]+$ || ! "$keep" =~ ^[0-9]+$ || "$keep" -lt 1 ]]; then
    return 0
  fi

  size=$(wc -c < "$file")
  if [[ "$size" -lt "$limit" ]]; then
    return 0
  fi

  rm -f "${file}.${keep}"
  for ((i = keep - 1; i >= 1; i--)); do
    if [[ -f "${file}.${i}" ]]; then
      mv "${file}.${i}" "${file}.$((i + 1))"
    fi
  done
  mv "$file" "${file}.1"
}

prepare_file_logs() {
  local names=(fluxbox nginx-access nginx-error nginx novnc scclient x11vnc xvfb)
  local name
  local file

  if [[ "$ENABLE_FILE_LOGS" != "1" ]]; then
    return 0
  fi

  mkdir -p "$LOG_DIR"
  for name in "${names[@]}"; do
    file="${LOG_DIR}/${name}.log"
    rotate_log_file "$file"
    touch "$file"
  done
}

if [[ "$MODE" == "core" ]]; then
  if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "CONFIG_FILE does not exist: ${CONFIG_FILE}" >&2
    echo "Mount a Mihomo-compatible config to ${CONFIG_FILE} or switch MODE back to gui." >&2
    exit 1
  fi

  echo "Starting Speedcat embedded core in headless mode..."
  exec /opt/scclient/lib/ScclientCore_amd64 -d "${CONFIG_DIR}" -f "${CONFIG_FILE}"
fi

prepare_file_logs

DISPLAY_NUM="${DISPLAY:-:99}"
VNC_PORT="${VNC_PORT:-5900}"
NOVNC_PORT="${NOVNC_PORT:-6080}"
NOVNC_BACKEND_PORT="${NOVNC_BACKEND_PORT:-6081}"
XVFB_WHD="${XVFB_WHD:-1280x800x24}"
UI_PASSWORD="${UI_PASSWORD:-${VNC_PASSWORD:-}}"
UI_AUTH_USERNAME="${UI_AUTH_USERNAME:-}"
UI_AUTH_PASSWORD="${UI_AUTH_PASSWORD:-}"
UI_RATE_LIMIT_RPS="${UI_RATE_LIMIT_RPS:-5}"
UI_RATE_LIMIT_BURST="${UI_RATE_LIMIT_BURST:-20}"
UI_RATE_LIMIT_CONN="${UI_RATE_LIMIT_CONN:-10}"

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
  >"$(log_target xvfb)" 2>&1 &
PIDS+=("$!")

echo "Starting Fluxbox..."
DISPLAY="${DISPLAY_NUM}" fluxbox >"$(log_target fluxbox)" 2>&1 &
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

  x11vnc "${X11VNC_ARGS[@]}" >"$(log_target x11vnc)" 2>&1 &
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
error_log $(log_target nginx-error) warn;

events {
  worker_connections 1024;
}

http {
  include /etc/nginx/mime.types;
  default_type application/octet-stream;
  access_log $(log_target nginx-access);
  sendfile on;
  limit_req_zone \$binary_remote_addr zone=ui_req_limit:10m rate=${UI_RATE_LIMIT_RPS}r/s;
  limit_conn_zone \$binary_remote_addr zone=ui_conn_limit:10m;
  limit_req_status 429;
  limit_conn_status 429;
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
      limit_req zone=ui_req_limit burst=${UI_RATE_LIMIT_BURST} nodelay;
      limit_conn ui_conn_limit ${UI_RATE_LIMIT_CONN};
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
    >"$(log_target novnc)" 2>&1 &
  PIDS+=("$!")

  echo "Starting HTTP UI gateway on port ${NOVNC_PORT}..."
  nginx -c /tmp/nginx/nginx.conf -g 'daemon off;' >"$(log_target nginx)" 2>&1 &
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
" >"$(log_target scclient)" 2>&1 &
APP_PID=$!
PIDS+=("${APP_PID}")

wait "${APP_PID}"
