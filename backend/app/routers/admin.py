import hmac,json
from fastapi import APIRouter,Header,HTTPException
from ..config import ADMIN_TOKEN,FAULTS_ENABLED,LOGS
from ..faults.engine import create,end
from ..faults.store import read
from ..faults.presets import PRESETS
from ..modules import MODULES
router=APIRouter(prefix='/admin/api');TYPES={'slow_chronic','slow_fixed','error_500','bad_gateway_502','unavailable_503','gateway_timeout_504','forbidden_403','not_found_404','hang','wrong_content','outage','blip'}
def auth(t):
 if not ADMIN_TOKEN or ADMIN_TOKEN=='change-me':raise HTTPException(403,'admin disabled: set ADMIN_TOKEN')
 if not t or not hmac.compare_digest(t,ADMIN_TOKEN):raise HTTPException(401,'Unauthorised')
def logs(n):
 p=LOGS/n;return[json.loads(x)for x in p.read_text().splitlines()]if p.exists()else[]
@router.post('/fault')
async def fault(b:dict,x_admin_token:str|None=Header(None)):
 auth(x_admin_token)
 if not FAULTS_ENABLED:raise HTTPException(403,'faults disabled')
 if b.get('type')not in TYPES or b.get('target')not in{x['id']for x in MODULES}|{'all','health'}:raise HTTPException(422,'Unknown type or target')
 if not 0<=float(b.get('probability',1))<=1:raise HTTPException(422,'probability must be between 0 and 1')
 return create({'type':b['type'],'target':b['target'],'duration_seconds':b.get('duration_seconds'),'probability':b.get('probability',1),'params':b,'count':b.get('count',1),'note':b.get('note','')})
@router.post('/preset')
async def preset(b:dict,x_admin_token:str|None=Header(None)):
 auth(x_admin_token);p=next((x for x in PRESETS if x['name']==b.get('preset')),None)
 if not p:raise HTTPException(422,'Unknown preset')
 return create({'type':p['type'],'target':p['target'],'duration_seconds':b.get('duration_seconds',p['duration_seconds']),'probability':p['params'].get('probability',1),'params':p['params'],'count':p['params'].get('count',1)})
@router.post('/reset')
async def reset(b:dict,x_admin_token:str|None=Header(None)):auth(x_admin_token);end(b.get('target','all'),'manual_reset');return{'status':'reset'}
@router.get('/status')
async def status(x_admin_token:str|None=Header(None)):auth(x_admin_token);return{'results':read(),'count':len(read()),'faults_enabled':FAULTS_ENABLED}
@router.get('/presets')
async def presets(x_admin_token:str|None=Header(None)):auth(x_admin_token);return{'results':PRESETS,'count':len(PRESETS)}
@router.get('/fault-log')
async def log(x_admin_token:str|None=Header(None),limit:int=100):auth(x_admin_token);r=logs('fault_log.jsonl');return{'results':r[-limit:],'count':len(r)}
@router.get('/summary')
async def summary(x_admin_token:str|None=Header(None),since:str|None=None):
 auth(x_admin_token);a=logs('access.jsonl');f=logs('fault_log.jsonl');a=[x for x in a if not since or x.get('time','')>=since];f=[x for x in f if not since or x.get('timestamp','')>=since];out={m['id']:{'total_requests':0,'affected_requests':0,'by_fault_type':{}}for m in MODULES}
 for x in a:
  m=next((z['id']for z in MODULES if x.get('path','').startswith(z['path'])),None)
  if m:
   out[m]['total_requests']+=1
   if x.get('fault_type'):out[m]['affected_requests']+=1;out[m]['by_fault_type'][x['fault_type']]=out[m]['by_fault_type'].get(x['fault_type'],0)+1
 starts={x['fault_id']:x for x in f if x.get('event')=='fault_start'};ends={x['fault_id']:x for x in f if x.get('event')in('fault_end','fault_expired')}
 return{'modules':out,'faults':[{'fault_id':k,'type':v['type'],'target':v['target'],'start':v['timestamp'],'end':ends.get(k,{}).get('timestamp')}for k,v in starts.items()]}
