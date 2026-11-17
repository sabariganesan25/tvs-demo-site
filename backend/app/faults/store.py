import json,os
from pathlib import Path
from filelock import FileLock
from ..config import LOGS
STATE=LOGS/'fault_state.json';LOCK=FileLock(str(LOGS/'fault_state.lock'))
def read():
 with LOCK:
  if not STATE.exists():return []
  try:return json.loads(STATE.read_text())
  except json.JSONDecodeError:return []
def write(v):
 with LOCK:
  tmp=STATE.with_suffix('.tmp');tmp.write_text(json.dumps(v));os.replace(tmp,STATE)
def update(fn):
 with LOCK:
  try:v=json.loads(STATE.read_text())if STATE.exists()else[]
  except json.JSONDecodeError:v=[]
  out=fn(v);tmp=STATE.with_suffix('.tmp');tmp.write_text(json.dumps(out));os.replace(tmp,STATE);return out
