@echo off
setlocal
cd /d "%~dp0"
if not exist .venv (
  py -3.11 -m venv .venv 2>nul || py -3 -m venv .venv
)
call .venv\Scripts\activate
pip install -r backend\requirements.txt
if not exist backend\.env copy backend\.env.example backend\.env
call npm --prefix frontend install
call npm --prefix frontend run build
cd backend
uvicorn app.main:app --host 0.0.0.0 --port 8000
