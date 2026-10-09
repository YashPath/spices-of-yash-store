# Spices of Yash - Landing V7 Cinematic Section Cleanup
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$index = Join-Path $root "public\index.html"
$css = Join-Path $root "public\styles.css"
if (!(Test-Path $index)) { throw "public\index.html not found." }
if (!(Test-Path $css)) { throw "public\styles.css not found." }
$html = Get-Content $index -Raw
$styles = Get-Content $css -Raw

foreach ($marker in @('id="product-grid"','id="cart-open"','id="checkout-form"','id="home"','sy-v3-hero','sy-v5-3d-interaction')) {
  if ($html.IndexOf($marker,[StringComparison]::OrdinalIgnoreCase) -lt 0) { throw "Safety check failed: $marker not found. Nothing changed." }
}

$pattern = '(?s)<!--\s*SPICES OF YASH FINAL CINEMATIC UI START\s*-->.*?<!--\s*SPICES OF YASH FINAL CINEMATIC UI END\s*-->'
$m = [regex]::Matches($html,$pattern)
if ($m.Count -ne 1) { throw "Expected exactly one existing cinematic ticker block. Found $($m.Count). Nothing changed." }

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = Join-Path $root "landing-v7-backup-$stamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Copy-Item $index (Join-Path $backupDir "index.html")
Copy-Item $css (Join-Path $backupDir "styles.css")

$ticker = @'
<!-- SPICES OF YASH FINAL CINEMATIC UI START -->
<div class="sy-v7-ticker" aria-label="Spices of Yash flavour categories">
  <div class="sy-v7-ticker-track">
    <span>AUTHENTIC INDIAN FLAVOUR</span><b aria-hidden="true">•</b>
    <span>WHOLE SPICES</span><b aria-hidden="true">•</b>
    <span>GROUND SPICES</span><b aria-hidden="true">•</b>
    <span>SIGNATURE BLENDS</span><b aria-hidden="true">•</b>
    <span>AUTHENTIC INDIAN FLAVOUR</span><b aria-hidden="true">•</b>
    <span>WHOLE SPICES</span><b aria-hidden="true">•</b>
    <span>GROUND SPICES</span><b aria-hidden="true">•</b>
    <span>SIGNATURE BLENDS</span><b aria-hidden="true">•</b>
  </div>
</div>
<!-- SPICES OF YASH FINAL CINEMATIC UI END -->
'@

$html = [regex]::Replace($html,$pattern,$ticker,1)

$cssBlock = @'

/* SPICES OF YASH - V7 CINEMATIC SECTION CLEANUP */
.sy-v3-hero{z-index:1;overflow:hidden;}
.sy-v3-inner{padding-top:96px;}
.sy-v3-product{padding-top:18px;}
.sy-v3-card{z-index:2;}

.sy-v7-ticker{
  position:relative;
  z-index:3;
  width:100%;
  overflow:hidden;
  border-top:1px solid rgba(217,155,70,.22);
  border-bottom:1px solid rgba(217,155,70,.22);
  background:#0c0907;
  color:#d9ad61;
}
.sy-v7-ticker-track{
  width:max-content;
  min-width:100%;
  display:flex;
  align-items:center;
  gap:24px;
  padding:13px 0;
  animation:syV7Ticker 32s linear infinite;
  will-change:transform;
}
.sy-v7-ticker span{
  white-space:nowrap;
  font:700 9px/1.2 "DM Mono",monospace;
  letter-spacing:.16em;
}
.sy-v7-ticker b{
  font:700 10px/1 "DM Mono",monospace;
  color:#9b542f;
}
@keyframes syV7Ticker{
  from{transform:translateX(0)}
  to{transform:translateX(-25%)}
}
@media (prefers-reduced-motion:reduce){.sy-v7-ticker-track{animation:none;}}
@media (max-width:900px){
  .sy-v3-inner{padding-top:78px;}
  .sy-v7-ticker-track{gap:18px;padding:11px 0;}
}
'@
if ($styles -notmatch 'SPICES OF YASH - V7 CINEMATIC SECTION CLEANUP') { $styles += $cssBlock }

try {
  Set-Content $index $html -Encoding UTF8
  Set-Content $css $styles -Encoding UTF8
  $check = Get-Content $index -Raw
  foreach ($marker in @('id="product-grid"','id="cart-open"','id="checkout-form"','id="home"','sy-v3-hero','sy-v5-3d-interaction','sy-v7-ticker')) {
    if ($check.IndexOf($marker,[StringComparison]::OrdinalIgnoreCase) -lt 0) { throw "Post-write validation failed: $marker missing." }
  }
  if ([regex]::Matches($check,'class="sy-final-ticker"').Count -gt 0) { throw "Post-write validation failed: old ticker still present." }
  Write-Host ""
  Write-Host "SUCCESS: Landing V7 cinematic cleanup applied." -ForegroundColor Green
  Write-Host "Backup: $backupDir" -ForegroundColor Cyan
  Write-Host "Changed only: public/index.html and public/styles.css" -ForegroundColor Yellow
  Write-Host "Backend/database/.env/app.js/admin/cart/checkout were NOT modified." -ForegroundColor Green
} catch {
  Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "Restoring backup..." -ForegroundColor Yellow
  Copy-Item (Join-Path $backupDir "index.html") $index -Force
  Copy-Item (Join-Path $backupDir "styles.css") $css -Force
  Write-Host "RESTORED. V7 changes were not kept." -ForegroundColor Green
  throw
}
