# Spices of Yash — Encoding Cleanup V1
# Frontend-only. Cleans common mojibake in public/index.html and public/styles.css.
# Creates a backup and restores automatically if validation fails.

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$index = Join-Path $root "public\index.html"
$css   = Join-Path $root "public\styles.css"

if (!(Test-Path $index)) { throw "public\index.html not found." }
if (!(Test-Path $css))   { throw "public\styles.css not found." }

$html = Get-Content $index -Raw
$styles = Get-Content $css -Raw

foreach ($marker in @('id="product-grid"','id="cart-open"','id="checkout-form"','id="home"')) {
  if ($html.IndexOf($marker, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
    throw "Safety check failed: $marker not found. Nothing changed."
  }
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = Join-Path $root "encoding-cleanup-backup-$stamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Copy-Item $index (Join-Path $backupDir "index.html")
Copy-Item $css   (Join-Path $backupDir "styles.css")

# Use HTML entities where possible so the source remains ASCII-safe.
$replacements = [ordered]@{
  'Â·'     = '&middot;'
  'â€¢'    = '&bull;'
  'â†’'    = '&rarr;'
  'â†'    = '&larr;'
  'â†‘'    = '&uarr;'
  'â†“'    = '&darr;'
  'â€”'    = '&mdash;'
  'â€“'    = '&ndash;'
  'â€¦'    = '&hellip;'
  'â€™'    = '&rsquo;'
  'â€˜'    = '&lsquo;'
  'â€œ'    = '&ldquo;'
  'â€'    = '&rdquo;'
  'â€œ'    = '&ldquo;'
  'Â'      = ''
}

foreach ($key in $replacements.Keys) {
  $html = $html.Replace($key, $replacements[$key])
  $styles = $styles.Replace($key, $replacements[$key])
}

try {
  Set-Content -Path $index -Value $html -Encoding UTF8
  Set-Content -Path $css -Value $styles -Encoding UTF8

  $check = Get-Content $index -Raw
  foreach ($marker in @('id="product-grid"','id="cart-open"','id="checkout-form"','id="home"')) {
    if ($check.IndexOf($marker, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
      throw "Post-write validation failed: $marker missing."
    }
  }

  Write-Host ""
  Write-Host "SUCCESS: Encoding cleanup applied." -ForegroundColor Green
  Write-Host "Backup: $backupDir" -ForegroundColor Cyan
  Write-Host "Changed only: public\index.html and public\styles.css" -ForegroundColor Yellow
  Write-Host "Backend/database/.env/app.js/admin/cart/checkout were not modified." -ForegroundColor Green
}
catch {
  Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "Restoring backup..." -ForegroundColor Yellow
  Copy-Item (Join-Path $backupDir "index.html") $index -Force
  Copy-Item (Join-Path $backupDir "styles.css") $css -Force
  Write-Host "RESTORED." -ForegroundColor Green
  throw
}
