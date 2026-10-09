param(
  [string]$ProjectPath = "D:\Project\Spices-of-Yash-Complete-Local-Project (1)\spices-of-yash-store"
)

$ErrorActionPreference = "Stop"

$public = Join-Path $ProjectPath "public"
$indexPath = Join-Path $public "index.html"
$cssPath = Join-Path $public "styles.css"

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
$backup = Join-Path $ProjectPath ("frontend-motion-polish-backup-" + $stamp)
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $indexPath -Destination (Join-Path $backup "index.html")
Copy-Item -LiteralPath $cssPath -Destination (Join-Path $backup "styles.css")

# Remove only the previous motion-polish layer if this script is rerun.
$css = [regex]::Replace(
  $css,
  '(?s)/\* SPICES OF YASH - MOTION POLISH V2 START \*/.*?/\* SPICES OF YASH - MOTION POLISH V2 END \*/',
  '',
  1
)

$cssPatch = @'

/* SPICES OF YASH - MOTION POLISH V2 START */

/* ---------- NAVBAR: cleaner hierarchy + premium scroll state ---------- */
.site-header,
.sy-motion-header {
  position: sticky !important;
  top: 0;
  z-index: 1000 !important;
  isolation: isolate;
}

.announcement {
  position: relative;
  z-index: 1001;
}

.site-header {
  transition:
    background-color .45s ease,
    border-color .45s ease,
    box-shadow .45s ease,
    backdrop-filter .45s ease;
}

.sy-header-top {
  background: rgba(22, 13, 8, .72) !important;
}

.sy-header-scrolled {
  background: rgba(22, 13, 8, .94) !important;
  border-bottom: 1px solid rgba(232, 183, 90, .20) !important;
  box-shadow: 0 12px 38px rgba(0,0,0,.20) !important;
  backdrop-filter: blur(18px);
  -webkit-backdrop-filter: blur(18px);
}

.site-header .main-nav a,
.site-header nav a {
  transition: color .28s ease, opacity .28s ease;
}

.site-header .main-nav a:hover,
.site-header nav a:hover {
  color: #e8b75a !important;
}

.site-header .cart-btn,
.site-header .cart-button {
  transition:
    transform .28s ease,
    border-color .28s ease,
    background-color .28s ease;
}

.site-header .cart-btn:hover,
.site-header .cart-button:hover {
  transform: translateY(-2px);
  border-color: rgba(232,183,90,.60) !important;
  background: rgba(232,183,90,.08);
}

/* ---------- HERO: staged choreography ---------- */
.sy-motion-hero {
  min-height: max(680px, calc(100svh - 80px));
}

.sy-motion-hero .hero-copy,
.sy-motion-hero .hero-content {
  position: relative;
  z-index: 5;
}

.sy-motion-hero .eyebrow {
  animation: sy-v2-rise .75s .12s both cubic-bezier(.2,.75,.2,1);
}

.sy-motion-hero h1 {
  animation: sy-v2-rise 1s .24s both cubic-bezier(.2,.75,.2,1);
}

.sy-motion-hero .hero-description {
  animation: sy-v2-rise .85s .40s both cubic-bezier(.2,.75,.2,1);
}

.sy-motion-hero .hero-ctas,
.sy-motion-hero .hero-actions {
  animation: sy-v2-rise .85s .54s both cubic-bezier(.2,.75,.2,1);
}

.sy-motion-hero .hero-trust,
.sy-motion-hero .hero-note {
  animation: sy-v2-rise .85s .68s both cubic-bezier(.2,.75,.2,1);
}

/* Editorial hero card */
.sy-motion-hero .hero-card,
.sy-motion-hero .editorial-card,
.sy-motion-hero .hero-note {
  transition:
    transform .55s cubic-bezier(.2,.75,.2,1),
    border-color .4s ease,
    background-color .4s ease;
}

.sy-motion-hero .hero-card:hover,
.sy-motion-hero .editorial-card:hover {
  transform: translateY(-5px);
  border-color: rgba(232,183,90,.65);
  background-color: rgba(22,13,8,.70);
}

/* Keep the hero image alive but slow. */
.sy-motion-hero .hero-photo,
.sy-motion-hero .hero-image {
  animation: sy-v2-kenburns 18s ease-in-out infinite alternate !important;
}

/* ---------- PRODUCT GRID: stagger + premium hover ---------- */
#product-grid {
  perspective: 1200px;
}

#product-grid > *,
#product-grid .product-card,
#product-grid .product-item {
  transform-origin: center bottom;
  will-change: transform;
}

#product-grid > *:hover,
#product-grid .product-card:hover,
#product-grid .product-item:hover {
  transform: translateY(-9px) !important;
  box-shadow: 0 26px 58px rgba(45,24,12,.16) !important;
}

#product-grid > *::after,
#product-grid .product-card::after,
#product-grid .product-item::after {
  content: "";
  position: absolute;
  inset: 0;
  pointer-events: none;
  opacity: 0;
  background: linear-gradient(
    115deg,
    transparent 35%,
    rgba(255,248,234,.22) 49%,
    transparent 63%
  );
  transform: translateX(-80%);
  transition: opacity .2s ease, transform .75s ease;
  z-index: 4;
}

#product-grid > *:hover::after,
#product-grid .product-card:hover::after,
#product-grid .product-item:hover::after {
  opacity: 1;
  transform: translateX(80%);
}

#product-grid img,
#product-grid .product-image img {
  will-change: transform;
}

#product-grid > *:hover img,
#product-grid .product-card:hover img,
#product-grid .product-item:hover img {
  transform: scale(1.065) !important;
}

/* Add buttons */
#product-grid button,
#product-grid .add-btn,
#product-grid .add-to-cart {
  transition:
    transform .28s cubic-bezier(.2,.75,.2,1),
    box-shadow .28s ease,
    background-color .28s ease;
}

#product-grid button:hover,
#product-grid .add-btn:hover,
#product-grid .add-to-cart:hover {
  transform: scale(1.10) rotate(2deg);
  box-shadow: 0 10px 24px rgba(45,24,12,.16);
}

/* ---------- FILTER PILLS + SEARCH ---------- */
#shop button,
.shop-filters button,
.filter button,
.filter-pill {
  transition:
    transform .25s ease,
    background-color .25s ease,
    color .25s ease,
    border-color .25s ease;
}

#shop button:hover,
.shop-filters button:hover,
.filter button:hover,
.filter-pill:hover {
  transform: translateY(-2px);
}

input[type="search"],
.search-input,
input[placeholder*="flavour" i],
input[placeholder*="flavor" i] {
  transition:
    border-color .3s ease,
    box-shadow .3s ease,
    transform .3s ease;
}

input[type="search"]:focus,
.search-input:focus,
input[placeholder*="flavour" i]:focus,
input[placeholder*="flavor" i]:focus {
  transform: translateY(-1px);
  border-color: #b98245 !important;
  box-shadow: 0 8px 24px rgba(75,40,18,.10) !important;
}

/* ---------- SECTION REVEALS ---------- */
.sy-reveal-section {
  transition:
    opacity .9s ease,
    transform .9s cubic-bezier(.2,.75,.2,1);
}

.sy-reveal-section.is-visible {
  transform: translateY(0);
}

/* ---------- GENERIC BUTTON MICRO-INTERACTION ---------- */
.btn,
.button,
.primary-btn,
.sy-motion-button {
  transition:
    transform .25s cubic-bezier(.2,.75,.2,1),
    box-shadow .3s ease,
    background-color .3s ease,
    border-color .3s ease;
}

.btn:hover,
.button:hover,
.primary-btn:hover,
.sy-motion-button:hover {
  transform: translateY(-2px);
}

.btn:active,
.button:active,
.primary-btn:active,
.sy-motion-button:active {
  transform: translateY(0) scale(.985);
}

/* ---------- STORY / IMAGE SECTIONS ---------- */
#story img,
.story img,
.story-image,
.image-panel img {
  transition: transform 1.1s cubic-bezier(.2,.75,.2,1), filter .6s ease;
}

#story:hover img,
.story:hover img,
.image-panel:hover img {
  transform: scale(1.025);
  filter: saturate(1.04);
}

/* ---------- MOBILE ---------- */
@media (max-width: 900px) {
  .sy-motion-hero {
    min-height: calc(100svh - 70px);
  }

  #product-grid > *:hover,
  #product-grid .product-card:hover,
  #product-grid .product-item:hover {
    transform: translateY(-5px) !important;
  }
}

@media (max-width: 650px) {
  .sy-motion-hero {
    min-height: calc(100svh - 64px);
  }

  .sy-motion-hero .hero-photo,
  .sy-motion-hero .hero-image {
    animation-duration: 22s !important;
  }

  #product-grid > *:hover,
  #product-grid .product-card:hover,
  #product-grid .product-item:hover {
    transform: translateY(-3px) !important;
  }

  #product-grid > *::after,
  #product-grid .product-card::after,
  #product-grid .product-item::after {
    display: none;
  }

  #product-grid button:hover,
  #product-grid .add-btn:hover,
  #product-grid .add-to-cart:hover {
    transform: scale(1.04);
  }

  .btn:hover,
  .button:hover,
  .primary-btn:hover,
  .sy-motion-button:hover {
    transform: none;
    box-shadow: none;
  }
}

/* ---------- REDUCED MOTION ---------- */
@media (prefers-reduced-motion: reduce) {
  .sy-motion-hero .hero-photo,
  .sy-motion-hero .hero-image {
    animation: none !important;
  }

  #product-grid > *,
  #product-grid img,
  .btn,
  .button,
  .primary-btn,
  .sy-motion-button {
    transition: none !important;
  }
}

@keyframes sy-v2-rise {
  from {
    opacity: 0;
    transform: translateY(22px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes sy-v2-kenburns {
  from {
    transform: scale(1.035);
  }
  to {
    transform: scale(1.075);
  }
}

/* SPICES OF YASH - MOTION POLISH V2 END */
'@

$css += $cssPatch

$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($cssPath, $css, $utf8)

# Validate that the commerce hooks are still present.
$finalHtml = [System.IO.File]::ReadAllText($indexPath)
foreach ($marker in @('id="product-grid"', 'id="cart-open"', 'id="checkout-form"')) {
  if ($finalHtml -notmatch [regex]::Escape($marker)) {
    Copy-Item (Join-Path $backup "index.html") $indexPath -Force
    Copy-Item (Join-Path $backup "styles.css") $cssPath -Force
    throw "Final validation failed for $marker. Original frontend restored."
  }
}

Write-Host ""
Write-Host "SPICES OF YASH MOTION POLISH V2 APPLIED SUCCESSFULLY." -ForegroundColor Green
Write-Host "Improved: navbar, hero choreography, Ken Burns, product hover, image sweep, add-button microinteraction, filters, search focus, story image motion and mobile behavior." -ForegroundColor Green
Write-Host "Frontend only: public\styles.css changed." -ForegroundColor Green
Write-Host "Backend, database, .env, server.js, app.js, cart and checkout were NOT changed." -ForegroundColor Green
Write-Host ("Backup: " + $backup) -ForegroundColor Cyan
Write-Host "Use Ctrl+F5 on http://localhost:3000" -ForegroundColor Yellow
