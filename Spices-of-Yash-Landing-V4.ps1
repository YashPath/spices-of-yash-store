# Spices of Yash - Premium Landing V4
# Safe frontend-only polish: global mojibake cleanup + hero viewport + subtle 3D motion.
# Does not touch server.js, database, .env, or app.js.
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$index = Join-Path $root "public\index.html"
$css = Join-Path $root "public\styles.css"

if (!(Test-Path $index)) { throw "public\index.html not found." }
if (!(Test-Path $css)) { throw "public\styles.css not found." }

$html = Get-Content $index -Raw
$styles = Get-Content $css -Raw

foreach ($marker in @('id="product-grid"','id="cart-open"','id="checkout-form"','id="home"')) {
    if ($html.IndexOf($marker, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "Safety check failed: $marker not found. Nothing changed."
    }
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = Join-Path $root "landing-v4-backup-$stamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Copy-Item $index (Join-Path $backupDir "index.html")
Copy-Item $css (Join-Path $backupDir "styles.css")

# Common UTF-8/Windows-1252 mojibake, constructed without non-ASCII source text.
$c2 = [string]([char]0x00C2)
$e2 = [string]([char]0x00E2)
$e3 = [string]([char]0x00E3)
$e280 = [string]([char]0x20AC)
$dagger = [string]([char]0x2020)
$quoteRight = [string]([char]0x2019)
$quoteLeft = [string]([char]0x2018)
$quoteDoubleRight = [string]([char]0x201D)
$quoteDoubleLeft = [string]([char]0x201C)
$nbsp = [string]([char]0x00A0)
$dot = [string]([char]0x00B7)
$rupeeMojibake = $e2 + [string]([char]0x201A) + [string]([char]0x00B9)

$replacements = @(
    @($c2 + $dot, '&middot;'),
    @($e2 + $dagger + $quoteRight, '&rarr;'),
    @($e2 + $dagger + $quoteLeft, '&larr;'),
    @($e2 + $e280 + $quoteDoubleRight, '&mdash;'),
    @($e2 + $e280 + $quoteDoubleLeft, '&ndash;'),
    @($e2 + $e280 + [string]([char]0x2122), '&trade;'),
    @($e2 + [string]([char]0x20AC) + [string]([char]0x00A2), '&bull;'),
    @($rupeeMojibake, '&#8377;'),
    @($c2 + ' ', ' '),
    @($nbsp, ' ')
)

foreach ($pair in $replacements) {
    $html = $html.Replace($pair[0], $pair[1])
    $styles = $styles.Replace($pair[0], $pair[1])
}

# Fix exact visible V3 hero phrases if mojibake survived.
$html = $html.Replace('SMALL-BATCH ' + $c2 + $dot + ' SINGLE ORIGIN ' + $c2 + $dot + ' INDIA',
                     'SMALL-BATCH &middot; SINGLE ORIGIN &middot; INDIA')
$html = $html.Replace('Shop the pantry ' + $e2 + $dagger + $quoteRight, 'Shop the pantry &rarr;')
$html = $html.Replace('Our story ' + $e2 + $dagger + $quoteRight, 'Our story &rarr;')
$html = $html.Replace('100g ' + $c2 + $dot + ' FARM-TRACEABLE', '100g &middot; FARM-TRACEABLE')
$html = $html.Replace('RETAIL ' + $c2 + $dot + ' WHOLESALE', 'RETAIL &middot; WHOLESALE')

# Append V4 CSS once. This only targets the V3 hero/header and does not replace
# the existing commerce layout.
if ($styles -notmatch 'SPICES OF YASH - LANDING V4') {
$cssBlock = @'

/* =========================================================
   SPICES OF YASH - LANDING V4
   Premium viewport + subtle 3D depth polish
   ========================================================= */
.sy-v3-hero{
  min-height:calc(100svh - 112px);
  max-height:920px;
}
.sy-v3-inner{
  padding-top:clamp(72px,8vh,110px);
  padding-bottom:clamp(58px,7vh,88px);
}
.sy-v3-copy{
  transform:translateZ(0);
}
.sy-v3-hero h1{
  max-width:700px;
  font-size:clamp(52px,6.25vw,94px);
  line-height:.9;
}
.sy-v3-description{
  max-width:560px;
  margin-top:24px;
}
.sy-v3-actions{
  margin-top:26px;
}
.sy-v3-proof{
  margin-top:38px;
}
.sy-v3-product{
  min-height:390px;
  perspective:1200px;
}
.sy-v3-card{
  transform:rotateY(-7deg) rotateZ(1.5deg) translateZ(0);
  transform-style:preserve-3d;
  transition:transform .65s cubic-bezier(.2,.75,.2,1),box-shadow .65s ease;
}
.sy-v3-card:hover{
  transform:rotateY(-1deg) rotateZ(0deg) translateY(-10px) scale(1.015);
  box-shadow:0 48px 120px rgba(0,0,0,.52);
}
.sy-v3-orbit{
  animation:syV4Float 8s ease-in-out infinite;
}
.sy-v3-card{
  animation:syV4CardFloat 7s ease-in-out infinite;
}
@keyframes syV4Float{
  0%,100%{transform:translateY(0) rotate(0deg);}
  50%{transform:translateY(-9px) rotate(3deg);}
}
@keyframes syV4CardFloat{
  0%,100%{transform:rotateY(-7deg) rotateZ(1.5deg) translateY(0);}
  50%{transform:rotateY(-4deg) rotateZ(1deg) translateY(-8px);}
}
@media (max-height:820px) and (min-width:901px){
  .sy-v3-hero{min-height:calc(100svh - 96px);}
  .sy-v3-inner{padding-top:54px;padding-bottom:42px;gap:46px;}
  .sy-v3-hero h1{font-size:clamp(48px,5.8vw,76px);}
  .sy-v3-description{margin-top:18px;}
  .sy-v3-actions{margin-top:20px;}
  .sy-v3-proof{margin-top:25px;}
  .sy-v3-product{min-height:330px;}
  .sy-v3-card-image{height:260px;}
}
@media (max-width:900px){
  .sy-v3-hero{min-height:calc(100svh - 82px);max-height:none;}
  .sy-v3-inner{padding-top:74px;padding-bottom:68px;}
  .sy-v3-card{animation:none;transform:rotateZ(1deg);}
}
@media (prefers-reduced-motion:reduce){
  .sy-v3-orbit,.sy-v3-card{animation:none!important;}
  .sy-v3-card{transition:none;}
}
'@
$styles = $styles + $cssBlock
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
    if ($check -notmatch 'sy-v3-hero') { throw "Post-write validation failed: V3 hero missing." }

    Write-Host ""
    Write-Host "SUCCESS: Landing V4 polish applied." -ForegroundColor Green
    Write-Host "Backup: $backupDir" -ForegroundColor Cyan
    Write-Host "Changed only: public/index.html and public/styles.css" -ForegroundColor Yellow
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
