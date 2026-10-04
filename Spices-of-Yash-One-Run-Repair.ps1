# Spices of Yash — one-run audit, safe repair, and verification
# Windows PowerShell 5.1+
# Makes backups; never uses npm audit fix --force; never edits .env or deletes the database.

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

function Section([string]$s) {
    Write-Host ""
    Write-Host ("=" * 68) -ForegroundColor DarkCyan
    Write-Host $s -ForegroundColor Cyan
    Write-Host ("=" * 68) -ForegroundColor DarkCyan
}
function AuditCount([string]$path) {
    try {
        if (!(Test-Path -LiteralPath $path)) { return $null }
        $o = (Get-Content -LiteralPath $path -Raw) | ConvertFrom-Json
        return [int]$o.metadata.vulnerabilities.total
    } catch { return $null }
}
function AuditSummary([string]$path, [string]$label) {
    Write-Host $label -ForegroundColor Yellow
    try {
        $v = ((Get-Content -LiteralPath $path -Raw) | ConvertFrom-Json).metadata.vulnerabilities
        Write-Host ("Total {0} | Critical {1} | High {2} | Moderate {3} | Low {4}" -f $v.total,$v.critical,$v.high,$v.moderate,$v.low)
    } catch { Write-Host "Could not parse audit output. See report files." -ForegroundColor Red }
}
function RunNpm([string]$argsText, [string]$outFile, [string]$errFile) {
    $line = "npm $argsText 1> `"$outFile`" 2> `"$errFile`""
    & $env:ComSpec /d /s /c $line
    return $LASTEXITCODE
}

Section "SPICES OF YASH — ONE-RUN SAFE REPAIR + TESTS"
$default = 'D:\Project\Spices-of-Yash-Complete-Local-Project (1)\spices-of-yash-store'
$project = Read-Host "Full path to spices-of-yash-store (Enter for default path)"
if ([string]::IsNullOrWhiteSpace($project)) { $project = $default }
$project = $project.Trim().Trim('"')
if (!(Test-Path -LiteralPath (Join-Path $project 'package.json'))) {
    Write-Host "ERROR: package.json not found: $project" -ForegroundColor Red
    Read-Host "Press Enter to close"; exit 1
}
$lock = Join-Path $project 'package-lock.json'
$shrink = Join-Path $project 'npm-shrinkwrap.json'
if (!(Test-Path -LiteralPath $lock) -and !(Test-Path -LiteralPath $shrink)) {
    Write-Host "ERROR: package-lock.json/npm-shrinkwrap.json missing. Stopping safely." -ForegroundColor Red
    Read-Host "Press Enter to close"; exit 1
}
Set-Location -LiteralPath $project
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $project ".one-run-backup-$stamp"
$reports = Join-Path $project "one-run-report-$stamp"
New-Item -ItemType Directory -Path $backup,$reports -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $project 'package.json') -Destination $backup
if (Test-Path -LiteralPath $lock) { Copy-Item -LiteralPath $lock -Destination $backup }
if (Test-Path -LiteralPath $shrink) { Copy-Item -LiteralPath $shrink -Destination $backup }

# Backup common SQLite file locations, without changing the database.
$dbCandidates = @(
    (Join-Path $project 'data\store.sqlite'),
    (Join-Path $project 'data\store.db'),
    (Join-Path $project 'store.sqlite'),
    (Join-Path $project 'store.db')
)
foreach ($db in $dbCandidates) {
    if (Test-Path -LiteralPath $db -PathType Leaf) {
        Copy-Item -LiteralPath $db -Destination $backup
        foreach ($sidecar in @("$db-wal","$db-shm")) {
            if (Test-Path -LiteralPath $sidecar) { Copy-Item -LiteralPath $sidecar -Destination $backup }
        }
    }
}
$transcript = Join-Path $reports 'run-log.txt'
Start-Transcript -Path $transcript -Force | Out-Null
$pkg = Get-Content -LiteralPath (Join-Path $project 'package.json') -Raw | ConvertFrom-Json
Write-Host "Project: $project"
Write-Host "Backup: $backup"
Write-Host "Reports: $reports"
Write-Host "Stop the running website server with Ctrl+C in its own terminal before proceeding."

Section "STEP 1 — Initial dependency audit"
$initial = Join-Path $reports 'audit-initial.json'
$null = RunNpm 'audit --json' $initial (Join-Path $reports 'audit-initial-stderr.txt')
$before = AuditCount $initial
AuditSummary $initial 'Initial full audit:'
$rounds = 0
$stopReason = ''
if ($null -eq $before) {
    $stopReason = 'Initial audit could not be parsed; skipped automatic dependency changes.'
} elseif ($before -eq 0) {
    $stopReason = 'Initial audit found zero vulnerabilities; no fix required.'
} else {
    Section "STEP 2 — Safe repair loop (maximum 3 attempts; never --force)"
    $current = $before
    for ($i=1; $i -le 3; $i++) {
        $rounds = $i
        Write-Host "Attempt $i/3: running ordinary npm audit fix..."
        $fixOut = Join-Path $reports "fix-$i-output.txt"
        $fixErr = Join-Path $reports "fix-$i-stderr.txt"
        $fixExit = RunNpm 'audit fix' $fixOut $fixErr
        Write-Host "npm audit fix exit code: $fixExit"
        Get-Content -LiteralPath $fixOut -Tail 14 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ }
        Get-Content -LiteralPath $fixErr -Tail 8 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ }
        $afterPath = Join-Path $reports "audit-after-$i.json"
        $null = RunNpm 'audit --json' $afterPath (Join-Path $reports "audit-after-$i-stderr.txt")
        $after = AuditCount $afterPath
        AuditSummary $afterPath ("Audit after attempt {0}:" -f $i)
        if ($null -eq $after) { $stopReason='Could not parse a follow-up audit; stopped safely.'; break }
        if ($after -eq 0) { $current=0; $stopReason='Full audit reports zero vulnerabilities.'; break }
        if ($after -ge $current) { $current=$after; $stopReason='Normal fix made no further progress; stopped to avoid forced/major upgrades.'; break }
        $current=$after
        $stopReason='Vulnerability count improved; continuing with another safe pass.'
    }
    if ($rounds -eq 3 -and $current -gt 0) { $stopReason='Reached safe repair limit; remaining issues need targeted dependency changes.' }
}

Section "STEP 3 — JavaScript syntax checks"
$syntaxFailures = 0
foreach ($rel in @('server.js','public\app.js')) {
    $file = Join-Path $project $rel
    if (Test-Path -LiteralPath $file -PathType Leaf) {
        Write-Host "Checking $rel ..."
        $out = & node --check $file 2>&1
        $code = $LASTEXITCODE
        $out | ForEach-Object { Write-Host $_ }
        if ($code -eq 0) { Write-Host "PASS: $rel" -ForegroundColor Green }
        else { $syntaxFailures++; Write-Host "FAIL: $rel" -ForegroundColor Red }
    } else { Write-Host "SKIP: $rel not found" }
}

Section "STEP 4 — Project test suite"
$testStatus = 'SKIPPED — no test script in package.json'
if ($pkg.scripts -and $pkg.scripts.test) {
    $testOut = Join-Path $reports 'npm-test-output.txt'
    $testErr = Join-Path $reports 'npm-test-stderr.txt'
    $testCode = RunNpm 'test' $testOut $testErr
    Get-Content -LiteralPath $testOut -Tail 35 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ }
    Get-Content -LiteralPath $testErr -Tail 12 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ }
    if ($testCode -eq 0) { $testStatus='PASS'; Write-Host 'npm test: PASS' -ForegroundColor Green }
    else { $testStatus="FAIL (exit code $testCode)"; Write-Host 'npm test: FAIL' -ForegroundColor Red }
} else {
    Write-Host "No test script exists in package.json; syntax checks and audits still run."
}

Section "STEP 5 — Production-only audit"
$prod = Join-Path $reports 'audit-production.json'
$null = RunNpm 'audit --omit=dev --json' $prod (Join-Path $reports 'audit-production-stderr.txt')
AuditSummary $prod 'Production dependency audit:'
$prodCount = AuditCount $prod

Section "STEP 6 — Read-only SQLite integrity check (if available)"
$dbPath = $null
foreach ($candidate in $dbCandidates) { if (Test-Path -LiteralPath $candidate -PathType Leaf) { $dbPath=$candidate; break } }
$dbStatus = 'SKIPPED — database file not found in common locations'
if ($dbPath -and (Test-Path -LiteralPath (Join-Path $project 'node_modules\sqlite3'))) {
    $js = 'const s=require("sqlite3").verbose();const p=process.argv[1];const d=new s.Database(p,s.OPEN_READONLY,e=>{if(e){console.error(e.message);process.exit(2)}d.get("PRAGMA integrity_check",(x,r)=>{if(x){console.error(x.message);d.close();process.exit(3)}console.log(r.integrity_check);d.close(()=>process.exit(r.integrity_check==="ok"?0:4))})})'
    $dbOut = & node -e $js $dbPath 2>&1
    $dbCode = $LASTEXITCODE
    $dbOut | ForEach-Object { Write-Host $_ }
    if ($dbCode -eq 0) { $dbStatus='PASS — SQLite integrity_check = ok'; Write-Host $dbStatus -ForegroundColor Green }
    else { $dbStatus="FAIL (exit code $dbCode)"; Write-Host $dbStatus -ForegroundColor Red }
} elseif ($dbPath) { $dbStatus='SKIPPED — sqlite3 Node module not installed'; Write-Host $dbStatus }
else { Write-Host $dbStatus }

Section "STEP 7 — Final full audit"
$final = Join-Path $reports 'audit-final.json'
$null = RunNpm 'audit --json' $final (Join-Path $reports 'audit-final-stderr.txt')
$finalCount = AuditCount $final
AuditSummary $final 'Final full dependency audit:'
$security = if ($finalCount -eq 0 -and $prodCount -eq 0) { 'CLEAN according to npm audit' } else { 'NOT CLEAN — do not deploy publicly until remaining findings are resolved' }
$summary = @(
    'SPICES OF YASH — ONE-RUN REPORT',
    "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "Project: $project",
    "Backup folder: $backup",
    "Report folder: $reports",
    "Initial vulnerability count: $before",
    "Final full audit count: $finalCount",
    "Final production audit count: $prodCount",
    "Safe repair attempts: $rounds",
    "Repair stop reason: $stopReason",
    "Syntax failures: $syntaxFailures",
    "npm test: $testStatus",
    "SQLite check: $dbStatus",
    "Security status: $security",
    'Note: npm audit and syntax/tests do not replace browser checkout/UI testing.'
)
$summary | Set-Content -LiteralPath (Join-Path $reports 'FINAL-SUMMARY.txt') -Encoding UTF8
Write-Host ""
$summary | ForEach-Object { Write-Host $_ }
Write-Host "`nDetailed logs, audit JSON files, and backups are saved in the project folder." -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host 'All steps finished. Press Enter to close'
