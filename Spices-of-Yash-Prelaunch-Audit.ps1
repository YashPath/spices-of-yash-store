$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"
Write-Host "`n=== SPICES OF YASH: PRE-LAUNCH AUDIT ===" -ForegroundColor Cyan
$failed = 0
$warnings = 0

if (-not (Test-Path ".\package.json") -or -not (Test-Path ".\data\store.sqlite")) {
  Write-Host "FAIL: Run this script from the spices-of-yash-store project root; package.json and data\store.sqlite must exist." -ForegroundColor Red
  exit 2
}
if (-not (Test-Path ".\node_modules\better-sqlite3")) {
  Write-Host "FAIL: better-sqlite3 is missing. No install was attempted." -ForegroundColor Red
  exit 2
}

Write-Host "`n--- Consistent SQLite backup ---" -ForegroundColor Cyan
$backupCode = 'const D=require("better-sqlite3");const db=new D("data/store.sqlite",{readonly:true,fileMustExist:true});const out="data/store.prelaunch-"+Date.now()+".sqlite";db.backup(out).then(()=>{console.log("PASS backup created: "+out);db.close()}).catch(e=>{console.error("FAIL backup: "+e.message);try{db.close()}catch{};process.exitCode=1})'
& node -e $backupCode
if ($LASTEXITCODE -ne 0) { Write-Host "Backup failed; stopping to protect your data." -ForegroundColor Red; exit 3 }

Write-Host "`n--- Syntax check ---" -ForegroundColor Cyan
& node --check .\server.js
if ($LASTEXITCODE -eq 0) { Write-Host "PASS server.js syntax" -ForegroundColor Green } else { Write-Host "FAIL server.js syntax" -ForegroundColor Red; $failed++ }

Write-Host "`n--- Static smoke tests ---" -ForegroundColor Cyan
& npm test
if ($LASTEXITCODE -eq 0) { Write-Host "PASS npm test" -ForegroundColor Green } else { Write-Host "FAIL npm test" -ForegroundColor Red; $failed++ }

Write-Host "`n--- Database audit ---" -ForegroundColor Cyan
if (Test-Path ".\scripts\db-audit.js") {
  & node .\scripts\db-audit.js
  if ($LASTEXITCODE -eq 0) { Write-Host "PASS database audit command" -ForegroundColor Green } else { Write-Host "FAIL database audit command" -ForegroundColor Red; $failed++ }
} else { Write-Host "WARN scripts\db-audit.js not found" -ForegroundColor Yellow; $warnings++ }

Write-Host "`n--- Live HTTP checks (GET only) ---" -ForegroundColor Cyan
try {
  $home = Invoke-WebRequest -Uri "http://localhost:3000/" -UseBasicParsing -TimeoutSec 4
  Write-Host "Storefront HTTP: $([int]$home.StatusCode)"
  if ([int]$home.StatusCode -ge 400) { $failed++ }
  try {
    $admin = Invoke-WebRequest -Uri "http://localhost:3000/admin" -UseBasicParsing -TimeoutSec 4
    Write-Host "Admin page HTTP: $([int]$admin.StatusCode)"
    if ([int]$admin.StatusCode -ge 500) { $failed++ }
  } catch {
    $code = 0
    if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
    if ($code -ge 500) { Write-Host "Admin page HTTP: $code" -ForegroundColor Red; $failed++ }
    elseif ($code -gt 0) { Write-Host "Admin page HTTP: $code" }
    else { Write-Host "WARN /admin check failed: $($_.Exception.Message)" -ForegroundColor Yellow; $warnings++ }
  }
  try {
    $api = Invoke-WebRequest -Uri "http://localhost:3000/api/admin/products" -UseBasicParsing -TimeoutSec 4
    $apiCode = [int]$api.StatusCode
    $apiBody = [string]$api.Content
  } catch {
    $apiCode = 0; $apiBody = ""
    if ($_.Exception.Response) {
      $apiCode = [int]$_.Exception.Response.StatusCode
      try { $r = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream()); $apiBody = $r.ReadToEnd(); $r.Close() } catch {}
    }
  }
  if ($apiCode -eq 401 -or $apiCode -eq 403 -or $apiBody -match "Admin login required") {
    Write-Host "PASS unauthenticated admin API is denied (HTTP $apiCode)" -ForegroundColor Green
  } elseif ($apiCode -eq 200) {
    Write-Host "WARN admin API returned 200 without login; review auth protection" -ForegroundColor Yellow; $warnings++
  } elseif ($apiCode -eq 0) {
    Write-Host "WARN server/API not reachable; start npm start for live checks" -ForegroundColor Yellow; $warnings++
  } else { Write-Host "WARN admin API HTTP $apiCode; review response" -ForegroundColor Yellow; $warnings++ }
} catch {
  Write-Host "WARN local server not responding; live HTTP checks skipped" -ForegroundColor Yellow
  $warnings++
}

Write-Host "`n--- Production dependency audit (network required) ---" -ForegroundColor Cyan
& npm audit --omit=dev
if ($LASTEXITCODE -eq 0) { Write-Host "PASS npm audit --omit=dev" -ForegroundColor Green }
else { Write-Host "WARN npm audit found issues or registry was unavailable. No packages were changed." -ForegroundColor Yellow; $warnings++ }

Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Hard failures: $failed"
Write-Host "Warnings / manual review: $warnings"
Write-Host "Backup: data\store.prelaunch-<timestamp>.sqlite"
Write-Host "This is an automated prelaunch audit, not proof of full production readiness." -ForegroundColor Yellow
if ($failed -gt 0) { exit 1 } else { exit 0 }
