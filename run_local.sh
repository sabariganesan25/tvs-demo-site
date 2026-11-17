#!/usr/bin/env bash
python3 -m venv .venv;. .venv/bin/activate;pip install -r backend/requirements.txt;[ -f backend/.env ]||cp backend/.env.example backend/.env;(cd frontend&&npm install&&npm run dev)&(cd backend&&uvicorn app.main:app --port 8000 --reload)&wait
