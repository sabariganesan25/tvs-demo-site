import json,logging
from datetime import datetime
from .config import TZ,LOGS
logging.basicConfig(level=logging.INFO,format='%(message)s');log=logging.getLogger('portal')
def now():return datetime.now(TZ).isoformat()
def write(x):
 line=json.dumps(x,separators=(',',':'));log.info(line)
 with(LOGS/'access.jsonl').open('a',encoding='utf8')as f:f.write(line+'\n')
def fault_event(x):
 line=json.dumps(x,separators=(',',':'));log.warning('FAULT_EVENT '+line)
 with(LOGS/'fault_log.jsonl').open('a',encoding='utf8')as f:f.write(line+'\n')
