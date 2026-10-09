param(
  [string]$ProjectPath = "D:\Project\Spices-of-Yash-Complete-Local-Project (1)\spices-of-yash-store"
)

$ErrorActionPreference = "Stop"

$indexPath = Join-Path $ProjectPath "public\index.html"
$cssPath   = Join-Path $ProjectPath "public\styles.css"

if (!(Test-Path -LiteralPath $indexPath)) { throw "public\index.html not found." }
if (!(Test-Path -LiteralPath $cssPath))   { throw "public\styles.css not found." }

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = Join-Path $ProjectPath ("frontend-video-landing-backup-" + $stamp)
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $indexPath -Destination (Join-Path $backup "index.html") -Force
Copy-Item -LiteralPath $cssPath   -Destination (Join-Path $backup "styles.css") -Force

$html = Get-Content -LiteralPath $indexPath -Raw
$css  = Get-Content -LiteralPath $cssPath -Raw

# Preserve existing storefront behavior. Only replace the visual hero.
foreach ($marker in @('id="product-grid"','id="cart-open"','id="checkout-form"')) {
  if (!$html.Contains($marker)) {
    throw "Required storefront marker missing: $marker. Nothing changed."
  }
}

$newHero = @'
<section class="hero hero-cinematic hero-video" aria-label="Spices of Yash">
  <video class="hero-video-bg" autoplay loop muted playsinline preload="metadata"
    poster="/images/story-spices.webp"
    aria-hidden="true">
    <source src="https://cdn.sceneai.art/Hero%20Section%20Video/01d1f8de-fec0-4bf5-8b48-9fc2dbc8c6b0.mp4" type="video/mp4">
  </video>
  <div class="hero-video-overlay" aria-hidden="true"></div>
  <div class="hero-grain" aria-hidden="true"></div>

  <div class="hero-copy hero-video-copy">
    <p class="eyebrow">AUTHENTIC INDIAN FLAVOUR</p>
    <h1>Bring Every Meal<br><em>To Life With Flavour</em></h1>
    <p class="hero-description">Discover carefully packed Indian spices for everyday kitchens, family recipes, restaurants and bulk buyers.</p>

    <div class="hero-ctas">
      <a class="btn btn-light hero-primary" href="#shop">Explore Our Spices</a>
      <a class="text-link hero-story-link" href="#story">Discover Our Story <span>-></span></a>
    </div>

    <div class="hero-trust">
      <span>Authentic Indian Spices</span>
      <span>Quality Packed</span>
      <span>Delivered Across India</span>
    </div>
  </div>
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

$videoCss = @'

/* Spices of Yash - cinematic video landing page */
html {
  scroll-behavior: smooth;
  scrollbar-width: none;
}
html::-webkit-scrollbar {
  width: 0;
  height: 0;
}
body {
  overflow-x: hidden;
}

.hero-video {
  position: relative;
  isolation: isolate;
  min-height: 100svh;
  height: 100svh;
  width: 100%;
  padding: 0 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  background: #17120d;
  color: #fffaf0;
}

.hero-video-bg {
  position: absolute;
  inset: 0;
  z-index: -3;
  width: 100%;
  height: 100%;
  object-fit: cover;
  object-position: center;
  background: #17120d;
}

.hero-video-overlay {
  position: absolute;
  inset: 0;
  z-index: -2;
  background:
    linear-gradient(
      to bottom,
      rgba(0,0,0,.10) 0%,
      rgba(0,0,0,.16) 35%,
      rgba(0,0,0,.40) 100%
    );
}

.hero-video-overlay:after {
  content: "";
  position: absolute;
  inset: 0;
  background:
    radial-gradient(circle at 50% 45%, rgba(0,0,0,0) 0%, rgba(0,0,0,.10) 48%, rgba(0,0,0,.30) 100%);
}

.hero-grain {
  position: absolute;
  inset: 0;
  z-index: -1;
  pointer-events: none;
  opacity: .10;
  background-image:
    radial-gradient(rgba(255,255,255,.8) .5px, transparent .5px);
  background-size: 5px 5px;
  mix-blend-mode: soft-light;
}

.hero-video-copy {
  width: min(900px, 100%);
  text-align: center;
  margin: 0 auto;
  transform: translateY(2vh);
  animation: spiceFadeUp .85s ease-out both;
}

.hero-video .eyebrow {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  margin: 0 0 22px;
  font-size: 12px;
  line-height: 1;
  letter-spacing: .22em;
  font-weight: 500;
  color: rgba(255,250,240,.88);
  text-transform: uppercase;
  animation: spiceFadeUp .7s .08s ease-out both;
}

.hero-video .eyebrow:before,
.hero-video .eyebrow:after {
  content: "";
  display: block;
  width: 34px;
  height: 1px;
  background: rgba(255,250,240,.55);
}

.hero-video h1 {
  margin: 0 auto;
  max-width: 850px;
  font-size: 56px;
  line-height: 1.10;
  letter-spacing: -.035em;
  font-weight: 500;
  color: #fffaf0;
  text-wrap: balance;
  animation: spiceFadeUp .8s .16s ease-out both;
}

.hero-video h1 em {
  color: #f2c078;
  font-style: normal;
}

.hero-video .hero-description {
  width: min(690px, 100%);
  margin: 24px auto 0;
  font-size: 18px;
  line-height: 1.65;
  font-weight: 400;
  color: rgba(255,250,240,.80);
  text-wrap: balance;
  animation: spiceFadeUp .8s .24s ease-out both;
}

.hero-video .hero-ctas {
  margin-top: 30px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 24px;
  animation: spiceFadeUp .8s .32s ease-out both;
}

.hero-video .hero-primary {
  min-height: 48px;
  padding: 12px 26px;
  background: #fffaf0;
  color: #16130f;
  border: 1px solid #fffaf0;
  box-shadow: 0 10px 30px rgba(0,0,0,.20);
  font-size: 15px;
  font-weight: 500;
  transition: transform .2s ease, box-shadow .2s ease;
}

.hero-video .hero-primary:hover {
  transform: scale(1.05);
  box-shadow: 0 16px 40px rgba(0,0,0,.30);
}

.hero-video .hero-story-link {
  color: rgba(255,250,240,.92);
  font-size: 15px;
  font-weight: 400;
  border-bottom-color: rgba(255,250,240,.55);
}

.hero-video .hero-story-link:hover {
  color: #fff;
  border-bottom-color: #fff;
}

.hero-video .hero-trust {
  margin-top: 38px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-wrap: wrap;
  gap: 0;
  color: rgba(255,250,240,.78);
  font-size: 12px;
  letter-spacing: .04em;
  animation: spiceFadeUp .8s .40s ease-out both;
}

.hero-video .hero-trust span {
  display: inline-flex;
  align-items: center;
}

.hero-video .hero-trust span + span:before {
  content: "";
  width: 4px;
  height: 4px;
  margin: 0 18px;
  border-radius: 50%;
  background: #e0a461;
}

@keyframes spiceFadeUp {
  from {
    opacity: 0;
    transform: translateY(18px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@media (max-width: 850px) {
  .hero-video {
    min-height: 100svh;
    height: 100svh;
    padding: 0 7%;
  }

  .hero-video h1 {
    font-size: 44px;
  }

  .hero-video .hero-description {
    font-size: 16px;
  }
}

@media (max-width: 650px) {
  .hero-video h1 {
    font-size: 38px;
    line-height: 1.1;
  }

  .hero-video .hero-description {
    font-size: 15px;
    line-height: 1.65;
  }

  .hero-video .hero-ctas {
    flex-direction: column;
    gap: 14px;
  }

  .hero-video .hero-primary {
    width: min(100%, 310px);
    justify-content: center;
  }

  .hero-video .hero-trust {
    max-width: 320px;
    margin-left: auto;
    margin-right: auto;
    line-height: 1.7;
  }

  .hero-video .hero-trust span + span:before {
    margin: 0 9px;
  }
}

@media (prefers-reduced-motion: reduce) {
  .hero-video-copy,
  .hero-video .eyebrow,
  .hero-video h1,
  .hero-video .hero-description,
  .hero-video .hero-ctas,
  .hero-video .hero-trust {
    animation: none !important;
  }
}
'@

if ($css -notmatch 'cinematic video landing page') {
  $css += $videoCss
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($indexPath, $html, $utf8)
[System.IO.File]::WriteAllText($cssPath, $css, $utf8)

Write-Host ""
Write-Host "SPICES OF YASH VIDEO LANDING PAGE APPLIED." -ForegroundColor Green
Write-Host "Frontend only: index.html and styles.css changed." -ForegroundColor Green
Write-Host "Backend, database, .env, payments and server.js were NOT changed." -ForegroundColor Green
Write-Host "Backup: $backup" -ForegroundColor Cyan
Write-Host "Now run: npm start" -ForegroundColor Yellow
Write-Host "Then open: http://localhost:3000" -ForegroundColor Yellow
