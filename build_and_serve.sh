#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
python3.11 -m venv .venv || python3 -m venv .venv
. .venv/bin/activate
pip install -r backend/requirements.txt
[ -f backend/.env ] || cp backend/.env.example backend/.env
(cd frontend && npm install && npm run build)
cd backend
uvicorn app.main:app --host 0.0.0.0 --port 8000
