function Req {
  param([string]$Method="GET",[string]$Path,[object]$Body=$null,[switch]$Admin,[int]$Timeout=60)
  $h = @{}
  if ($Admin) { $h["x-admin-token"] = $Token }
  $p = @{ Uri="$Base$Path"; Method=$Method; Headers=$h; UseBasicParsing=$true; TimeoutSec=$Timeout }
  if ($null -ne $Body) { $p.Body = ($Body | ConvertTo-Json -Depth 5); $p.ContentType = "application/json" }
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $status = -1; $content = ""
  try {
    $r = Invoke-WebRequest @p
    $status = [int]$r.StatusCode; $content = [string]$r.Content
  } catch {
    $resp = $_.Exception.Response
    if ($resp) {
      $status = [int]$resp.StatusCode
      if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $content = $_.ErrorDetails.Message }
      else { try { $sr = New-Object IO.StreamReader($resp.GetResponseStream()); $content = $sr.ReadToEnd(); $sr.Close() } catch {} }
    } else { $content = $_.Exception.Message }
  }
  $sw.Stop()
  [pscustomobject]@{ Status=$status; Ms=[int]$sw.ElapsedMilliseconds; Body=$content }
}
function Start-Preset($name,$secs=180) { Req -Method POST -Path "/admin/api/preset" -Body @{preset=$name; duration_seconds=$secs} -Admin }
function Start-Fault($body)            { Req -Method POST -Path "/admin/api/fault" -Body $body -Admin }
function Reset-All                     { Req -Method POST -Path "/admin/api/reset" -Body @{target="all"} -Admin }
function Get-Status                    { Req -Path "/admin/api/status" -Admin }
function Is-Html($b)                   { $b -match '^\s*<(!doctype|html)' }
function Head($b,$n=300)               { if ($b.Length -gt $n) { $b.Substring(0,$n) } else { $b } }