import time
from pathlib import Path
from fastapi import FastAPI,Request,HTTPException
from fastapi.responses import JSONResponse,FileResponse
from fastapi.staticfiles import StaticFiles
from .logging_utils import now,write
from .config import ROOT
from .routers.api import router as api_router
from .routers.pages import router as pages_router
from .routers.admin import router as admin_router
from .middleware_faults import FaultMiddleware
app=FastAPI(title='Dealer Operations Portal',version='1.0')
# MIDDLEWARE REGISTRATION POINT: add future observability/fault middleware here.
app.add_middleware(FaultMiddleware)
@app.middleware('http')
async def access_log(request:Request,call_next):
 start=time.perf_counter();response=await call_next(request)
 if request.url.path.startswith('/admin'):response.headers['X-Robots-Tag']='noindex'
 record={'time':now(),'method':request.method,'path':request.url.path,'status':response.status_code,'duration_ms':round((time.perf_counter()-start)*1000,1)}
 if hasattr(request.state,'fault_id'):record.update({'fault_id':request.state.fault_id,'fault_type':request.state.fault_type})
 write(record);return response
@app.exception_handler(HTTPException)
async def http_error(request:Request,exc:HTTPException):return JSONResponse({'error':str(exc.detail),'status':exc.status_code}if request.url.path.startswith('/api')else{'detail':exc.detail},exc.status_code)
@app.exception_handler(Exception)
async def server_error(request:Request,exc:Exception):return JSONResponse({'error':'Service request failed','status':500}if request.url.path.startswith('/api')else{'detail':'Server error'},500)
@app.get('/health')
async def health():return {'status':'ok','service':'dealer-portal','time':now(),'version':'1.0'}
app.include_router(api_router);app.include_router(pages_router);app.include_router(admin_router)
DIST=ROOT/'frontend'/'dist'
if(DIST/'assets').exists():app.mount('/assets',StaticFiles(directory=DIST/'assets'),name='assets')
@app.get('/{path:path}',include_in_schema=False)
async def spa(path:str):
 if path.startswith('api/') or path.startswith('admin/api/'):
  return JSONResponse({'error':'Not found'},404)
 c=DIST/path
 if path and c.is_file():return FileResponse(c)
 if(DIST/'index.html').exists():return FileResponse(DIST/'index.html')
 return JSONResponse({'detail':'Frontend build not found'},503)
