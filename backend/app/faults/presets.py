PRESETS=[
{'name':'chronic_slow_marginal','description':'Intermittent booking threshold breaches','target':'booking-claims','type':'slow_chronic','params':{'severity':'marginal','probability':.35},'duration_seconds':5400,'expected_finding':'Service stays up but threshold breaches rise.'},
{'name':'chronic_slow_severe','description':'Severe transit slowness','target':'transit-claims','type':'slow_chronic','params':{'severity':'severe','probability':.35},'duration_seconds':3600,'expected_finding':'Frequent severe slowness.'},
{'name':'unavailable_503','description':'Hard stock outage','target':'parts-stock','type':'unavailable_503','params':{},'duration_seconds':1200,'expected_finding':'Hard unavailability.'},
{'name':'gateway_timeout_504','description':'Gateway upstream timeout','target':'apps-gateway','type':'gateway_timeout_504','params':{},'duration_seconds':600,'expected_finding':'Gateway reachable, upstream silent.'},
{'name':'bad_gateway_502','description':'Gateway upstream fast failure','target':'apps-gateway','type':'bad_gateway_502','params':{},'duration_seconds':600,'expected_finding':'Upstream fails fast.'},
{'name':'app_error_500','description':'E-invoice app error','target':'e-invoice','type':'error_500','params':{},'duration_seconds':300,'expected_finding':'Application error.'},
{'name':'hang_35s','description':'Catalogue hang','target':'parts-catalogue','type':'hang','params':{'hang_seconds':35},'duration_seconds':600,'expected_finding':'No response within 30 seconds.'},
{'name':'route_missing_404','description':'Reports route missing','target':'dealer-reports','type':'not_found_404','params':{},'duration_seconds':600,'expected_finding':'Configuration problem.'},
{'name':'forbidden_403','description':'Reports forbidden','target':'dealer-reports','type':'forbidden_403','params':{},'duration_seconds':600,'expected_finding':'Access change.'},
{'name':'wrong_content','description':'Sign-in maintenance response','target':'dealer-signin','type':'wrong_content','params':{'mode':'maintenance'},'duration_seconds':600,'expected_finding':'Keyword missing.'},
{'name':'full_outage','description':'All module outage','target':'all','type':'outage','params':{},'duration_seconds':600,'expected_finding':'One root cause.'},
{'name':'blip','description':'One catalogue error','target':'parts-catalogue','type':'blip','params':{'count':1},'duration_seconds':600,'expected_finding':'Transient only.'}]
