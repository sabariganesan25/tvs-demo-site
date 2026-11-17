import asyncio,random,uuid
from datetime import datetime,timedelta
from fastapi.responses import JSONResponse,HTMLResponse
from ..config import TZ,MAX_FAULT_SECONDS
from ..logging_utils import now,fault_event
from ..modules import MODULES
from .store import read,update
def target_for(path):
 if path=='/health':return'health'
 if path=='/login':return'dealer-signin'
 for m in MODULES:
  if path.startswith(m['path']):return m['id']
def evt(name,f,reason=None):
 x={'event':name,'fault_id':f['fault_id'],'type':f['type'],'target':f['target'],'params':f.get('params',{}),'timestamp':now()}
 if reason:x['reason']=reason
 fault_event(x)
def active(path):
 expired=[]
 def clean(rows):
  keep=[];t=datetime.now(TZ)
  for f in rows:
   if datetime.fromisoformat(f['expires_at'])<=t:expired.append(f)
   else:keep.append(f)
  for f in expired:evt('fault_expired',f)
  return keep
 rows=update(clean);target=target_for(path);matches=[f for f in rows if f['target']==target or(f['target']=='all'and(target!='health'or f['type']=='outage'))]
 return next((f for f in matches if f['target']==target),matches[0]if matches else None)
def create(d):
 sec=min(max(1,int(d.get('duration_seconds')or 3600)),MAX_FAULT_SECONDS);f={'fault_id':uuid.uuid4().hex[:10],'type':d['type'],'target':d['target'],'params':d.get('params',{}),'probability':float(d.get('probability',1)),'started_at':now(),'expires_at':(datetime.now(TZ)+timedelta(seconds=sec)).isoformat(),'remaining_count':int(d.get('count',1)),'created_by':'admin','note':d.get('note','')}
 def put(rows):
  keep=[]
  for old in rows:
   if old['target']==f['target']:evt('fault_end',old,'replaced')
   else:keep.append(old)
  return keep+[f]
 update(put);evt('fault_start',f);return f
def end(target,reason):
 def remove(rows):
  keep=[]
  for f in rows:
   if target=='all'or f['target']==target:evt('fault_end',f,reason)
   else:keep.append(f)
  return keep
 return update(remove)
async def effect(f,path,threshold):
 if random.random()>f['probability']:return None
 k,p=f['type'],f.get('params',{})
 if k=='slow_fixed':await asyncio.sleep(int(p.get('delay_ms',4000))/1000);return None
 if k=='slow_chronic':
  a,b=(1.15,1.5)if p.get('severity')=='marginal'else(1.6,2.5);await asyncio.sleep(threshold*random.uniform(a,b)/1000);return None
 if k=='gateway_timeout_504':await asyncio.sleep(int(p.get('upstream_delay_ms',10000))/1000);return JSONResponse({'error':'Gateway Timeout'},504)
 if k=='hang':await asyncio.sleep(int(p.get('hang_seconds',35)));return None
 if k=='wrong_content':
  if path=='/login':return HTMLResponse('<!doctype html><h1>Maintenance</h1>')
  return JSONResponse({'results':[],'count':0}if p.get('mode')=='empty'else{'status':'maintenance','message':'Service is being updated'})
 if k=='blip':
  fired=[]
  def consume(rows):
   keep=[]
   for old in rows:
    if old['fault_id']!=f['fault_id']:keep.append(old);continue
    old['remaining_count']-=1;fired.append(1)
    if old['remaining_count']>0:keep.append(old)
    else:evt('fault_end',old,'count_exhausted')
   return keep
  update(consume);return JSONResponse({'error':'Internal Server Error'},500)if fired else None
 from .responses import fault_response
 return fault_response(k,path)
