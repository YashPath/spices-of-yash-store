# Spices of Yash — one-run dependency repair + checks
# Windows PowerShell 5.1+ | No --force | Does not edit .env or database contents.

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "SPICES OF YASH — ONE-RUN REPAIR + VERIFICATION" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$defaultProject = 'D:\Project\Spices-of-Yash-Complete-Local-Project (1)\spices-of-yash-store'
$project = Read-Host "Project path (press Enter to use: $defaultProject)"
if ([string]::IsNullOrWhiteSpace($project)) { $project = $defaultProject }
$project = $project.Trim().Trim('"')

if (!(Test-Path -LiteralPath (Join-Path $project 'package.json'))) {
    Write-Host "ERROR: package.json not found at: $project" -ForegroundColor Red
    Read-Host 'Press Enter to close'
    exit 1
}
if (!(Test-Path -LiteralPath (Join-Path $project 'package-lock.json'))) {
    Write-Host 'ERROR: package-lock.json not found. Stopping without changes.' -ForegroundColor Red
    Read-Host 'Press Enter to close'
    exit 1
}

Set-Location -LiteralPath $project
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $project ".one-run-v2-backup-$stamp"
$reports = Join-Path $project "one-run-v2-report-$stamp"
New-Item -ItemType Directory -Path $backup,$reports -Force | Out-Null
Copy-Item -LiteralPath '.\package.json' -Destination $backup
Copy-Item -LiteralPath '.\package-lock.json' -Destination $backup
$log = Join-Path $reports 'run-log.txt'
Start-Transcript -Path $log -Force | Out-Null

function Invoke-NpmLogged {
    param([string[]]$NpmArgs, [string]$LogName)
    $logFile = Join-Path $reports $LogName
    Write-Host "`n> npm $($NpmArgs -join ' ')" -ForegroundColor Yellow
    & npm @NpmArgs 2>&1 | Tee-Object -FilePath $logFile
    return $LASTEXITCODE
}

function Save-Audit {
    param([string]$Name)
    $out = Join-Path $reports "$Name.json"
    $err = Join-Path $reports "$Name-stderr.txt"
    $line = 'npm audit --json 1> "' + $out + '" 2> "' + $err + '"'
    & $env:ComSpec /d /s /c $line
    return $out
}

function Get-AuditSummary {
    param([string]$Path)
    try {
        $a = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        $v = $a.metadata.vulnerabilities
        return ("Total {0} | Critical {1} | High {2} | Moderate {3} | Low {4}" -f $v.total,$v.critical,$v.high,$v.moderate,$v.low)
    } catch {
        return 'Could not parse npm audit JSON; inspect the report file.'
    }
}

try {
    Write-Host "`nProject: $project"
    Write-Host "Backup:  $backup"
    Write-Host "Reports: $reports"

    Write-Host "`n[1/7] Initial dependency audit" -ForegroundColor Cyan
    $initial = Save-Audit 'audit-initial'
    Write-Host (Get-AuditSummary $initial)

    Write-Host "`n[2/7] Check whether sqlite3 is used by project source" -ForegroundColor Cyan
    $pkg = Get-Content -LiteralPath '.\package.json' -Raw | ConvertFrom-Json
    $sqlite3Direct = $false
    if (($pkg.dependencies -and $pkg.dependencies.sqlite3) -or ($pkg.devDependencies -and $pkg.devDependencies.sqlite3)) {
        $sqlite3Direct = $true
    }

    $sourceFiles = Get-ChildItem -LiteralPath $project -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -in '.js','.cjs','.mjs','.ts' -and
            $_.FullName -notmatch '\\node_modules\\|\\.one-run-|\\one-run-v2-report-'
        }
    $sqlite3Refs = @($sourceFiles | Select-String -Pattern "require\s*\(\s*['""]sqlite3['""]\s*\)|from\s+['""]sqlite3['""]|import\s*\(\s*['""]sqlite3['""]\s*\)" -ErrorAction SilentlyContinue)

    if ($sqlite3Direct -and $sqlite3Refs.Count -eq 0) {
        Write-Host 'sqlite3 is a direct dependency but no static source import was found.' -ForegroundColor Yellow
        Write-Host 'Removing this apparently unused dependency; package.json/lockfile are backed up.' -ForegroundColor Yellow
        $uninstallCode = Invoke-NpmLogged -NpmArgs @('uninstall','sqlite3') -LogName 'npm-uninstall-sqlite3.txt'
        if ($uninstallCode -ne 0) {
            Write-Host 'Uninstall did not complete. Continuing with safe npm audit fix only.' -ForegroundColor Yellow
        }
    } elseif ($sqlite3Direct -and $sqlite3Refs.Count -gt 0) {
        Write-Host 'sqlite3 is referenced in source; attempting its current published version, then tests will verify compatibility.' -ForegroundColor Yellow
        $upgradeCode = Invoke-NpmLogged -NpmArgs @('install','sqlite3@latest') -LogName 'npm-update-sqlite3.txt'
        if ($upgradeCode -ne 0) { Write-Host 'sqlite3 update failed; continuing with normal audit fix.' -ForegroundColor Yellow }
    } else {
        Write-Host 'sqlite3 is not a direct package.json dependency; no sqlite3 removal attempted.'
    }

    Write-Host "`n[3/7] Apply compatible npm security fixes (never --force)" -ForegroundColor Cyan
    $fixCode = Invoke-NpmLogged -NpmArgs @('audit','fix') -LogName 'npm-audit-fix.txt'
    Write-Host "npm audit fix exit code: $fixCode"

    Write-Host "`n[4/7] JavaScript syntax checks" -ForegroundColor Cyan
    $syntaxFailures = 0
    foreach ($rel in @('server.js','public\app.js')) {
        if (Test-Path -LiteralPath $rel -PathType Leaf) {
            Write-Host "> node --check $rel"
            & node --check $rel
            if ($LASTEXITCODE -eq 0) { Write-Host "PASS: $rel" -ForegroundColor Green }
            else { Write-Host "FAIL: $rel" -ForegroundColor Red; $syntaxFailures++ }
        } else {
            Write-Host "SKIP: $rel not found" -ForegroundColor DarkYellow
        }
    }

    Write-Host "`n[5/7] Project tests" -ForegroundColor Cyan
    $pkgNow = Get-Content -LiteralPath '.\package.json' -Raw | ConvertFrom-Json
    $testStatus = 'SKIPPED — no test script in package.json'
    if ($pkgNow.scripts -and $pkgNow.scripts.test) {
        $testCode = Invoke-NpmLogged -NpmArgs @('test') -LogName 'npm-test.txt'
        if ($testCode -eq 0) { $testStatus = 'PASS'; Write-Host 'npm test: PASS' -ForegroundColor Green }
        else { $testStatus = "FAIL (exit code $testCode)"; Write-Host 'npm test: FAIL' -ForegroundColor Red }
    } else {
        Write-Host $testStatus -ForegroundColor Yellow
    }

    if ($syntaxFailures -gt 0 -or $testStatus -like 'FAIL*') {
        Write-Host "`nA syntax check or project test failed. Restoring package.json/package-lock.json and reinstalling the original dependency tree..." -ForegroundColor Red
        Copy-Item -LiteralPath (Join-Path $backup 'package.json') -Destination (Join-Path $project 'package.json') -Force
        Copy-Item -LiteralPath (Join-Path $backup 'package-lock.json') -Destination (Join-Path $project 'package-lock.json') -Force
        $restoreCode = Invoke-NpmLogged -NpmArgs @('install') -LogName 'npm-restore-original-dependencies.txt'
        if ($restoreCode -eq 0) {
            Write-Host 'Original package files restored and npm install completed.' -ForegroundColor Yellow
            $testStatus = "$testStatus; dependency changes rolled back"
        } else {
            Write-Host 'WARNING: package files restored, but npm install did not complete. See restore log.' -ForegroundColor Red
            $testStatus = "$testStatus; package files restored but dependency reinstall failed"
        }
    }

    Write-Host "`n[6/7] Read-only SQLite integrity check (uses better-sqlite3, avoids PowerShell quote corruption)" -ForegroundColor Cyan
    $dbPath = Join-Path $project 'data\store.sqlite'
    $dbStatus = 'SKIPPED — data\store.sqlite not found'
    if ((Test-Path -LiteralPath $dbPath -PathType Leaf) -and (Test-Path -LiteralPath '.\node_modules\better-sqlite3')) {
        $checkJs = Join-Path $reports 'sqlite-integrity-check.cjs'
        $checkSource = @'
const Database = require("better-sqlite3");
const dbPath = process.argv[2];
let db;
try {
  db = new Database(dbPath, { readonly: true, fileMustExist: true });
  const result = db.pragma("integrity_check", { simple: true });
  console.log("SQLite integrity_check:", result);
  db.close();
  process.exit(result === "ok" ? 0 : 1);
} catch (error) {
  console.error("SQLite check error:", error.message);
  try { if (db) db.close(); } catch {}
  process.exit(2);
}
'@
        Set-Content -LiteralPath $checkJs -Value $checkSource -Encoding UTF8
        & node $checkJs $dbPath
        if ($LASTEXITCODE -eq 0) { $dbStatus = 'PASS — SQLite integrity_check = ok'; Write-Host $dbStatus -ForegroundColor Green }
        else { $dbStatus = "FAIL (exit code $LASTEXITCODE)"; Write-Host $dbStatus -ForegroundColor Red }
    } elseif (!(Test-Path -LiteralPath $dbPath -PathType Leaf)) {
        Write-Host $dbStatus -ForegroundColor Yellow
    } else {
        $dbStatus = 'SKIPPED — better-sqlite3 module not installed'
        Write-Host $dbStatus -ForegroundColor Yellow
    }

    Write-Host "`n[7/7] Final full and production dependency audits" -ForegroundColor Cyan
    $final = Save-Audit 'audit-final'
    $prod = Join-Path $reports 'audit-production.json'
    $prodErr = Join-Path $reports 'audit-production-stderr.txt'
    $prodLine = 'npm audit --omit=dev --json 1> "' + $prod + '" 2> "' + $prodErr + '"'
    & $env:ComSpec /d /s /c $prodLine
    $finalSummary = Get-AuditSummary $final
    $prodSummary = Get-AuditSummary $prod
    Write-Host "Full audit:       $finalSummary"
    Write-Host "Production audit: $prodSummary"

    $fullCount = $null
    $prodCount = $null
    try { $fullCount = [int]((Get-Content -LiteralPath $final -Raw | ConvertFrom-Json).metadata.vulnerabilities.total) } catch {}
    try { $prodCount = [int]((Get-Content -LiteralPath $prod -Raw | ConvertFrom-Json).metadata.vulnerabilities.total) } catch {}
    $security = if ($fullCount -eq 0 -and $prodCount -eq 0) { 'CLEAN according to npm audit' } else { 'NOT CLEAN — do not deploy publicly yet' }

    $summary = @(
        'SPICES OF YASH — ONE-RUN V2 REPORT',
        "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "Project: $project",
        "Backup folder: $backup",
        "Report folder: $reports",
        "Initial audit: $(Get-AuditSummary $initial)",
        "Final full audit: $finalSummary",
        "Final production audit: $prodSummary",
        "npm audit fix exit code: $fixCode",
        "Syntax failures: $syntaxFailures",
        "npm test: $testStatus",
        "SQLite check: $dbStatus",
        "Security status: $security",
        'No npm audit fix --force was used.',
        'This script does not edit .env or modify database contents.'
    )
    $summary | Set-Content -LiteralPath (Join-Path $reports 'FINAL-SUMMARY.txt') -Encoding UTF8
    Write-Host "`n============================================================" -ForegroundColor Cyan
    $summary | ForEach-Object { Write-Host $_ }
    Write-Host "`nDetailed logs and audit JSON are in: $reports" -ForegroundColor Cyan
    Write-Host 'If audit still reports vulnerabilities, do not deploy publicly; the report identifies the remaining dependency chain.' -ForegroundColor Yellow
}
catch {
    Write-Host "`nUNEXPECTED SCRIPT ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Your original package.json and package-lock.json copies are in: $backup" -ForegroundColor Yellow
}
finally {
    try { Stop-Transcript | Out-Null } catch {}
}
Read-Host 'Run finished. Press Enter to close'
