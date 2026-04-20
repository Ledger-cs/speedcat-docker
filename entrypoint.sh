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
XVFB_WHD="${XVFB_WHD:-1280x800x24}"
UI_PASSWORD="${UI_PASSWORD:-${VNC_PASSWORD:-}}"

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
  echo "Starting noVNC on port ${NOVNC_PORT}..."
  websockify --web=/usr/share/novnc/ "${NOVNC_PORT}" "127.0.0.1:${VNC_PORT}" \
    >/data/logs/novnc.log 2>&1 &
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
