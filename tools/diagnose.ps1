param(
  [string]$Base = "http://localhost:8000",
  [Parameter(Mandatory=$true)][string]$Token,
  [string]$Target = "parts_stock",
  [string]$Path = "/api/stock",
  [string]$OtherPath = "/api/claims/bookings",
  [string]$ProjectDir = ".."
)
. "$PSScriptRoot\common.ps1"
function Ok($m) { Write-Host "[PASS] $m" -ForegroundColor Green }
function Bad($m,$hint) { Write-Host "[FAIL] $m" -ForegroundColor Red; Write-Host "       Likely cause: $hint" -ForegroundColor Yellow; Reset-All | Out-Null; exit 1 }

Write-Host "Diagnosing $Base" -ForegroundColor Cyan

$r = Req -Path "/health"
if ($r.Status -eq 200) { Ok "Server answers /health" } else { Bad "Server not reachable (status $($r.Status))" "Site not running, or wrong URL or port" }

$r = Req -Path "/api/modules"
Write-Host "       /api/modules: $(Head $r.Body 600)"
if ($r.Body -notmatch [regex]::Escape($Target)) { Write-Host "[WARN] '$Target' is not in the list above. Re-run with -Target <real module id>." -ForegroundColor Yellow }

$r = Get-Status
if (Is-Html $r.Body)      { Bad "Admin API returned the React page (HTML)" "The SPA fallback is catching /admin/api. Register admin router and fault middleware BEFORE the SPA fallback or static mount." }
elseif ($r.Status -eq 401) { Bad "Admin API says 401" "Token in .env differs from the one you passed. Restart after editing .env." }
elseif ($r.Status -eq 403) { Bad "Admin API says 403" "ADMIN_TOKEN is empty or 'change-me', or FAULTS_ENABLED=false." }
elseif ($r.Status -eq 404) { Bad "Admin API says 404" "Admin router not registered, or it uses a different path. Check /docs or the source." }
elseif ($r.Status -eq 200) { Ok "Admin API reachable, token accepted" }
else { Bad "Admin API status $($r.Status): $(Head $r.Body 150)" "Unexpected admin error" }

$s = Start-Fault @{ type="error_500"; target=$Target; duration_seconds=120; note="diagnose" }
if ($s.Status -ge 200 -and $s.Status -lt 300 -and -not (Is-Html $s.Body)) { Ok "Fault accepted: $(Head $s.Body 150)" }
else { Bad "Fault start rejected (status $($s.Status)): $(Head $s.Body 200)" "Wrong field names or invalid target. See /docs for the exact request body." }
Start-Sleep -Seconds 1

$r = Get-Status
if ($r.Body -match [regex]::Escape($Target)) { Ok "Fault listed as active in /admin/api/status" }
else { Bad "Fault accepted but NOT listed as active" "State not saved or not read (wrong file path), or the fault expired immediately (time zone, or seconds vs milliseconds)." }

$f = Get-ChildItem -Path $ProjectDir -Recurse -Filter "fault_state.json" -ErrorAction SilentlyContinue | Select-Object -First 3
if ($f) { $f | ForEach-Object { Write-Host "       state file: $($_.FullName) (modified $($_.LastWriteTime))" } }
else { Write-Host "[WARN] no fault_state.json found under $ProjectDir" -ForegroundColor Yellow }

$r = Req -Path $Path
if ($r.Status -eq 500) { Ok "$Path returns 500 as injected" }
else { Bad "$Path returned $($r.Status), expected 500" "Fault stored but not applied: middleware not registered, sitting behind the static/SPA mount, or path-to-module matching does not cover this path. Also confirm no old server process." }

$bad = 0; 1..20 | ForEach-Object { if ((Req -Path $Path).Status -ne 500) { $bad++ } }
if ($bad -eq 0) { Ok "20 of 20 requests failed (consistent)" }
else { Bad "$bad of 20 requests were NOT affected" "Several workers or processes with separate in-memory state, or an old process still running." }

$o = Req -Path $OtherPath; $h = Req -Path "/health"
if ($o.Status -eq 200 -and $h.Status -eq 200) { Ok "Other module and /health unaffected" }
else { Bad "Other module ($($o.Status)) or /health ($($h.Status)) affected" "Target matching is too broad." }

Reset-All | Out-Null; Start-Sleep -Seconds 1
$r = Req -Path $Path
if ($r.Status -eq 200) { Ok "Recovered after reset" } else { Bad "Still failing after reset ($($r.Status))" "Reset does not clear state or the cache is not refreshing." }

$l = Req -Path "/admin/api/fault-log" -Admin
if ($l.Body -match "fault_start" -and $l.Body -match "fault_end") { Ok "Ground-truth log has fault_start and fault_end" }
else { Write-Host "[WARN] fault log missing start/end lines" -ForegroundColor Yellow }

Write-Host "`nAll checks passed. Next: run test_all_faults.ps1" -ForegroundColor Green