import os
from pathlib import Path
from zoneinfo import ZoneInfo
ROOT=Path(__file__).resolve().parents[2]
for p in(ROOT/'backend'/'.env',ROOT/'.env'):
 if p.exists():
  for l in p.read_text().splitlines():
   if '=' in l and not l.startswith('#'):k,v=l.split('=',1);os.environ.setdefault(k.strip(),v.strip())
PORT=int(os.getenv('PORT','8000'));TZ=ZoneInfo(os.getenv('TIMEZONE','Asia/Kolkata'));LOGS=Path(os.getenv('FAULT_DATA_DIR',str(ROOT/'logs'))).resolve();LOGS.mkdir(parents=True,exist_ok=True);ADMIN_TOKEN=os.getenv('ADMIN_TOKEN','change-me');FAULTS_ENABLED=os.getenv('FAULTS_ENABLED','true').lower()=='true';MAX_FAULT_SECONDS=int(os.getenv('MAX_FAULT_SECONDS','7200'))
