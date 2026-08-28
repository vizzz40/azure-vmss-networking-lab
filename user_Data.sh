#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y python3-venv

install -d -o azureuser -g azureuser /opt/backend-api
python3 -m venv /opt/backend-api/venv
/opt/backend-api/venv/bin/pip install --no-cache-dir fastapi uvicorn

cat <<'PYTHON' > /opt/backend-api/main.py
from fastapi import FastAPI
import socket

app = FastAPI()


@app.get("/")
def read_root():
    return {
        "status": "ok",
        "message": "Azure VMSS networking lab",
        "server_instance": socket.gethostname(),
    }
PYTHON

chown -R azureuser:azureuser /opt/backend-api

cat <<'SERVICE' > /etc/systemd/system/backend-api.service
[Unit]
Description=FastAPI VMSS demo service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=azureuser
Group=azureuser
WorkingDirectory=/opt/backend-api
ExecStart=/opt/backend-api/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable --now backend-api.service
