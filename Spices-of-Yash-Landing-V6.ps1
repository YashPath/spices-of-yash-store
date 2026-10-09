# Spices of Yash - Landing V6 Brand Cleanup
# Frontend-only. Cleans remaining mojibake and normalizes hero symbols/prices.
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$index = Join-Path $root "public\index.html"
$css   = Join-Path $root "public\styles.css"

if (!(Test-Path $index)) { throw "public\index.html not found." }
if (!(Test-Path $css))   { throw "public\styles.css not found." }

$html = Get-Content $index -Raw
$styles = Get-Content $css -Raw

foreach ($marker in @('id="product-grid"','id="cart-open"','id="checkout-form"','id="home"','sy-v3-hero')) {
    if ($html.IndexOf($marker, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "Safety check failed: $marker not found. Nothing changed."
    }
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = Join-Path $root "landing-v6-backup-$stamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Copy-Item $index (Join-Path $backupDir "index.html")
Copy-Item $css   (Join-Path $backupDir "styles.css")

# Build common mojibake sequences using character codes.
$c2 = [string]([char]0x00C2)
$e2 = [string]([char]0x00E2)

$map = @(
    @($c2 + [string]([char]0x00B7), '&middot;'),
    @($c2 + [string]([char]0x00A0), ' '),
    @($e2 + [string]([char]0x20AC) + [string]([char]0x00A2), '&bull;'),
    @($e2 + [string]([char]0x2020) + [string]([char]0x2019), '&rarr;'),
    @($e2 + [string]([char]0x20AC) + [string]([char]0x201D), '&mdash;'),
    @($e2 + [string]([char]0x2020) + [string]([char]0x00A9), '&copy;')
)

foreach ($pair in $map) {
    $html = $html.Replace($pair[0], $pair[1])
    $styles = $styles.Replace($pair[0], $pair[1])
}

foreach ($ch in @(' ',':',';','|','-','+','.',',','(')) {
    $html = $html.Replace($c2 + $ch, $ch)
    $styles = $styles.Replace($c2 + $ch, $ch)
}

# Normalize current hero symbols to ASCII-safe HTML entities.
$html = $html.Replace('Shop the pantry &rarr;', 'Shop the pantry <span aria-hidden="true">&rarr;</span>')
$html = $html.Replace('Our story &rarr;', 'Our story <span aria-hidden="true">&rarr;</span>')

# Encode the rupee symbol by Unicode code point, avoiding font/encoding issues.
$rupee = [string]([char]0x20B9)
$html = $html.Replace($rupee + '349', '&#8377;349')
$html = $html.Replace($rupee, '&#8377;')
$html = $html.Replace('&rarr;&rarr;', '&rarr;')

$cssBlock = @'

/* =========================================================
   SPICES OF YASH - V6 BRAND MARK + FINAL SYMBOL POLISH
   ========================================================= */
.site-header .brand-mark,
.site-header .logo-mark,
.site-header .brand-icon{
  font-size:0;
  position:relative;
  display:inline-grid;
  place-items:center;
}
.site-header .brand-mark:before,
.site-header .logo-mark:before,
.site-header .brand-icon:before{
  content:"";
  width:26px;
  height:26px;
  border:2px solid currentColor;
  border-radius:50% 50% 50% 12%;
  transform:rotate(-18deg);
  display:block;
  opacity:.95;
}
.site-header .brand-mark:after,
.site-header .logo-mark:after,
.site-header .brand-icon:after{
  content:"";
  position:absolute;
  width:9px;
  height:9px;
  border-radius:50%;
  background:currentColor;
  transform:translate(4px,-5px);
}
.sy-v3-card-meta b{
  font-variant-numeric:tabular-nums;
  white-space:nowrap;
}
.sy-v3-primary span[aria-hidden="true"],
.sy-v3-story span[aria-hidden="true"]{
  display:inline-block;
  transition:transform .2s ease;
}
.sy-v3-primary:hover span[aria-hidden="true"],
.sy-v3-story:hover span[aria-hidden="true"]{
  transform:translateX(3px);
}
'@

if ($styles -notmatch 'SPICES OF YASH - V6 BRAND MARK') {
    $styles += $cssBlock
}

try {
    Set-Content -Path $index -Value $html -Encoding UTF8
    Set-Content -Path $css -Value $styles -Encoding UTF8

    $check = Get-Content $index -Raw
    foreach ($marker in @('id="product-grid"','id="cart-open"','id="checkout-form"','id="home"','sy-v3-hero')) {
        if ($check.IndexOf($marker, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
            throw "Post-write validation failed: $marker missing."
        }
    }
    if ($check -notmatch 'sy-v5-3d-interaction') {
        throw "Post-write validation failed: V5 interaction missing."
    }

    Write-Host ""
    Write-Host "SUCCESS: Landing V6 brand cleanup applied." -ForegroundColor Green
    Write-Host "Backup: $backupDir" -ForegroundColor Cyan
    Write-Host "Changed only: public/index.html and public/styles.css" -ForegroundColor Yellow
    Write-Host "Backend/database/.env/app.js/admin/cart/checkout were NOT modified." -ForegroundColor Green
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Restoring backup..." -ForegroundColor Yellow
    Copy-Item (Join-Path $backupDir "index.html") $index -Force
    Copy-Item (Join-Path $backupDir "styles.css") $css -Force
    Write-Host "RESTORED. V6 changes were not kept." -ForegroundColor Green
    throw
}
