param(
  [string]$ProjectPath = "D:\Project\Spices-of-Yash-Complete-Local-Project (1)\spices-of-yash-store"
)

$ErrorActionPreference = "Stop"

$public = Join-Path $ProjectPath "public"
$indexPath = Join-Path $public "index.html"
$cssPath   = Join-Path $public "styles.css"

if (!(Test-Path -LiteralPath $indexPath)) { throw "public\index.html not found." }
if (!(Test-Path -LiteralPath $cssPath))   { throw "public\styles.css not found." }

$html = [System.IO.File]::ReadAllText($indexPath)
$css  = [System.IO.File]::ReadAllText($cssPath)

# Safety gates: this patch only changes the customer landing-page presentation.
foreach ($marker in @('id="product-grid"', 'id="cart-open"', 'id="checkout-form"')) {
  if (!$html.Contains($marker)) {
    throw "Required storefront marker missing: $marker. Nothing changed."
  }
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = Join-Path $ProjectPath ("landing-v2-backup-" + $stamp)
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $indexPath -Destination (Join-Path $backup "index.html") -Force
Copy-Item -LiteralPath $cssPath   -Destination (Join-Path $backup "styles.css") -Force

# Replace only the visual hero. Product/cart/checkout hooks are untouched.
$newHero = @'
<section class="hero hero-cinematic hero-video sy-landing-v2" aria-label="Spices of Yash">
  <video class="hero-video-bg" autoplay loop muted playsinline preload="metadata"
    poster="/images/story-spices.webp" aria-hidden="true">
    <source src="https://cdn.sceneai.art/Hero%20Section%20Video/01d1f8de-fec0-4bf5-8b48-9fc2dbc8c6b0.mp4" type="video/mp4">
  </video>

  <div class="sy-v2-shade" aria-hidden="true"></div>
  <div class="sy-v2-glow sy-v2-glow-a" aria-hidden="true"></div>
  <div class="sy-v2-glow sy-v2-glow-b" aria-hidden="true"></div>

  <div class="sy-v2-inner">
    <div class="sy-v2-copy">
      <p class="sy-v2-kicker"><span></span> AUTHENTIC INDIAN FLAVOUR <span></span></p>

      <h1>Make every meal<br><em>worth remembering.</em></h1>

      <p class="sy-v2-description">
        Carefully packed Indian spices, bold masalas and everyday pantry essentials —
        selected for real kitchens, family recipes and professional cooking.
      </p>

      <div class="sy-v2-actions">
        <a class="sy-v2-primary" href="#shop">Shop the pantry <span>↗</span></a>
        <a class="sy-v2-secondary" href="#story">Our story <span>→</span></a>
      </div>

      <div class="sy-v2-proof" aria-label="Store highlights">
        <div><strong>100%</strong><span>flavour-first</span></div>
        <i></i>
        <div><strong>India</strong><span>delivery ready</span></div>
        <i></i>
        <div><strong>Retail +</strong><span>wholesale</span></div>
      </div>
    </div>

    <div class="sy-v2-product" aria-label="Featured product">
      <div class="sy-v2-product-orbit"></div>
      <div class="sy-v2-product-card">
        <span class="sy-v2-product-label">FEATURED PANTRY PICK</span>
        <div class="sy-v2-product-image">
          <img src="/images/green-cardamom.jpg" alt="Green Cardamom" onerror="this.style.display='none'">
          <span class="sy-v2-product-fallback">CARDAMOM</span>
        </div>
        <div class="sy-v2-product-meta">
          <div>
            <small>SINGLE ORIGIN</small>
            <h2>Green Cardamom</h2>
          </div>
          <strong>₹349</strong>
        </div>
        <a href="#shop" class="sy-v2-product-link">Discover the collection <span>↗</span></a>
      </div>
      <div class="sy-v2-stamp">SMALL<br>BATCH<br><span>✳</span></div>
    </div>
  </div>

  <a class="sy-v2-scroll" href="#shop" aria-label="Scroll to shop">
    <span>SCROLL TO EXPLORE</span><b>↓</b>
  </a>
</section>
'@

$heroPattern = '(?s)<section\s+class="hero[^"]*"[^>]*>.*?</section>'
$matches = [regex]::Matches($html, $heroPattern)

if ($matches.Count -ne 1) {
  throw "Expected exactly one existing hero section. Found $($matches.Count). Nothing changed."
}

$html = [regex]::Replace(
  $html,
  $heroPattern,
  [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $newHero },
  1
)

$cssPatch = @'

/* =========================================================
   SPICES OF YASH — LANDING PAGE V2
   Premium editorial storefront hero.
   Frontend only. Commerce logic is untouched.
   ========================================================= */

.sy-landing-v2 {
  position: relative;
  isolation: isolate;
  min-height: min(900px, calc(100svh - 74px));
  height: min(900px, calc(100svh - 74px));
  overflow: hidden;
  background: #17130e;
  color: #fffaf0;
  padding: 0;
}

.sy-landing-v2 .hero-video-bg {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
  object-position: center;
  z-index: -4;
  filter: saturate(.88) contrast(1.04);
}

.sy-v2-shade {
  position: absolute;
  inset: 0;
  z-index: -3;
  background:
    linear-gradient(90deg, rgba(8,7,5,.90) 0%, rgba(8,7,5,.70) 34%, rgba(8,7,5,.22) 72%, rgba(8,7,5,.46) 100%),
    linear-gradient(0deg, rgba(8,7,5,.58) 0%, transparent 35%, rgba(8,7,5,.18) 100%);
}

.sy-v2-glow {
  position: absolute;
  width: 430px;
  height: 430px;
  border-radius: 50%;
  pointer-events: none;
  filter: blur(12px);
  z-index: -2;
  opacity: .42;
}

.sy-v2-glow-a {
  left: 35%;
  top: -180px;
  background: radial-gradient(circle, rgba(226,157,75,.34), transparent 68%);
}

.sy-v2-glow-b {
  right: -160px;
  bottom: -220px;
  background: radial-gradient(circle, rgba(119,74,38,.36), transparent 68%);
}

.sy-v2-inner {
  width: min(1240px, 88vw);
  height: 100%;
  margin: 0 auto;
  display: grid;
  grid-template-columns: minmax(0, 1.15fr) minmax(360px, .85fr);
  align-items: center;
  gap: clamp(36px, 6vw, 100px);
  padding: 76px 0 70px;
}

.sy-v2-copy {
  max-width: 720px;
  transform: translateY(8px);
  animation: syV2Up .85s ease-out both;
}

.sy-v2-kicker {
  display: flex;
  align-items: center;
  gap: 12px;
  margin: 0 0 22px;
  color: rgba(255,250,240,.74);
  font-size: 11px;
  font-weight: 600;
  letter-spacing: .22em;
}

.sy-v2-kicker span {
  width: 28px;
  height: 1px;
  background: #dca364;
}

.sy-v2-kicker span:last-child {
  display: none;
}

.sy-v2-copy h1 {
  margin: 0;
  max-width: 760px;
  font-size: clamp(48px, 6vw, 86px);
  line-height: .98;
  letter-spacing: -.055em;
  font-weight: 500;
  text-wrap: balance;
  color: #fffaf0;
}

.sy-v2-copy h1 em {
  color: #e8ad68;
  font-style: normal;
}

.sy-v2-description {
  max-width: 620px;
  margin: 27px 0 0;
  color: rgba(255,250,240,.72);
  font-size: clamp(15px, 1.35vw, 18px);
  line-height: 1.7;
  text-wrap: balance;
}

.sy-v2-actions {
  display: flex;
  align-items: center;
  gap: 24px;
  margin-top: 34px;
}

.sy-v2-primary {
  display: inline-flex;
  align-items: center;
  gap: 22px;
  min-height: 52px;
  padding: 0 20px 0 23px;
  border-radius: 2px;
  background: #fffaf0;
  color: #17130e;
  font-size: 14px;
  font-weight: 700;
  letter-spacing: .01em;
  text-decoration: none;
  box-shadow: 0 18px 45px rgba(0,0,0,.24);
  transition: transform .25s ease, box-shadow .25s ease;
}

.sy-v2-primary span {
  font-size: 18px;
}

.sy-v2-primary:hover {
  transform: translateY(-3px);
  box-shadow: 0 22px 55px rgba(0,0,0,.32);
}

.sy-v2-secondary {
  color: rgba(255,250,240,.86);
  text-decoration: none;
  font-size: 14px;
  border-bottom: 1px solid rgba(255,250,240,.38);
  padding-bottom: 5px;
  transition: color .2s ease, border-color .2s ease;
}

.sy-v2-secondary:hover {
  color: #fff;
  border-color: #fff;
}

.sy-v2-proof {
  display: flex;
  align-items: center;
  gap: 22px;
  margin-top: 44px;
}

.sy-v2-proof div {
  display: grid;
  gap: 3px;
}

.sy-v2-proof strong {
  font-size: 14px;
  font-weight: 600;
  color: #fffaf0;
}

.sy-v2-proof span {
  font-size: 10px;
  letter-spacing: .11em;
  text-transform: uppercase;
  color: rgba(255,250,240,.48);
}

.sy-v2-proof i {
  width: 1px;
  height: 30px;
  background: rgba(255,250,240,.18);
}

.sy-v2-product {
  position: relative;
  justify-self: end;
  width: min(410px, 100%);
  animation: syV2Product .95s .12s ease-out both;
}

.sy-v2-product-orbit {
  position: absolute;
  width: 420px;
  height: 420px;
  left: 50%;
  top: 48%;
  transform: translate(-50%,-50%);
  border-radius: 50%;
  border: 1px solid rgba(235,181,111,.20);
  box-shadow:
    0 0 0 32px rgba(235,181,111,.025),
    0 0 90px rgba(215,143,65,.12);
}

.sy-v2-product-card {
  position: relative;
  z-index: 2;
  padding: 15px;
  border: 1px solid rgba(255,250,240,.18);
  background: rgba(20,16,11,.66);
  backdrop-filter: blur(18px);
  -webkit-backdrop-filter: blur(18px);
  box-shadow: 0 30px 90px rgba(0,0,0,.42);
}

.sy-v2-product-label {
  display: block;
  padding: 9px 10px 13px;
  color: rgba(255,250,240,.48);
  font-size: 9px;
  letter-spacing: .18em;
}

.sy-v2-product-image {
  position: relative;
  height: 285px;
  overflow: hidden;
  background:
    radial-gradient(circle at 50% 50%, rgba(217,157,78,.32), transparent 45%),
    #211a12;
}

.sy-v2-product-image img {
  width: 100%;
  height: 100%;
  display: block;
  object-fit: cover;
  filter: saturate(.92) contrast(1.04);
}

.sy-v2-product-fallback {
  position: absolute;
  inset: 0;
  display: grid;
  place-items: center;
  color: rgba(255,250,240,.72);
  font-size: 18px;
  letter-spacing: .25em;
}

.sy-v2-product-meta {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 20px;
  padding: 18px 4px 15px;
}

.sy-v2-product-meta small {
  color: #c9985c;
  font-size: 9px;
  letter-spacing: .16em;
}

.sy-v2-product-meta h2 {
  margin: 6px 0 0;
  color: #fffaf0;
  font-size: 22px;
  font-weight: 500;
  letter-spacing: -.025em;
}

.sy-v2-product-meta > strong {
  color: #fffaf0;
  font-size: 18px;
  font-weight: 600;
}

.sy-v2-product-link {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 13px 5px 3px;
  border-top: 1px solid rgba(255,250,240,.12);
  color: rgba(255,250,240,.72);
  font-size: 11px;
  text-decoration: none;
  letter-spacing: .05em;
}

.sy-v2-product-link span {
  color: #e1a35f;
  font-size: 16px;
}

.sy-v2-stamp {
  position: absolute;
  right: -35px;
  top: 55px;
  width: 84px;
  height: 84px;
  display: grid;
  place-content: center;
  text-align: center;
  border: 1px solid rgba(232,173,104,.65);
  border-radius: 50%;
  background: rgba(20,16,11,.72);
  color: #e8ad68;
  font-size: 8px;
  line-height: 1.35;
  letter-spacing: .14em;
  transform: rotate(11deg);
}

.sy-v2-stamp span {
  font-size: 13px;
  margin-top: 2px;
}

.sy-v2-scroll {
  position: absolute;
  left: 6vw;
  bottom: 25px;
  display: flex;
  align-items: center;
  gap: 12px;
  color: rgba(255,250,240,.48);
  text-decoration: none;
  font-size: 9px;
  letter-spacing: .17em;
}

.sy-v2-scroll b {
  color: #e1a35f;
  font-size: 17px;
  font-weight: 400;
  animation: syV2Bounce 1.8s ease-in-out infinite;
}

@keyframes syV2Up {
  from { opacity: 0; transform: translateY(24px); }
  to { opacity: 1; transform: translateY(8px); }
}

@keyframes syV2Product {
  from { opacity: 0; transform: translateY(30px) scale(.97); }
  to { opacity: 1; transform: translateY(0) scale(1); }
}

@keyframes syV2Bounce {
  0%,100% { transform: translateY(0); }
  50% { transform: translateY(5px); }
}

@media (max-width: 980px) {
  .sy-landing-v2 {
    height: auto;
    min-height: 820px;
  }

  .sy-v2-inner {
    grid-template-columns: 1fr;
    gap: 44px;
    padding: 105px 0 80px;
  }

  .sy-v2-copy {
    max-width: 700px;
  }

  .sy-v2-product {
    justify-self: center;
    width: min(390px, 84vw);
  }

  .sy-v2-scroll {
    display: none;
  }
}

@media (max-width: 650px) {
  .sy-landing-v2 {
    min-height: auto;
  }

  .sy-v2-inner {
    width: 88vw;
    padding: 82px 0 62px;
  }

  .sy-v2-copy h1 {
    font-size: clamp(42px, 12vw, 58px);
    line-height: 1.02;
  }

  .sy-v2-description {
    font-size: 15px;
    line-height: 1.65;
  }

  .sy-v2-actions {
    align-items: flex-start;
    flex-direction: column;
    gap: 17px;
  }

  .sy-v2-primary {
    width: min(100%, 315px);
    justify-content: space-between;
  }

  .sy-v2-proof {
    gap: 13px;
    margin-top: 34px;
  }

  .sy-v2-proof i {
    height: 24px;
  }

  .sy-v2-proof span {
    font-size: 8px;
  }

  .sy-v2-product-image {
    height: 235px;
  }

  .sy-v2-product-orbit {
    width: 300px;
    height: 300px;
  }

  .sy-v2-stamp {
    right: -10px;
    top: 35px;
    width: 70px;
    height: 70px;
    font-size: 7px;
  }
}

@media (prefers-reduced-motion: reduce) {
  .sy-v2-copy,
  .sy-v2-product,
  .sy-v2-scroll b {
    animation: none !important;
  }
}
'@

# Avoid stacking duplicate copies if this patch is accidentally run twice.
$css = [regex]::Replace(
  $css,
  '(?s)\s*/\* =========================================================\s+SPICES OF YASH — LANDING PAGE V2.*$',
  '',
  1
)
$css += $cssPatch

$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($indexPath, $html, $utf8)
[System.IO.File]::WriteAllText($cssPath, $css, $utf8)

# Final validation. If anything fails, restore the exact previous frontend.
$finalHtml = [System.IO.File]::ReadAllText($indexPath)
$finalCss  = [System.IO.File]::ReadAllText($cssPath)

foreach ($marker in @('id="product-grid"', 'id="cart-open"', 'id="checkout-form"', 'sy-landing-v2', 'sy-v2-product-card')) {
  if (($finalHtml + "`n" + $finalCss) -notmatch [regex]::Escape($marker)) {
    Copy-Item -LiteralPath (Join-Path $backup "index.html") -Destination $indexPath -Force
    Copy-Item -LiteralPath (Join-Path $backup "styles.css") -Destination $cssPath -Force
    throw "Validation failed for $marker. Original frontend restored."
  }
}

Write-Host ""
Write-Host "SPICES OF YASH LANDING PAGE V2 APPLIED." -ForegroundColor Green
Write-Host "Changed: customer landing hero only + landing CSS." -ForegroundColor Green
Write-Host "Untouched: server.js, database, .env, app.js, admin, cart and checkout." -ForegroundColor Green
Write-Host ("Backup: " + $backup) -ForegroundColor Cyan
Write-Host ""
Write-Host "Start server with: npm start" -ForegroundColor Yellow
Write-Host "Then open: http://localhost:3000" -ForegroundColor Yellow
Write-Host "Hard refresh: Ctrl + Shift + R" -ForegroundColor Yellow
