#!/bin/bash
# Azure App Service startup — Dealer Operations Portal
# This runs inside the Linux container at /home/site/wwwroot

set -e
cd /home/site/wwwroot

echo "=== Dealer Portal Startup ==="
echo "Directory: $(pwd)"
echo "Python: $(python3 --version 2>&1)"

VENV=/home/site/venv

# Install / refresh venv (only if packages missing or first boot)
if [ ! -f "$VENV/bin/gunicorn" ]; then
  echo "=== Creating virtualenv and installing packages ==="
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet --no-cache-dir \
    "fastapi==0.115.6" \
    "uvicorn[standard]==0.34.0" \
    "gunicorn==23.0.0" \
    "jinja2==3.1.5" \
    "pydantic==2.10.4" \
    "filelock==3.16.1" \
    "tzdata==2025.1"
  echo "=== Package install done ==="
else
  echo "=== Virtualenv already exists, skipping install ==="
fi

PORT="${PORT:-8000}"
echo "=== Starting gunicorn on port $PORT ==="

exec "$VENV/bin/gunicorn" \
  -w 2 \
  -k uvicorn.workers.UvicornWorker \
  backend.app.main:app \
  --bind "0.0.0.0:$PORT" \
  --timeout 120 \
  --access-logfile - \
  --error-logfile -
