param(
  [string]$ProjectPath = "D:\Project\Spices-of-Yash-Complete-Local-Project (1)\spices-of-yash-store"
)

$ErrorActionPreference = "Stop"

$indexPath = Join-Path $ProjectPath "public\index.html"
$cssPath   = Join-Path $ProjectPath "public\styles.css"

if (!(Test-Path -LiteralPath $indexPath)) { throw "public\index.html was not found." }
if (!(Test-Path -LiteralPath $cssPath)) { throw "public\styles.css was not found." }

$html = [System.IO.File]::ReadAllText($indexPath)
$css  = [System.IO.File]::ReadAllText($cssPath)

foreach ($marker in @('id="product-grid"', 'id="cart-open"', 'id="checkout-form"')) {
  if ($html -notmatch [regex]::Escape($marker)) {
    throw "Safety check failed: $marker was not found. Nothing changed."
  }
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = Join-Path $ProjectPath ("frontend-final-cleanup-backup-" + $stamp)
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $indexPath -Destination (Join-Path $backup "index.html")
Copy-Item -LiteralPath $cssPath -Destination (Join-Path $backup "styles.css")

# Remove only an accidental visible "html" text node if it appears immediately
# before the document head. This does not touch legitimate HTML tags.
$html = [regex]::Replace(
  $html,
  '(?is)^\s*html\s*(?=<\s*!doctype|<\s*html\b)',
  '',
  1
)

# Also remove the exact stray text immediately before <head>, if present.
$html = [regex]::Replace(
  $html,
  '(?is)(<html\b[^>]*>\s*)html(\s*<head\b)',
  '$1$2',
  1
)

# Guarantee a clean UTF-8 declaration without changing the rest of the head.
if ($html -notmatch '(?i)<meta\s+charset\s*=') {
  $html = [regex]::Replace(
    $html,
    '(?i)(<head\b[^>]*>)',
    '$1' + "`r`n" + '<meta charset="UTF-8">',
    1
  )
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($indexPath, $html, $utf8)
[System.IO.File]::WriteAllText($cssPath, $css, $utf8)

# Final safety validation.
$finalHtml = [System.IO.File]::ReadAllText($indexPath)

foreach ($marker in @('id="product-grid"', 'id="cart-open"', 'id="checkout-form"')) {
  if ($finalHtml -notmatch [regex]::Escape($marker)) {
    Copy-Item (Join-Path $backup "index.html") $indexPath -Force
    Copy-Item (Join-Path $backup "styles.css") $cssPath -Force
    throw "Final validation failed for $marker. Original frontend restored."
  }
}

if ($finalHtml -match '(?is)^\s*html\s*(?=<\s*!doctype|<\s*html\b)') {
  Copy-Item (Join-Path $backup "index.html") $indexPath -Force
  Copy-Item (Join-Path $backup "styles.css") $cssPath -Force
  throw "The stray html text was not safely removed. Original frontend restored."
}

Write-Host ""
Write-Host "FINAL FRONTEND CLEANUP APPLIED SUCCESSFULLY." -ForegroundColor Green
Write-Host "Removed the accidental visible html text and preserved the existing design." -ForegroundColor Green
Write-Host "Frontend only: public\index.html and public\styles.css." -ForegroundColor Green
Write-Host "Backend, database, .env, server.js, app.js, cart and checkout were NOT changed." -ForegroundColor Green
Write-Host ("Backup: " + $backup) -ForegroundColor Cyan
Write-Host "Refresh http://localhost:3000 with Ctrl+F5." -ForegroundColor Yellow
