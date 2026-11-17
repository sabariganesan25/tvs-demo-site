from fastapi import APIRouter,Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from pathlib import Path
router=APIRouter();templates=Jinja2Templates(directory=str(Path(__file__).parents[1]/'templates'))
@router.get('/login',response_class=HTMLResponse)
async def login(request:Request):return templates.TemplateResponse('login.html',{'request':request})
