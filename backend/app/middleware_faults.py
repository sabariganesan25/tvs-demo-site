from starlette.middleware.base import BaseHTTPMiddleware
from .config import FAULTS_ENABLED
from .faults.engine import active,effect,target_for
from .modules import MODULES
class FaultMiddleware(BaseHTTPMiddleware):
 async def dispatch(self,request,call_next):
  path=request.url.path
  if not FAULTS_ENABLED or path.startswith('/admin')or path in('/api/modules','/docs','/openapi.json')or not(path.startswith('/api')or path in('/health','/login')):return await call_next(request)
  f=active(path)
  if not f:return await call_next(request)
  request.state.fault_id=f['fault_id'];request.state.fault_type=f['type']
  m=next((x for x in MODULES if x['id']==target_for(path)),None);r=await effect(f,path,m['threshold_ms']if m else 1000)
  return r or await call_next(request)
