# Spices of Yash - Read-only project health report
# Run from the spices-of-yash-store project folder.
$ErrorActionPreference = "Continue"
$root = (Get-Location).Path
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$report = Join-Path $root "health-report-$stamp.txt"
Start-Transcript -Path $report -Force | Out-Null

function Section($name) {
  Write-Output "`r`n========== $name =========="
}
function Check-File($path) {
  if (Test-Path $path) { Write-Output "PASS  Found: $path" }
  else { Write-Output "WARN  Missing: $path" }
}

Write-Output "SPICES OF YASH - READ-ONLY HEALTH REPORT"
Write-Output "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output "Project: $root"
Write-Output "Note: This report does not modify project files or fix vulnerabilities."

Section "1. RUNTIME"
node --version
npm --version
if ($LASTEXITCODE -ne 0) { Write-Output "WARN  Node/npm command failed." }

Section "2. IMPORTANT FILES"
@("package.json","server.js","public\index.html","public\styles.css","public\app.js",".env") | ForEach-Object { Check-File $_ }
if (Test-Path "package.json") {
  try {
    $pkg = Get-Content "package.json" -Raw | ConvertFrom-Json
    Write-Output "Package: $($pkg.name) $($pkg.version)"
    Write-Output "Start script: $($pkg.scripts.start)"
    Write-Output "Test script: $($pkg.scripts.test)"
  } catch { Write-Output "FAIL  package.json could not be parsed: $($_.Exception.Message)" }
}

Section "3. BACKEND SYNTAX"
if (Test-Path "server.js") {
  node --check "server.js"
  if ($LASTEXITCODE -eq 0) { Write-Output "PASS  server.js syntax check" }
  else { Write-Output "FAIL  server.js syntax check" }
}
if (Test-Path "public\app.js") {
  node --check "public\app.js"
  if ($LASTEXITCODE -eq 0) { Write-Output "PASS  public/app.js syntax check" }
  else { Write-Output "FAIL  public/app.js syntax check" }
}

Section "4. DEPENDENCIES / SECURITY ADVISORY"
if (Test-Path "node_modules") { Write-Output "PASS  node_modules exists" } else { Write-Output "WARN  node_modules missing; dependency audit may fail." }
if (Test-Path "package-lock.json") {
  Write-Output "PASS  package-lock.json exists"
  npm audit --json 2>$null | Out-File -FilePath (Join-Path $env:TEMP "spices-audit-$stamp.json") -Encoding utf8
  $auditFile = Join-Path $env:TEMP "spices-audit-$stamp.json"
  try {
    $audit = Get-Content $auditFile -Raw | ConvertFrom-Json
    if ($audit.metadata.vulnerabilities) {
      $v = $audit.metadata.vulnerabilities
      Write-Output ("npm audit counts: critical={0}, high={1}, moderate={2}, low={3}, info={4}" -f $v.critical,$v.high,$v.moderate,$v.low,$v.info)
      if ($v.critical -gt 0 -or $v.high -gt 0) { Write-Output "WARN  High/critical dependency advisories exist; review before production." }
      else { Write-Output "PASS  No high/critical advisories reported by npm audit." }
    } else { Write-Output "WARN  npm audit output had no vulnerability metadata; inspect npm audit manually." }
  } catch { Write-Output "WARN  npm audit JSON could not be summarized; run npm audit manually." }
  Remove-Item $auditFile -Force -ErrorAction SilentlyContinue
} else { Write-Output "WARN  package-lock.json missing; reproducible dependency audit is limited." }

Section "5. DATABASE FILE DISCOVERY (names and sizes only)"
$dbFiles = Get-ChildItem -Path . -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Extension -in @(".db",".sqlite",".sqlite3") -and $_.FullName -notmatch "\\node_modules\\" }
if ($dbFiles) {
  $dbFiles | ForEach-Object { "{0} | {1:N0} bytes" -f $_.FullName,$_.Length }
} else { Write-Output "WARN  No .db/.sqlite/.sqlite3 file found under project (database may be elsewhere or created at runtime)." }
Write-Output "NOTE  Finding a DB file does not prove integrity, schema correctness, or backup restorability."

Section "6. CONFIGURATION SAFETY (never print secret values)"
if (Test-Path ".env") {
  $envText = Get-Content ".env" -Raw
  foreach ($key in @("SESSION_SECRET","JWT_SECRET","COOKIE_SECRET","NODE_ENV","DATABASE_PATH","DB_PATH")) {
    if ($envText -match "(?m)^\s*$key\s*=\s*(.*?)\s*$") {
      $value = $Matches[1]
      if ($key -match "SECRET") {
        if ([string]::IsNullOrWhiteSpace($value) -or $value -match "change.?me|your.?secret|example|placeholder|^\w{1,8}$") {
          Write-Output "WARN  $key is present but may be empty/default/weak."
        } else { Write-Output "CHECK $key is set (value hidden; strength not cryptographically verified)." }
      } else {
        if ($key -eq "NODE_ENV" -and $value -ne "production") { Write-Output "CHECK NODE_ENV is '$value' (production deployment normally expects production)." }
        else { Write-Output "CHECK $key is set (value hidden if sensitive)." }
      }
    } else {
      if ($key -match "SECRET") { Write-Output "CHECK $key not found in .env; app may use another auth mechanism or config name." }
    }
  }
} else { Write-Output "WARN  .env missing. This may be okay if config is provided elsewhere, but verify secrets/configuration." }
if (Test-Path ".env.example") { Write-Output "PASS  .env.example exists" } else { Write-Output "CHECK .env.example not found" }
if (Test-Path ".gitignore") {
  $gitignore = Get-Content ".gitignore" -Raw
  if ($gitignore -match "(?m)^\s*\.env\s*$" -or $gitignore -match "(?m)^\s*\.env\*") { Write-Output "PASS  .gitignore appears to ignore .env" }
  else { Write-Output "WARN  .gitignore may not ignore .env; check before using Git/public repo." }
} else { Write-Output "WARN  .gitignore missing; ensure .env and database files are not committed." }

Section "7. STOREFRONT HOOKS / ROUTES (basic text checks only)"
if (Test-Path "public\index.html") {
  $html = Get-Content "public\index.html" -Raw
  foreach ($id in @("home","shop","product-grid","cart-open","checkout-form")) {
    if ($html -match "id\s*=\s*['""]$id['""]") { Write-Output "PASS  index.html contains id=$id" }
    else { Write-Output "CHECK index.html missing id=$id (may be generated dynamically or named differently)." }
  }
}
if (Test-Path "server.js") {
  $server = Get-Content "server.js" -Raw
  foreach ($pattern in @("helmet","express\.json","express\.urlencoded","rate.?limit","session|cookie","better-sqlite3|sqlite3","csrf")) {
    if ($server -match $pattern) { Write-Output "CHECK server.js contains pattern: $pattern (presence only, not proof of correct security)" }
    else { Write-Output "MANUAL server.js does not visibly match: $pattern (may be implemented elsewhere or unnecessary)" }
  }
}

Section "8. BACKUP FOLDERS"
$backupDirs = Get-ChildItem -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "backup|backups" }
if ($backupDirs) {
  Write-Output ("Found {0} backup-named folders (does not verify DB backup/restore)." -f $backupDirs.Count)
  $backupDirs | Select-Object -First 15 -ExpandProperty Name
} else { Write-Output "WARN  No backup-named folders found at project root." }

Section "9. MANUAL TESTS STILL REQUIRED"
Write-Output "MANUAL  Place a test order and confirm it appears in admin and persists after server restart."
Write-Output "MANUAL  Test invalid login, repeated login attempts, and admin routes while logged out."
Write-Output "MANUAL  Confirm payment provider is real/test-mode as intended; do not store raw card data."
Write-Output "MANUAL  Verify HTTPS, secure cookies, CSRF protection where applicable, and rate limiting before public launch."
Write-Output "MANUAL  Back up the actual DB file, then test restoring a copy—not the live DB."
Write-Output "MANUAL  Inspect SQL queries for parameterization and all user inputs for validation."

Section "END"
Write-Output "Report saved to: $report"
Write-Output "This is a preliminary static health report, not a penetration test or security certification."
Stop-Transcript | Out-Null
Write-Output ("Report complete: " + $report)
