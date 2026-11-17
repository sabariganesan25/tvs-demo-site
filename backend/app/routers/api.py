import asyncio,random
from fastapi import APIRouter,HTTPException
from pydantic import BaseModel,Field
from ..modules import MODULES,module
from ..data import booking_claims,transit_claims,stock,catalogue,invoices,reports,orders,dealers
router=APIRouter(prefix='/api')
async def wait(key):
 m=module(key);await asyncio.sleep(random.randint(m['baseline_ms_min'],m['baseline_ms_max'])/1000)
@router.get('/modules')
async def modules():return {'results':MODULES,'count':len(MODULES)}
@router.get('/dashboard/summary')
async def dashboard():
 await asyncio.sleep(.08);return {'results':{'kpis':[{'label':'Open claims','value':18,'icon':'claims','trend':'5 need review'},{'label':'Claims in transit','value':11,'icon':'transit','trend':'3 arriving today'},{'label':'Low stock items','value':3,'icon':'stock','trend':'Review required'},{'label':'Pending invoices','value':4,'icon':'invoice','trend':'₹28,400 outstanding'},{'label':'Orders today','value':16,'icon':'gateway','trend':'+12% this week'},{'label':'Reports generated','value':12,'icon':'reports','trend':'Current month ready'}],'chart':[{'label':'Submitted','value':12},{'label':'Under review','value':8},{'label':'Approved','value':19},{'label':'Rejected','value':3}],'activity':[{'title':'Booking claim CLM-2026-0008 approved','time':'12 minutes ago'},{'title':'Coimbatore Central stock updated','time':'34 minutes ago'},{'title':'Invoice INV-2026-0004 received','time':'1 hour ago'}],'modules':[{'name':m['name'],'status':'Operational'}for m in MODULES]},'count':1}
@router.get('/claims/bookings')
async def claims(q:str='',status:str=''):
 await wait('booking-claims');r=[x for x in booking_claims if q.lower()in str(x).lower()and(not status or x['status']==status)];return {'results':r,'count':len(r)}
@router.get('/claims/transit')
async def transit():await wait('transit-claims');return {'results':transit_claims,'count':len(transit_claims)}
@router.get('/stock')
async def getstock():await wait('parts-stock');return {'results':stock,'count':len(stock)}
@router.get('/stock/{part_id}')
async def getpart(part_id:int):
 await wait('parts-stock');x=next((x for x in stock if x['id']==part_id),None)
 if not x:raise HTTPException(404,'Stock item not found')
 return {**x,'available_qty':x['available_qty'],'movement':[{'date':'2026-10-20','type':'Goods receipt','quantity':12},{'date':'2026-10-28','type':'Dealer allocation','quantity':-4}]}
@router.get('/catalogue')
async def cat(q:str='',category:str='',sort:str=''):
 await wait('parts-catalogue');r=[x for x in catalogue if q.lower()in x['name'].lower()and(not category or x['category']==category)];
 if sort:r.sort(key=lambda x:x['price'],reverse=sort=='price-desc')
 return {'results':r,'count':len(r)}
@router.get('/einvoice')
async def invs():await wait('e-invoice');return {'results':invoices,'count':len(invoices)}
@router.get('/einvoice/{id}')
async def inv(id:int):
 await wait('e-invoice');x=next((x for x in invoices if x['id']==id),None)
 if not x:raise HTTPException(404,'Invoice not found')
 return x
@router.get('/reports/monthly')
async def monthly(month:str=''):
 await wait('dealer-reports');r=[x for x in reports if not month or x['month']==month];return {'results':r,'count':len(r),'report_id':r[0]['report_id']if r else''}
@router.get('/gateway/orders')
async def getorders():await wait('apps-gateway');return {'results':orders,'count':len(orders)}
class Order(BaseModel):dealer:str=Field(min_length=3);part:str=Field(min_length=3);quantity:int=Field(gt=0,le=100)
@router.post('/gateway/orders',status_code=201)
async def order(o:Order):
 await wait('apps-gateway');item={'order_id':f'ORD-{50001+len(orders)}',**o.model_dump(),'status':'Received','created_at':'2026-11-12T10:00:00+05:30'};orders.insert(0,item);return {'order_id':item['order_id'],'status':'received'}
