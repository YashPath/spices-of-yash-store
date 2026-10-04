$ErrorActionPreference = "Continue"
$script:Failures = 0
$script:Warnings = 0
$root = (Get-Location).Path

function Pass($message) { Write-Host "PASS  $message" -ForegroundColor Green }
function Fail($message) { Write-Host "FAIL  $message" -ForegroundColor Red; $script:Failures++ }
function Warn($message) { Write-Host "WARN  $message" -ForegroundColor Yellow; $script:Warnings++ }

Write-Host "`n=== SPICES OF YASH: PRE-LAUNCH AUDIT v2 ===" -ForegroundColor Cyan
Write-Host "Project: $root"

if (!(Test-Path ".\package.json") -or !(Test-Path ".\server.js")) {
    Write-Host "Run this script from the spices-of-yash-store project folder." -ForegroundColor Red
    exit 2
}
if (!(Test-Path ".\data\store.sqlite")) {
    Fail "Database file data\store.sqlite not found"
    Write-Host "`nAudit stopped. No database changes were made." -ForegroundColor Red
    exit 1
}
if (!(Test-Path ".\node_modules\better-sqlite3")) {
    Fail "better-sqlite3 is not installed in this project"
    Write-Host "`nAudit stopped. No database changes were made." -ForegroundColor Red
    exit 1
}

# Create a consistent SQLite backup using a temporary JS file. This avoids
# fragile nested quoting in `node -e` commands on Windows.
$jsPath = Join-Path $root ".prelaunch-backup-temp.cjs"
$js = @'
const fs = require("fs");
const path = require("path");
const Database = require("better-sqlite3");
(async () => {
  const source = path.resolve("data/store.sqlite");
  if (!fs.existsSync(source)) throw new Error("Database file not found");
  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  const target = path.resolve("data", `prelaunch-backup-${stamp}.sqlite`);
  const db = new Database(source, { readonly: true, fileMustExist: true });
  try {
    await db.backup(target);
  } finally {
    db.close();
  }
  const backup = new Database(target, { readonly: true, fileMustExist: true });
  try {
    const integrity = backup.pragma("integrity_check");
    const fk = backup.pragma("foreign_key_check");
    console.log("BACKUP_PATH=" + target);
    console.log("BACKUP_INTEGRITY=" + JSON.stringify(integrity));
    console.log("BACKUP_FOREIGN_KEYS=" + JSON.stringify(fk));
    if (integrity.length !== 1 || integrity[0].integrity_check !== "ok" || fk.length !== 0) process.exitCode = 1;
  } finally {
    backup.close();
  }
})().catch(err => { console.error("BACKUP_ERROR=" + err.message); process.exitCode = 1; });
'@

try {
    Set-Content -LiteralPath $jsPath -Value $js -Encoding UTF8
    Write-Host "`n--- Consistent database backup + integrity ---" -ForegroundColor Cyan
    $backupOutput = & node $jsPath 2>&1
    $backupExit = $LASTEXITCODE
    $backupOutput | ForEach-Object { Write-Host $_ }
    if ($backupExit -eq 0) {
        Pass "Database backup created and verified"
    } else {
        Fail "Backup/integrity check failed; stopping before other checks"
        Write-Host "Original database was not intentionally modified." -ForegroundColor Yellow
        exit 1
    }
} finally {
    if (Test-Path $jsPath) { Remove-Item -LiteralPath $jsPath -Force -ErrorAction SilentlyContinue }
}

Write-Host "`n--- Code and automated tests ---" -ForegroundColor Cyan
& node --check ".\server.js"
if ($LASTEXITCODE -eq 0) { Pass "server.js syntax" } else { Fail "server.js syntax" }

& npm test
if ($LASTEXITCODE -eq 0) { Pass "npm test" } else { Fail "npm test" }

if (Test-Path ".\scripts\db-audit.js") {
    & node ".\scripts\db-audit.js"
    if ($LASTEXITCODE -eq 0) { Pass "Read-only database audit script" } else { Fail "Read-only database audit script" }
} else {
    Warn "scripts\db-audit.js not found; built-in backup integrity check was still run"
}

Write-Host "`n--- Production configuration (values are not printed) ---" -ForegroundColor Cyan
if (Test-Path ".\.env") {
    Pass ".env file exists"
    $envText = Get-Content ".\.env" -Raw
    if ($envText -match '(?m)^\s*NODE_ENV\s*=\s*development\s*$') {
        Warn "NODE_ENV is development; use production configuration before public launch"
    }
    if ($envText -match '(?m)^\s*COOKIE_SECURE\s*=\s*false\s*$') {
        Warn "COOKIE_SECURE=false; production should use HTTPS and secure cookies"
    }
    if ($envText -match '(?m)^\s*SESSION_SECRET\s*=\s*(change-me|secret|your-secret|)$') {
        Warn "SESSION_SECRET appears blank or a placeholder; set a unique strong secret before launch"
    }
} else {
    Warn ".env file not found"
}

Write-Host "`n--- Live local HTTP checks ---" -ForegroundColor Cyan
$base = "http://localhost:3000"
try {
    $storeResponse = Invoke-WebRequest -Uri "$base/" -UseBasicParsing -TimeoutSec 5
    if ($storeResponse.StatusCode -eq 200) { Pass "Storefront responds HTTP 200" }
    else { Fail "Storefront returned HTTP $($storeResponse.StatusCode)" }
} catch {
    Warn "Storefront unavailable at localhost:3000; start the server and rerun for live checks"
}

try {
    $adminResponse = Invoke-WebRequest -Uri "$base/admin" -UseBasicParsing -TimeoutSec 5
    if ($adminResponse.StatusCode -eq 200) { Pass "Admin page responds HTTP 200" }
    else { Warn "Admin page returned HTTP $($adminResponse.StatusCode)" }
} catch {
    if ($_.Exception.Response) { Warn "Admin page returned HTTP $([int]$_.Exception.Response.StatusCode)" }
    else { Warn "Could not reach admin page at localhost:3000" }
}

foreach ($endpoint in @("/api/admin/products", "/api/admin/orders", "/api/admin/coupons")) {
    try {
        $r = Invoke-WebRequest -Uri "$base$endpoint" -UseBasicParsing -TimeoutSec 5 -MaximumRedirection 0
        if ($r.StatusCode -eq 200) {
            Warn "$endpoint returned HTTP 200 without a login session; review whether this route is properly protected"
        } else {
            Pass "$endpoint returned HTTP $($r.StatusCode)"
        }
    } catch {
        $status = $null
        try { $status = [int]$_.Exception.Response.StatusCode } catch {}
        if ($status -in @(301,302,303,307,308,401,403)) {
            Pass "$endpoint blocks/redirects unauthenticated access (HTTP $status)"
        } elseif ($status -eq 404) {
            Warn "$endpoint not found (HTTP 404); route may use a different path"
        } elseif ($null -ne $status) {
            Warn "$endpoint returned HTTP $status; review response"
        } else {
            Warn "$endpoint could not be checked; server may be stopped"
        }
    }
}

Write-Host "`n--- Production dependency audit ---" -ForegroundColor Cyan
Write-Host "Running npm audit for production dependencies; network access may be required."
& npm audit --omit=dev --audit-level=high
if ($LASTEXITCODE -eq 0) { Pass "No high/critical production dependency advisories reported by npm audit" }
else { Warn "npm audit reported advisories or could not complete; review its output before public launch" }

Write-Host "`n=== AUDIT SUMMARY ===" -ForegroundColor Cyan
Write-Host "Failures: $script:Failures"
Write-Host "Warnings: $script:Warnings"
Write-Host "Note: this is an automated pre-launch check, not a full penetration test or browser checkout test."
if ($script:Failures -gt 0) {
    Write-Host "Result: FIX FAILURES BEFORE LAUNCH" -ForegroundColor Red
    exit 1
} elseif ($script:Warnings -gt 0) {
    Write-Host "Result: REVIEW WARNINGS BEFORE PUBLIC LAUNCH" -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "Result: AUTOMATED CHECKS PASSED; perform final manual launch checks" -ForegroundColor Green
    exit 0
}
