#!/usr/bin/env bash
set -euo pipefail

OPTIONS_FILE="/data/options.json"

is_writable_dir() {
  local d="$1"
  mkdir -p "$d" 2>/dev/null || return 1
  local t="$d/.rwtest.$$"
  touch "$t" 2>/dev/null || return 1
  rm -f "$t" 2>/dev/null || true
  return 0
}

pick_data_dir() {
  for d in "/share/openwa-data" "/tmp/openwa-data"; do
    if is_writable_dir "$d"; then
      echo "$d"
      return 0
    fi
  done
  return 1
}

OPENWA_DATA_DIR="$(pick_data_dir)" || {
  echo "[OpenWA Add-on] ERROR: no writable data directory found."
  exit 1
}

mkdir -p "${OPENWA_DATA_DIR}/sessions" "${OPENWA_DATA_DIR}/media" "${OPENWA_DATA_DIR}/plugins"

read_option() {
  local key="$1"
  local default_value="$2"
  python3 - "$OPTIONS_FILE" "$key" "$default_value" <<'PY'
import json, sys
path, key, default_value = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    print(default_value)
    raise SystemExit(0)
value = data.get(key, default_value)
if value is None:
    value = default_value
print(value)
PY
}

API_MASTER_KEY="$(read_option api_master_key "")"
LOG_LEVEL="$(read_option log_level "info")"
OPENWA_API_KEY="$(read_option openwa_api_key "")"
SESSION_ID="$(read_option session_id "")"

if [ -n "${OPENWA_API_KEY}" ] && [ -z "${API_MASTER_KEY}" ]; then
  API_MASTER_KEY="${OPENWA_API_KEY}"
fi

export NODE_ENV=production
export PORT=2785
export LOG_LEVEL="${LOG_LEVEL}"
export DATABASE_TYPE=sqlite
export DATABASE_NAME="${OPENWA_DATA_DIR}/openwa.sqlite"
export DATABASE_SYNCHRONIZE=false
export ENGINE_TYPE=whatsapp-web.js
export SESSION_DATA_PATH="${OPENWA_DATA_DIR}/sessions"
export PUPPETEER_HEADLESS=true
export PUPPETEER_ARGS="--no-sandbox,--disable-setuid-sandbox,--disable-dev-shm-usage,--disable-gpu"
export STORAGE_TYPE=local
export STORAGE_LOCAL_PATH="${OPENWA_DATA_DIR}/media"
export REDIS_ENABLED=false
export WEBHOOK_TIMEOUT=10000
export WEBHOOK_MAX_RETRIES=3
export WEBHOOK_RETRY_DELAY=5000
export RATE_LIMIT_TTL=60
export RATE_LIMIT_MAX=100
export PLUGINS_ENABLED=true
export PLUGINS_DIR="${OPENWA_DATA_DIR}/plugins"
export API_MASTER_KEY="${API_MASTER_KEY}"
export API_KEY="${OPENWA_API_KEY:-${API_MASTER_KEY:-}}"

if [ -n "$OPENWA_API_KEY" ]; then
  printf "%s" "$OPENWA_API_KEY" > "${OPENWA_DATA_DIR}/.api-key"
  chmod 600 "${OPENWA_DATA_DIR}/.api-key"
fi

echo "[OpenWA Add-on] Using data dir: ${OPENWA_DATA_DIR}"

mkdir -p /app/data 2>/dev/null || true

cleanup() {
  if [ -n "${HELPER_PID:-}" ]; then
    kill "${HELPER_PID}" 2>/dev/null || true
  fi
  if [ -n "${OPENWA_PID:-}" ]; then
    kill "${OPENWA_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

cd /app 2>/dev/null || true
if [ -f "/app/dist/main.js" ]; then
  node /app/dist/main.js &
  OPENWA_PID="$!"
elif [ -f "/app/dist/src/main.js" ]; then
  node /app/dist/src/main.js &
  OPENWA_PID="$!"
elif [ -f "dist/main.js" ]; then
  node dist/main.js &
  OPENWA_PID="$!"
elif [ -f "dist/src/main.js" ]; then
  node dist/src/main.js &
  OPENWA_PID="$!"
else
  npm run start:prod &
  OPENWA_PID="$!"
fi

for _ in $(seq 1 45); do
  if curl -fsS "http://127.0.0.1:2785/api/health" >/dev/null 2>&1; then
    echo "[OpenWA Add-on] OpenWA API is healthy."
    break
  fi
  sleep 2
done

python3 /usr/local/bin/helper_server.py &
HELPER_PID="$!"

wait -n "${OPENWA_PID}" "${HELPER_PID}"
