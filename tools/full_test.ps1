param(
  [string]$Base = "http://localhost:8000",
  [Parameter(Mandatory=$true)][string]$Token,
  [string]$LogDir = "..\backend\logs",
  [switch]$Quick
)
. "$PSScriptRoot\common.ps1"
$script:Results = New-Object System.Collections.ArrayList
$swAll = [Diagnostics.Stopwatch]::StartNew()

function Stage($t) { Write-Host ""; Write-Host "=== $t" -ForegroundColor Cyan }
function Info($t)  { Write-Host "    $t" -ForegroundColor DarkGray }
function Check($stage, $name, $ok, $detail) {
  $tag = "FAIL"; $col = "Red"
  if ($ok) { $tag = "PASS"; $col = "Green" }
  [void]$script:Results.Add([pscustomobject]@{ Stage = $stage; Test = $name; Result = $tag; Detail = $detail })
  Write-Host ("  [{0}] {1} - {2}" -f $tag, $name, $detail) -ForegroundColor $col
}
function Mod([string[]]$patterns) {
  foreach ($p in $patterns) {
    $m = $script:mods | Where-Object { ($_.path -like $p) -or ($_.id -like $p) } | Select-Object -First 1
    if ($m) { return $m }
  }
  return $null
}
function Has-Kw($body, $kw) { return ($body -like "*$kw*") }
function Norm($o) {
  if ($null -eq $o) { return @() }
  if ($o -is [array]) { return $o }
  foreach ($k in @("results","presets","items","data")) {
    if ($o.PSObject.Properties[$k]) { return @($o.$k) }
  }
  return @($o)
}
function Get-HeaderText($path) {
  try {
    $w = Invoke-WebRequest -Uri "$Base$path" -UseBasicParsing -TimeoutSec 60
    return (($w.Headers.Keys | ForEach-Object { "$_=$($w.Headers[$_])" }) -join "; ")
  } catch {
    $resp = $_.Exception.Response
    if ($resp -and $resp.Headers) {
      try { return (($resp.Headers.AllKeys | ForEach-Object { "$_=$($resp.Headers[$_])" }) -join "; ") }
      catch { return ($resp.Headers | Out-String) }
    }
    return ""
  }
}

function Run-Case($c) {
  Stage ("FAULT: " + $c.n)
  if ($null -eq $c.mod) { Check "faults" $c.n $false "module not found in /api/modules"; return }
  $body = @{ type = $c.type; target = $c.mod.id; duration_seconds = 120; note = "full_test" }
  foreach ($k in $c.extra.Keys) { $body[$k] = $c.extra[$k] }
  $s = Start-Fault $body
  $ok = ($s.Status -ge 200 -and $s.Status -lt 300 -and -not (Is-Html $s.Body))
  $why = ""
  if (-not $ok) { $why = Head $s.Body 150 }
  Check "faults" ($c.n + " - fault accepted") $ok ("status " + $s.Status + " " + $why)
  if (-not $ok) { Reset-All | Out-Null; return }
  Start-Sleep -Milliseconds 1200

  $r = Req -Path $c.mod.path -Timeout 90
  if ($c.status) { Check "faults" ($c.n + " - status") ($r.Status -eq $c.status) ("got " + $r.Status + ", expected " + $c.status + ", " + $r.Ms + " ms") }
  if ($c.minMs)  { Check "faults" ($c.n + " - delay") ($r.Ms -ge $c.minMs) ("" + $r.Ms + " ms, expected at least " + $c.minMs) }
  if ($c.kwAbsent)  { Check "faults" ($c.n + " - keyword missing") (-not (Has-Kw $r.Body $c.mod.keyword)) ("'" + $c.mod.keyword + "' absent from the raw response") }
  if ($c.kwPresent) { Check "faults" ($c.n + " - content still correct") (Has-Kw $r.Body $c.mod.keyword) ("'" + $c.mod.keyword + "' present") }
  if ($c.bodyMatch) { Check "faults" ($c.n + " - body pattern") ($r.Body -match $c.bodyMatch) (Head $r.Body 120) }
  if ($c.leak) {
    $ht = Get-HeaderText $c.mod.path
    Check "faults" ($c.n + " - no fault hint in headers") (-not ($ht -match "(?i)fault|inject|chaos")) "headers checked"
    Check "faults" ($c.n + " - no fault hint in body") (-not ($r.Body -match "(?i)inject|fault")) (Head $r.Body 80)
  }
  $other = $mBook
  if ($c.mod.id -eq $mBook.id) { $other = $mStock }
  $o = Req -Path $other.path
  Check "faults" ($c.n + " - other module unaffected") ($o.Status -eq 200 -and (Has-Kw $o.Body $other.keyword)) ($other.path + " -> " + $o.Status)

  Reset-All | Out-Null
  Start-Sleep -Milliseconds 1200
  $a = Req -Path $c.mod.path -Timeout 90
  Check "faults" ($c.n + " - recovers after reset") ($a.Status -eq 200 -and (Has-Kw $a.Body $c.mod.keyword) -and $a.Ms -lt 3000) ("status " + $a.Status + ", " + $a.Ms + " ms")
}

function Run-Chronic($label, $sev, $mod, $count, $minSlow, $maxSlow) {
  Stage ("FAULT: " + $label)
  if ($null -eq $mod) { Check "chronic" $label $false "module not found"; return }
  $s = Start-Fault @{ type = "slow_chronic"; target = $mod.id; duration_seconds = 300; severity = $sev; probability = 0.35; note = "full_test" }
  $ok = ($s.Status -ge 200 -and $s.Status -lt 300 -and -not (Is-Html $s.Body))
  Check "chronic" ($label + " - fault accepted") $ok ("status " + $s.Status + " " + (Head $s.Body 120))
  if (-not $ok) { Reset-All | Out-Null; return }
  Start-Sleep -Milliseconds 1200
  $slow = 0; $down = 0; $max = 0; $limit = [int]$mod.threshold_ms
  for ($i = 0; $i -lt $count; $i++) {
    $r = Req -Path $mod.path -Timeout 90
    if ($r.Status -ne 200) { $down++ }
    if ($r.Ms -gt $limit) { $slow++ }
    if ($r.Ms -gt $max) { $max = $r.Ms }
  }
  Check "chronic" ($label + " - service stays up") ($down -eq 0) ("" + $down + " failed of " + $count)
  Check "chronic" ($label + " - some requests exceed " + $limit + " ms") (($slow -ge $minSlow) -and ($slow -le $maxSlow)) ("" + $slow + " of " + $count + " slow (expected about " + [math]::Round($count * 0.35) + "), slowest " + $max + " ms")
  Reset-All | Out-Null
}

try {
  Reset-All | Out-Null

  # ---------------- STAGE 0 ----------------
  Stage "STAGE 0: pre-flight"
  $r = Req -Path "/health"
  Check "pre" "server answers /health" ($r.Status -eq 200) ("status " + $r.Status)
  if ($r.Status -ne 200) { throw "Server not reachable. Start the site first." }
  $mr = Req -Path "/api/modules"
  $script:mods = @((($mr.Body | ConvertFrom-Json).results))
  Check "pre" "module registry loaded" ($script:mods.Count -ge 8) ("" + $script:mods.Count + " modules")
  foreach ($m in $script:mods) { Info ("{0,-18} {1,-30} {2,5} ms  keyword={3}" -f $m.id, $m.path, $m.threshold_ms, $m.keyword) }

  $mBook  = Mod @("*booking*")
  $mTrans = Mod @("*transit*")
  $mStock = Mod @("*stock*")
  $mInv   = Mod @("*einvoice*", "*invoice*")
  $mSign  = Mod @("*login*", "*sign*")
  $mRep   = Mod @("*report*")
  $mCat   = Mod @("*catalogue*")
  $mGate  = Mod @("*gateway*")
  if ($null -eq $mSign) { $mSign = [pscustomobject]@{ id = "signin"; path = "/login"; threshold_ms = 1000; keyword = "Sign in with SSO" }; Info "sign-in module not in the registry, assuming id 'signin'" }

  $eps = @()
  foreach ($m in $script:mods) { $eps += [pscustomobject]@{ name = $m.id; path = $m.path; kw = $m.keyword; limit = [int]$m.threshold_ms } }
  if (-not ($eps | Where-Object { $_.path -eq "/login" })) { $eps += [pscustomobject]@{ name = "sign-in"; path = "/login"; kw = "Sign in with SSO"; limit = 1000 } }
  $eps += [pscustomobject]@{ name = "health"; path = "/health"; kw = "ok"; limit = 1000 }

  # ---------------- STAGE 1 ----------------
  Stage "STAGE 1: baseline (no fault) - every endpoint, 5 calls each"
  foreach ($e in $eps) {
    Req -Path $e.path | Out-Null
    $okc = 0; $max = 0
    for ($i = 0; $i -lt 5; $i++) {
      $r = Req -Path $e.path
      if ($r.Status -eq 200 -and (Has-Kw $r.Body $e.kw)) { $okc++ }
      if ($r.Ms -gt $max) { $max = $r.Ms }
    }
    Check "baseline" $e.name (($okc -eq 5) -and ($max -lt $e.limit)) ("" + $okc + "/5 ok, slowest " + $max + " ms, limit " + $e.limit + " ms (" + $e.path + ")")
  }

  Stage "STAGE 2: routing (site pages vs API)"
  $r = Req -Path "/";            Check "routing" "React shell at /" ($r.Status -eq 200 -and ($r.Body -match 'id="root"')) ("status " + $r.Status)
  $r = Req -Path "/stock";       Check "routing" "deep link /stock serves the app" ($r.Status -eq 200 -and ($r.Body -match 'id="root"')) ("status " + $r.Status)
  $r = Req -Path "/admin/console"; Check "routing" "/admin/console page loads" ($r.Status -eq 200) ("status " + $r.Status)
  $r = Req -Path "/docs";        Check "routing" "/docs loads" ($r.Status -eq 200) ("status " + $r.Status)
  $r = Req -Path "/api/modules"; Check "routing" "/api/modules is JSON, not the React page" ($r.Status -eq 200 -and -not (Is-Html $r.Body)) ("status " + $r.Status)
  $r = Req -Path "/api/does-not-exist"; Check "routing" "unknown API path returns JSON, not the React page" (-not (Is-Html $r.Body)) ("status " + $r.Status)
  $r = Req -Path "/login";       Check "routing" "/login is server-rendered HTML with the keyword" ((Is-Html $r.Body) -and (Has-Kw $r.Body "Sign in with SSO")) ("status " + $r.Status)

  Stage "STAGE 3: admin security"
  $r = Req -Method POST -Path "/admin/api/reset" -Body @{ target = "all" }
  Check "security" "no token is rejected" ($r.Status -eq 401) ("status " + $r.Status)
  $saved = $Token; $Token = "wrong-token-for-test"
  $r = Req -Path "/admin/api/status" -Admin
  $Token = $saved
  Check "security" "wrong token is rejected" ($r.Status -eq 401) ("status " + $r.Status)
  $r = Get-Status
  Check "security" "correct token works" ($r.Status -eq 200 -and -not (Is-Html $r.Body)) ("status " + $r.Status)

  # ---------------- STAGE 4 ----------------
  Stage "STAGE 4: every fault type, one at a time"
  Run-Case @{ n = "unavailable_503 (parts stock)"; type = "unavailable_503"; mod = $mStock; extra = @{}; status = 503; leak = $true }
  Run-Case @{ n = "error_500 (e-invoice)";          type = "error_500";       mod = $mInv;   extra = @{}; status = 500; leak = $true }
  Run-Case @{ n = "bad_gateway_502 (gateway)";      type = "bad_gateway_502"; mod = $mGate;  extra = @{}; status = 502 }
  Run-Case @{ n = "forbidden_403 (reports)";        type = "forbidden_403";   mod = $mRep;   extra = @{}; status = 403 }
  Run-Case @{ n = "not_found_404 (reports)";        type = "not_found_404";   mod = $mRep;   extra = @{}; status = 404 }
  Run-Case @{ n = "slow_fixed 1500 ms (booking claims)"; type = "slow_fixed"; mod = $mBook; extra = @{ delay_ms = 1500 }; status = 200; minMs = 1400; kwPresent = $true }
  Run-Case @{ n = "wrong_content (sign-in page)";   type = "wrong_content";   mod = $mSign;  extra = @{ mode = "maintenance" }; status = 200; kwAbsent = $true; leak = $true }
  Run-Case @{ n = "wrong_content (catalogue, maintenance)"; type = "wrong_content"; mod = $mCat; extra = @{ mode = "maintenance" }; status = 200; kwAbsent = $true }
  Run-Case @{ n = "wrong_content empty list (catalogue)";   type = "wrong_content"; mod = $mCat; extra = @{ mode = "empty" }; status = 200; bodyMatch = '"count"\s*:\s*0' }
  if ($Quick) {
    Run-Case @{ n = "gateway_timeout_504 (3 s wait, quick)"; type = "gateway_timeout_504"; mod = $mGate; extra = @{ upstream_delay_ms = 3000 }; status = 504; minMs = 2800 }
    Run-Case @{ n = "hang (5 s, quick)"; type = "hang"; mod = $mCat; extra = @{ hang_seconds = 5 }; status = 200; minMs = 4800; kwPresent = $true }
  } else {
    Run-Case @{ n = "gateway_timeout_504 (default 10 s wait)"; type = "gateway_timeout_504"; mod = $mGate; extra = @{}; status = 504; minMs = 9000 }
    Run-Case @{ n = "hang (default 35 s)"; type = "hang"; mod = $mCat; extra = @{}; status = 200; minMs = 34000; kwPresent = $true }
  }

  Stage "STAGE 5: chronic slowness (some requests slow, service stays up)"
  Run-Chronic "slow_chronic marginal (booking claims)" "marginal" $mBook 30 3 22
  Run-Chronic "slow_chronic severe (transit claims)"   "severe"   $mTrans 20 1 16

  Stage "STAGE 6: behaviour rules"
  Start-Fault @{ type = "error_500"; target = $mStock.id; duration_seconds = 120; note = "full_test" } | Out-Null
  Start-Sleep -Milliseconds 1200
  $a = Req -Path $mStock.path
  Start-Fault @{ type = "slow_fixed"; target = $mStock.id; duration_seconds = 120; delay_ms = 1500; note = "full_test" } | Out-Null
  Start-Sleep -Milliseconds 1200
  $b = Req -Path $mStock.path
  Check "rules" "first fault on the target works" ($a.Status -eq 500) ("status " + $a.Status)
  Check "rules" "new fault on same target replaces the old one" ($b.Status -eq 200 -and $b.Ms -ge 1400) ("status " + $b.Status + ", " + $b.Ms + " ms")
  Reset-All | Out-Null

  Start-Fault @{ type = "unavailable_503"; target = $mStock.id; duration_seconds = 120; note = "full_test" } | Out-Null
  Start-Fault @{ type = "error_500"; target = $mInv.id; duration_seconds = 120; note = "full_test" } | Out-Null
  Start-Sleep -Milliseconds 1200
  $x = Req -Path $mStock.path; $y = Req -Path $mInv.path; $z = Req -Path $mBook.path
  Check "rules" "two faults at once: both apply" ($x.Status -eq 503 -and $y.Status -eq 500) ("stock " + $x.Status + ", invoice " + $y.Status)
  Check "rules" "two faults at once: third module unaffected" ($z.Status -eq 200) ("booking " + $z.Status)
  Reset-All | Out-Null

  Start-Fault @{ type = "blip"; target = $mCat.id; count = 1; duration_seconds = 120; note = "full_test" } | Out-Null
  Start-Sleep -Milliseconds 1200
  $a = Req -Path $mCat.path; $b = Req -Path $mCat.path; $c3 = Req -Path $mCat.path
  Check "rules" "blip: first request fails" ($a.Status -eq 500) ("status " + $a.Status)
  Check "rules" "blip: next two requests are fine" ($b.Status -eq 200 -and $c3.Status -eq 200) ("" + $b.Status + ", " + $c3.Status)
  Reset-All | Out-Null

  Start-Fault @{ type = "unavailable_503"; target = $mStock.id; duration_seconds = 10; note = "full_test" } | Out-Null
  Start-Sleep -Milliseconds 1200
  $a = Req -Path $mStock.path
  Start-Sleep -Seconds 11
  $b = Req -Path $mStock.path
  Check "rules" "auto-expiry: fault active at first" ($a.Status -eq 503) ("status " + $a.Status)
  Check "rules" "auto-expiry: gone by itself after 10 s" ($b.Status -eq 200) ("status " + $b.Status)

  Stage "STAGE 7: full outage (all modules)"
  Start-Fault @{ type = "outage"; target = "all"; duration_seconds = 120; note = "full_test" } | Out-Null
  Start-Sleep -Milliseconds 1200
  foreach ($e in $eps) {
    $r = Req -Path $e.path
    Check "outage" ("down: " + $e.path) ($r.Status -eq 503) ("status " + $r.Status)
  }
  $r = Req -Path "/login"
  Check "outage" "/login has no sign-in text during outage" (-not (Has-Kw $r.Body "Sign in with SSO")) "keyword absent"
  Check "outage" "admin API still works" ((Get-Status).Status -eq 200) "exempt"
  Check "outage" "/api/modules still works" ((Req -Path "/api/modules").Status -eq 200) "exempt"
  Check "outage" "React shell still loads" ((Req -Path "/").Status -eq 200) "exempt"
  Reset-All | Out-Null
  Start-Sleep -Milliseconds 1500
  $badAfter = 0
  foreach ($e in $eps) { if ((Req -Path $e.path).Status -ne 200) { $badAfter++ } }
  Check "outage" "everything recovers after reset" ($badAfter -eq 0) ("" + $badAfter + " endpoints still failing")

  # ---------------- STAGE 8 ----------------
  Stage "STAGE 8: every preset in your build"
  $pr = Req -Path "/admin/api/presets" -Admin
  $presets = @()
  if ($pr.Status -eq 200) { try { $presets = @(Norm ($pr.Body | ConvertFrom-Json)) } catch {} }
  Check "presets" "preset list available" ($presets.Count -gt 0) ("" + $presets.Count + " presets")
  foreach ($p in $presets) {
    $pname = $null
    foreach ($k in @("name", "preset", "id")) { if ($p.PSObject.Properties[$k] -and $p.$k) { $pname = [string]$p.$k; break } }
    if (-not $pname) { continue }
    $ptarget = ""
    if ($p.PSObject.Properties["target"]) { $ptarget = [string]$p.target }
    $s = Start-Preset $pname 120
    $ok = ($s.Status -ge 200 -and $s.Status -lt 300 -and -not (Is-Html $s.Body))
    Check "presets" ($pname + " - starts") $ok ("status " + $s.Status + " " + (Head $s.Body 100))
    if (-not $ok) { Reset-All | Out-Null; continue }
    Start-Sleep -Milliseconds 1200

    $path = $mStock.path; $kw = $mStock.keyword; $limit = [int]$mStock.threshold_ms
    if ($ptarget -eq "health") { $path = "/health"; $kw = "ok"; $limit = 1000 }
    elseif ($ptarget -and $ptarget -ne "all") {
      $pm = $script:mods | Where-Object { $_.id -eq $ptarget } | Select-Object -First 1
      if ($null -eq $pm -and $ptarget -eq $mSign.id) { $pm = $mSign }
      if ($pm) { $path = $pm.path; $kw = $pm.keyword; $limit = [int]$pm.threshold_ms }
    }
    $skip = ($Quick -and ($pname -match "hang|504|timeout"))
    if ($skip) { Info ($pname + ": effect probe skipped in -Quick mode (slow fault)"); Reset-All | Out-Null; Start-Sleep -Milliseconds 800; continue }
    $tries = 1
    if ($pname -match "chronic|slow") { $tries = 20 }
    $effect = $false; $seen = ""
    for ($i = 0; $i -lt $tries; $i++) {
      $r = Req -Path $path -Timeout 90
      if ($r.Status -ne 200 -or $r.Ms -gt $limit -or -not (Has-Kw $r.Body $kw) -or ($r.Body -match '"count"\s*:\s*0')) { $effect = $true; $seen = "status " + $r.Status + ", " + $r.Ms + " ms"; break }
    }
    if (-not $effect) { $seen = "no change seen on " + $path }
    Check "presets" ($pname + " - visible effect on " + $path) $effect $seen
    Reset-All | Out-Null
    Start-Sleep -Milliseconds 800
  }

  # ---------------- STAGE 9 ----------------
  Stage "STAGE 9: ground-truth logs (the answer key)"
  $ld = $LogDir
  if (-not (Test-Path $ld)) { $ld = Join-Path $PSScriptRoot $LogDir }
  Info ("log folder: " + $ld)
  $flog = Join-Path $ld "fault_log.jsonl"
  $alog = Join-Path $ld "access.jsonl"
  if (Test-Path $flog) {
    $lines = @(Get-Content $flog)
    $starts = @($lines | Select-String -Pattern "start").Count
    $ends   = @($lines | Select-String -Pattern "end|expired").Count
    Check "logs" "fault_log.jsonl has entries" ($lines.Count -gt 0) ("" + $lines.Count + " lines")
    Check "logs" "log has start events" ($starts -gt 0) ("" + $starts)
    Check "logs" "log has end or expired events" ($ends -gt 0) ("" + $ends)
    Check "logs" "log timestamps use +05:30" ([bool](Select-String -Path $flog -SimpleMatch "+05:30" -Quiet)) "IST offset"
    Check "logs" "admin token is not in the fault log" (-not [bool](Select-String -Path $flog -SimpleMatch $Token -Quiet)) "token absent"
    Info "last 3 log lines:"
    $lines | Select-Object -Last 3 | ForEach-Object { Info (Head $_ 260) }
  } else { Check "logs" "fault_log.jsonl exists" $false ("not found at " + $flog + " (use -LogDir to point to it)") }
  if (Test-Path $alog) {
    Check "logs" "access.jsonl marks affected requests with fault_id" ([bool](Select-String -Path $alog -Pattern "fault_id" -Quiet)) "fault_id found"
    Check "logs" "admin token is not in the access log" (-not [bool](Select-String -Path $alog -SimpleMatch $Token -Quiet)) "token absent"
  } else { Check "logs" "access.jsonl exists" $false ("not found at " + $alog) }
  $l = Req -Path "/admin/api/fault-log" -Admin
  Check "logs" "GET /admin/api/fault-log works" ($l.Status -eq 200 -and -not (Is-Html $l.Body)) ("status " + $l.Status)
  $sm = Req -Path "/admin/api/summary" -Admin
  Check "logs" "GET /admin/api/summary works" ($sm.Status -eq 200 -and -not (Is-Html $sm.Body)) ("status " + $sm.Status)
}
catch { Write-Host ("STOPPED: " + $_) -ForegroundColor Red }
finally { Reset-All | Out-Null }

$swAll.Stop()
Write-Host ""
Write-Host "================ SUMMARY ================" -ForegroundColor Cyan
$fails = @($script:Results | Where-Object { $_.Result -eq "FAIL" })
$passes = @($script:Results | Where-Object { $_.Result -eq "PASS" })
Write-Host ("PASS: " + $passes.Count + "    FAIL: " + $fails.Count + "    time: " + $swAll.Elapsed.ToString("mm\:ss"))
if ($fails.Count -gt 0) {
  Write-Host "`nFailed checks:" -ForegroundColor Red
  $fails | Format-Table Stage, Test, Detail -AutoSize -Wrap
}
$csv = Join-Path $PSScriptRoot "test_results.csv"
$script:Results | Export-Csv -Path $csv -NoTypeInformation
Write-Host ("Full results saved to " + $csv)
if ($passes.Count -eq 0) { Write-Host "NO CHECKS RAN - treat as FAILED" -ForegroundColor Red; exit 1 }; if ($fails.Count -eq 0) { Write-Host "ALL TESTS PASSED" -ForegroundColor Green; exit 0 } else { exit 1 }
