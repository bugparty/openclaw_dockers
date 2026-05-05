#!/bin/bash
set -euo pipefail

export HOME=/home/appuser
export XDG_RUNTIME_DIR=/tmp/xdg-runtime-dir
export WAYLAND_DISPLAY=wayland-0
export DISPLAY=:0
WESTON_CONFIG_DIR="${HOME}/.config/weston"
WESTON_CERT="${WESTON_CONFIG_DIR}/rdp.crt"
WESTON_KEY="${WESTON_CONFIG_DIR}/rdp.key"

mkdir -p "${XDG_RUNTIME_DIR}" "${WESTON_CONFIG_DIR}" /tmp/.X11-unix
chmod 700 "${XDG_RUNTIME_DIR}"
chmod 1777 /tmp/.X11-unix

# Start DBus session bus for desktop integration hooks used by Chromium-based browsers.
if command -v dbus-launch >/dev/null 2>&1; then
  eval "$(dbus-launch --sh-syntax)"
  export DBUS_SESSION_BUS_ADDRESS
  export DBUS_SESSION_BUS_PID
  export DBUS_SYSTEM_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS}"
  echo "Started DBus session bus: ${DBUS_SESSION_BUS_ADDRESS}"
fi

if [ ! -f "${WESTON_CERT}" ] || [ ! -f "${WESTON_KEY}" ]; then
  openssl req -x509 -newkey rsa:2048 -nodes -sha256 \
    -keyout "${WESTON_KEY}" \
    -out "${WESTON_CERT}" \
    -days 3650 \
    -subj "/CN=browser-rdp" >/dev/null 2>&1
fi

cat > /tmp/browser-launch.sh <<EOF
#!/bin/bash
set -euo pipefail
# Clean stale Chromium profile locks left by previous pod hostname/PID.
rm -f /home/appuser/chrome-data/SingletonLock \
      /home/appuser/chrome-data/SingletonSocket \
      /home/appuser/chrome-data/SingletonCookie \
      /home/appuser/chrome-data/DevToolsActivePort || true
exec $(printf '%q ' "$@")
EOF
chmod +x /tmp/browser-launch.sh

cat > /tmp/weston.ini <<'EOF'
[core]
xwayland=true
idle-time=0

[autolaunch]
path=/tmp/browser-launch.sh
watch=true
EOF

weston \
  --backend=rdp-backend.so \
  --xwayland \
  --socket="${WAYLAND_DISPLAY}" \
  --config=/tmp/weston.ini \
  --width=1920 \
  --height=1080 \
  --rdp-tls-cert="${WESTON_CERT}" \
  --rdp-tls-key="${WESTON_KEY}" \
  --log=/tmp/weston.log &
WESTON_PID=$!

echo "Waiting for browser debugging interface..."
for _ in $(seq 1 60); do
  if curl -fsS http://127.0.0.1:9222/json/version >/dev/null 2>&1; then
    echo "Browser debugging interface is ready"
    break
  fi
  sleep 1
done

cat > /tmp/nginx-cdp.conf <<'EOF'
daemon off;
worker_processes 1;
pid /tmp/nginx.pid;
error_log /tmp/nginx-error.log;
events { worker_connections 1024; }
http {
    access_log /tmp/nginx-access.log;
    client_body_temp_path /tmp/nginx-client-body;
    proxy_temp_path /tmp/nginx-proxy;
    fastcgi_temp_path /tmp/nginx-fastcgi;
    uwsgi_temp_path /tmp/nginx-uwsgi;
    scgi_temp_path /tmp/nginx-scgi;
    server {
        listen 9223;
        location / {
            proxy_pass http://127.0.0.1:9222;
            proxy_http_version 1.1;
            proxy_set_header Host localhost:9222;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_read_timeout 86400;
        }
    }
}
EOF

nginx -c /tmp/nginx-cdp.conf &
echo "nginx reverse proxy forwarding CDP port 9222 to 9223"

wait "${WESTON_PID}"
