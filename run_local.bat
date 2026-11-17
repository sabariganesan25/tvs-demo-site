@echo off
setlocal
cd /d "%~dp0"
if not exist .venv (
  py -3.11 -m venv .venv 2>nul || py -3 -m venv .venv
)
call .venv\Scripts\activate
pip install -r backend\requirements.txt
if not exist backend\.env copy backend\.env.example backend\.env
cd frontend && call npm install
start "Portal API" cmd /k "cd /d %~dp0backend && %~dp0.venv\Scripts\uvicorn app.main:app --reload --port 8000"
start "Portal UI" cmd /k "cd /d %~dp0frontend && npm run dev"
