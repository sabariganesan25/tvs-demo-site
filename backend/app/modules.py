MODULES=[
 {'id':'booking-claims','name':'Booking Claims','path':'/api/claims/bookings','threshold_ms':500,'keyword':'claim_id','baseline_ms_min':40,'baseline_ms_max':120},
 {'id':'transit-claims','name':'In-Transit Claims','path':'/api/claims/transit','threshold_ms':1500,'keyword':'consignment','baseline_ms_min':45,'baseline_ms_max':150},
 {'id':'parts-stock','name':'Parts Stock','path':'/api/stock','threshold_ms':1000,'keyword':'available_qty','baseline_ms_min':40,'baseline_ms_max':130},
 {'id':'e-invoice','name':'E-Invoice','path':'/api/einvoice','threshold_ms':1800,'keyword':'invoice_no','baseline_ms_min':50,'baseline_ms_max':170},
 {'id':'dealer-signin','name':'Dealer Sign-in','path':'/login','threshold_ms':1000,'keyword':'Sign in with SSO','baseline_ms_min':40,'baseline_ms_max':100},
 {'id':'dealer-reports','name':'Dealer Reports','path':'/api/reports/monthly','threshold_ms':3000,'keyword':'report_id','baseline_ms_min':100,'baseline_ms_max':400},
 {'id':'parts-catalogue','name':'Parts E-Catalogue','path':'/api/catalogue','threshold_ms':1000,'keyword':'results','baseline_ms_min':40,'baseline_ms_max':150},
 {'id':'apps-gateway','name':'Dealer Apps Gateway','path':'/api/gateway/orders','threshold_ms':1500,'keyword':'order_id','baseline_ms_min':45,'baseline_ms_max':150}]
def module(id):return next(x for x in MODULES if x['id']==id)
