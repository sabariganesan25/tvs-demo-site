from fastapi.responses import JSONResponse,HTMLResponse
def fault_response(kind,path):
 code={'error_500':500,'bad_gateway_502':502,'unavailable_503':503,'gateway_timeout_504':504,'forbidden_403':403,'not_found_404':404,'outage':503,'blip':500}[kind];msg={500:'Internal Server Error',502:'Bad Gateway',503:'Service Unavailable',504:'Gateway Timeout',403:'Forbidden',404:'Request URI does not exist'}[code]
 if path=='/login':return HTMLResponse(f'<!doctype html><title>{code}</title><main><h1>Dealer Operations Portal</h1><p>{code} {msg}</p></main>',code)
 return JSONResponse({'error':msg},code)
