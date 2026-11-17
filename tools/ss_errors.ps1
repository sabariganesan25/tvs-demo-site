param(
  [string]$Base = "http://localhost:8000",
  [Parameter(Mandatory=$true)][string]$Token,
  [int]$Minutes = 20
)
. "$PSScriptRoot\common.ps1"
$secs = $Minutes * 60

$steps = @(
  @{ n="00_healthy_BEFORE"; title="Healthy site (before any error)"; real="Normal operation"; fault=$null;
     probe="/api/stock"; pages=@("/stock");
     see="Parts Stock shows data. Network: /api/stock is 200 with a small time." },

  @{ n="01_slow_response"; title="ERROR 1: Response time exceeded (4 seconds)"; real="Response time exceeded 500 ms";
     fault=@{ type="slow_fixed"; target="booking-claims"; delay_ms=4000 }; probe="/api/claims/bookings";
     pages=@("/claims/bookings");
     see="Page spins about 4 seconds, then loads. Take the screenshot AFTER it loads. Network time for /api/claims/bookings is about 4 s." },

  @{ n="02_503_service_unavailable"; title="ERROR 2: 503 Service Unavailable"; real="Service Unavailable (HTTP 503)";
     fault=@{ type="unavailable_503"; target="parts-stock" }; probe="/api/stock";
     pages=@("/stock");
     see="Error card on the page with 503 and a Retry button. Sidebar and top bar still work." },

  @{ n="03_500_internal_error"; title="ERROR 3: 500 Internal Server Error"; real="Internal Server Error";
     fault=@{ type="error_500"; target="e-invoice" }; probe="/api/einvoice";
     pages=@("/einvoice");
     see="E-Invoice page shows the error card with 500." },

  @{ n="04_502_bad_gateway"; title="ERROR 4: 502 Bad Gateway"; real="Bad Gateway";
     fault=@{ type="bad_gateway_502"; target="apps-gateway" }; probe="/api/gateway/orders";
     pages=@("/gateway");
     see="Gateway page shows the error card with 502, instantly." },

  @{ n="05_504_gateway_timeout"; title="ERROR 5: 504 Gateway Timeout"; real="Gateway Timeout";
     fault=@{ type="gateway_timeout_504"; target="apps-gateway"; upstream_delay_ms=4000 }; probe="/api/gateway/orders";
     pages=@("/gateway");
     see="Page waits about 4 seconds, then shows the error card with 504. Network time is about 4 s." },

  @{ n="06_no_response_30s"; title="ERROR 6: No response (35 seconds)"; real="Response not received within 30 seconds";
     fault=@{ type="hang"; target="parts-catalogue"; hang_seconds=35 }; probe=$null;
     pages=@("/catalogue");
     see="Loading skeleton for 10 seconds, then the error card says timeout. WAIT the full 10 seconds before the screenshot. The Network request stays pending or cancelled." },

  @{ n="07_404_not_found"; title="ERROR 7: 404 Request URI does not exist"; real="Request URI does not exist";
     fault=@{ type="not_found_404"; target="dealer-reports" }; probe="/api/reports/monthly";
     pages=@("/reports");
     see="Reports page shows the error card with 404." },

  @{ n="08_sso_text_missing"; title="ERROR 8: 'Sign in with SSO' text missing"; real="'sso login' string not found in response";
     fault=@{ type="wrong_content"; target="dealer-signin"; mode="maintenance" }; probe="/login"; kw="Sign in with SSO";
     pages=@("/login");
     see="A maintenance page loads with status 200. Screenshot 1: the page. Then press Ctrl+U and take Screenshot 2 of the page source, which has no 'Sign in with SSO'." },

  @{ n="09_bonus_403_forbidden"; title="BONUS: 403 Forbidden"; real="URL Forbidden";
     fault=@{ type="forbidden_403"; target="dealer-reports" }; probe="/api/reports/monthly";
     pages=@("/reports");
     see="Reports page shows the error card with 403." },

  @{ n="10_bonus_full_outage"; title="BONUS: Full outage (everything down)"; real="Website outage";
     fault=@{ type="outage"; target="all" }; probe="/health";
     pages=@("/", "/stock", "/login");
     see="Every data page shows an error card, while the sidebar and top bar stay. /login shows an error page." }
)

$i = 0
try {
  foreach ($s in $steps) {
    $i++
    Reset-All | Out-Null
    Write-Host ""
    Write-Host ("=" * 74) -ForegroundColor Cyan
    Write-Host ("STEP {0} of {1}   save screenshot as: {2}.png" -f $i, $steps.Count, $s.n) -ForegroundColor Cyan
    Write-Host $s.title -ForegroundColor White
    Write-Host ("Matches your production report: " + $s.real) -ForegroundColor DarkYellow
    if ($s.fault) {
      $body = @{ duration_seconds = $secs; note = "screenshot_demo" }
      foreach ($k in $s.fault.Keys) { $body[$k] = $s.fault[$k] }
      $res = Start-Fault $body
      if ($res.Status -lt 200 -or $res.Status -ge 300) {
        Write-Host ("Could not start this fault: status " + $res.Status + " " + (Head $res.Body 150)) -ForegroundColor Red
        Read-Host "Press Enter to skip this step"
        continue
      }
      Write-Host ("Fault started at " + (Get-Date -Format "HH:mm:ss") + " (it stays active for " + $Minutes + " minutes)") -ForegroundColor Green
    }
    Start-Sleep -Milliseconds 1200
    if ($s.probe) {
      $pr = Req -Path $s.probe -Timeout 60
      $line = "Server check: {0} returns status {1} in {2} ms" -f $s.probe, $pr.Status, $pr.Ms
      if ($s.kw) { $line += ("; text '" + $s.kw + "' present: " + ($pr.Body -like ("*" + $s.kw + "*"))) }
      Write-Host $line -ForegroundColor Yellow
    }
    Write-Host "NOW: open this page in the browser, clear the Network log, press Ctrl+F5:"
    foreach ($pg in $s.pages) { Write-Host ("     " + $Base + $pg) -ForegroundColor Yellow }
    Write-Host ("EXPECTED: " + $s.see)
    Read-Host "Take the screenshot, then press Enter for the next step"
  }
}
finally {
  Reset-All | Out-Null
  Write-Host ""
  Write-Host "All errors reset. Reload the dashboard and take a final 'recovered' screenshot (name: 99_recovered_AFTER.png)." -ForegroundColor Green
}