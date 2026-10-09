# Spices of Yash - Encoding Cleanup V2
# ASCII-safe PowerShell patch. Frontend-only.
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
$backupDir = Join-Path $root "encoding-cleanup-v2-backup-$stamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Copy-Item $index (Join-Path $backupDir "index.html")
Copy-Item $css   (Join-Path $backupDir "styles.css")

# Build mojibake sequences using character codes, so this script contains
# no non-ASCII source characters.
$c2 = [string]([char]0x00C2)
$dotBad = $c2 + [string]([char]0x00B7)
$bulletBad = [string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x00A2)
$rightBad = [string]([char]0x00E2) + [string]([char]0x2020) + [string]([char]0x2019)
$dashBad = [string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x201D)

$pairs = @(
    @($dotBad, '&middot;'),
    @($bulletBad, '&bull;'),
    @($rightBad, '&rarr;'),
    @($dashBad, '&mdash;')
)

foreach ($pair in $pairs) {
    $html = $html.Replace($pair[0], $pair[1])
    $styles = $styles.Replace($pair[0], $pair[1])
}

# Remove common stray C2 characters left before spaces.
$html = $html.Replace($c2 + ' ', ' ')
$styles = $styles.Replace($c2 + ' ', ' ')

# Normalize the exact V3 hero phrases.
$html = $html.Replace('SMALL-BATCH ' + $dotBad + ' SINGLE ORIGIN ' + $dotBad + ' INDIA',
                     'SMALL-BATCH &middot; SINGLE ORIGIN &middot; INDIA')
$html = $html.Replace('Shop the pantry ' + $rightBad, 'Shop the pantry &rarr;')
$html = $html.Replace('Our story ' + $rightBad, 'Our story &rarr;')
$html = $html.Replace('100g ' + $dotBad + ' FARM-TRACEABLE', '100g &middot; FARM-TRACEABLE')
$html = $html.Replace('RETAIL ' + $dotBad + ' WHOLESALE', 'RETAIL &middot; WHOLESALE')

try {
    Set-Content -Path $index -Value $html -Encoding UTF8
    Set-Content -Path $css -Value $styles -Encoding UTF8

    $check = Get-Content $index -Raw
    foreach ($marker in @('id="product-grid"','id="cart-open"','id="checkout-form"','id="home"')) {
        if ($check.IndexOf($marker, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
            throw "Post-write validation failed: $marker missing."
        }
    }

    if ($check -notmatch 'sy-v3-hero') {
        throw "Post-write validation failed: V3 hero missing."
    }

    Write-Host ""
    Write-Host "SUCCESS: Encoding cleanup V2 applied." -ForegroundColor Green
    Write-Host "Backup: $backupDir" -ForegroundColor Cyan
    Write-Host "Only public/index.html and public/styles.css were changed." -ForegroundColor Yellow
    Write-Host "Backend/database/.env/app.js/admin/cart/checkout were NOT modified." -ForegroundColor Green
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Restoring backup..." -ForegroundColor Yellow
    Copy-Item (Join-Path $backupDir "index.html") $index -Force
    Copy-Item (Join-Path $backupDir "styles.css") $css -Force
    Write-Host "RESTORED." -ForegroundColor Green
    throw
}
