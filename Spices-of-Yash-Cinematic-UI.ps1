param(
  [string]$ProjectPath = "D:\Project\Spices-of-Yash-Complete-Local-Project (1)\spices-of-yash-store"
)
$ErrorActionPreference = 'Stop'
if (!(Test-Path (Join-Path $ProjectPath 'package.json')) -or !(Test-Path (Join-Path $ProjectPath 'server.js'))) {
  $ProjectPath = Read-Host 'Paste the FULL path to spices-of-yash-store (folder containing package.json and server.js)'
}
$indexPath = Join-Path $ProjectPath 'public\index.html'
$cssPath = Join-Path $ProjectPath 'public\styles.css'
if (!(Test-Path $indexPath) -or !(Test-Path $cssPath)) { throw 'Expected public\index.html and public\styles.css were not found. Nothing changed.' }
$storyImage = Join-Path $ProjectPath 'public\images\story-spices.webp'
$heroImage = Join-Path $ProjectPath 'public\images\hero-spices.webp'
if (!(Test-Path $storyImage) -and !(Test-Path $heroImage)) { throw 'Neither public\images\story-spices.webp nor hero-spices.webp exists. Nothing changed.' }
$heroImageUrl = if (Test-Path $storyImage) { '/images/story-spices.webp' } else { '/images/hero-spices.webp' }
$html = Get-Content -LiteralPath $indexPath -Raw
$css = Get-Content -LiteralPath $cssPath -Raw
foreach ($marker in @('id="product-grid"','id="checkout-form"','id="cart-open"')) {
  if (!$html.Contains($marker)) { throw "Expected existing storefront marker missing ($marker). This UI patch is not compatible with this version. Nothing changed." }
}
if ([regex]::Matches($html, '(?s)<section\s+class="hero[^\"]*"[^>]*>.*?</section>').Count -ne 1) { throw 'Expected exactly one hero section. Nothing changed.' }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $ProjectPath "ui-backup-$stamp"
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $indexPath -Destination $backup
Copy-Item -LiteralPath $cssPath -Destination $backup
Write-Host "Backup created: $backup" -ForegroundColor Green

$newHero = @'
<section class="hero hero-cinematic" aria-label="Welcome to Spices of Yash">
  <div class="hero-art" aria-hidden="true"><div class="hero-photo"></div></div>
  <div class="hero-copy">
    <p class="eyebrow"><span></span> GOOD FOOD STARTS HERE</p>
    <h1>Bring every meal<br><em>to life with flavour.</em></h1>
    <p class="hero-description">Discover carefully packed Indian spices for everyday kitchens, family recipes, restaurants and bulk buyers.</p>
    <div class="hero-ctas"><a class="btn btn-light" href="#shop">Explore the pantry <span>↗</span></a><a class="text-link hero-story-link" href="#story">Our story <span>→</span></a></div>
    <div class="hero-note"><span class="note-icon">✳</span><div><strong>Small-batch goodness</strong><small>Big flavour for everyday cooking</small></div></div>
  </div>
</section>
'@
$html = [regex]::Replace($html, '(?s)<section\s+class="hero[^\"]*"[^>]*>.*?</section>', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $newHero }, 1)

$cinematicCss = @"

/* Spices of Yash cinematic hero — progressive enhancement; storefront IDs and checkout logic remain unchanged. */
.announcement{background:#171d13;color:#f8f4e9}
.site-header{background:#202719;color:#fffaf0;border-bottom:1px solid #ffffff18;box-shadow:none}
.site-header .brand small{color:#d2cdbb}
.site-header .brand-mark{color:#d9a66f}
.site-header .main-nav{color:#f6f0e3e8}
.site-header .main-nav a:hover{color:#e8b77e}
.site-header .cart-btn{border-color:#ffffff66;color:#fffaf0}
.site-header .cart-btn span{background:#c36a42}
.site-header .icon-btn,.site-header .menu-toggle{color:#fffaf0}
.hero-cinematic{position:relative;isolation:isolate;display:flex;align-items:center;justify-content:center;text-align:center;min-height:calc(100svh - 122px);padding:72px 7%;overflow:hidden;background:#202719;color:#fffaf0}
.hero-cinematic .hero-art{position:absolute;inset:0;z-index:-2;min-height:0;width:100%;max-width:none;margin:0}
.hero-cinematic .hero-photo{position:absolute;inset:0;border-radius:0;box-shadow:none;background-image:url('$heroImageUrl');background-position:center 43%;background-size:cover;transform:scale(1.015);animation:spiceHeroDrift 18s ease-in-out infinite alternate}
.hero-cinematic:before{content:"";position:absolute;inset:0;z-index:-1;background:linear-gradient(180deg,rgba(14,18,12,.30) 0%,rgba(14,18,12,.53) 52%,rgba(14,18,12,.82) 100%),linear-gradient(90deg,rgba(14,18,12,.32),rgba(14,18,12,.08),rgba(14,18,12,.32))}
.hero-cinematic .hero-copy{position:relative;z-index:1;max-width:850px;padding:0;animation:spiceFadeUp .8s both}
.hero-cinematic .eyebrow{color:#e8bd8c;font-size:10px;letter-spacing:.24em;margin-bottom:24px;animation:spiceFadeUp .8s .08s both}
.hero-cinematic .eyebrow span{background:#e8bd8c}
.hero-cinematic h1{font-family:var(--sans);font-weight:500;font-size:clamp(38px,5.2vw,56px);line-height:1.1;letter-spacing:-.045em;color:#fffaf0;margin:0 auto 20px;animation:spiceFadeUp .8s .18s both}
.hero-cinematic h1 em{font-style:normal;color:#f0c28e;font-weight:500}
.hero-cinematic .hero-description{font-size:clamp(15px,1.5vw,18px);line-height:1.75;color:#fffaf0cc;max-width:620px;margin:0 auto;animation:spiceFadeUp .8s .28s both}
.hero-cinematic .hero-ctas{justify-content:center;flex-wrap:wrap;margin-top:32px;gap:14px;animation:spiceFadeUp .8s .38s both}
.hero-cinematic .btn{font-size:15px;font-weight:500;letter-spacing:0;padding:12px 26px;gap:18px;transition:transform .22s,box-shadow .22s,background .22s}
.hero-cinematic .btn-light{background:#fff;color:#171d13;box-shadow:0 8px 24px #0003}
.hero-cinematic .btn-light:hover{background:#f4e9d7;transform:scale(1.05);box-shadow:0 14px 32px #0005}
.hero-cinematic .hero-story-link{color:#fffaf0;border-color:#ffffff8c;font-size:13px;padding:10px 2px}
.hero-cinematic .hero-story-link:hover{color:#f0c28e;border-color:#f0c28e}
.hero-cinematic .hero-note{justify-content:center;margin-top:34px;color:#fffaf0;animation:spiceFadeUp .8s .48s both}
.hero-cinematic .note-icon{color:#f0c28e}
.hero-cinematic .hero-note strong{font-family:var(--sans);font-size:11px;font-weight:600;letter-spacing:.04em}
.hero-cinematic .hero-note small{color:#fffaf0b8;font-size:10px}
.hero-cinematic .hero-sticker,.hero-cinematic .hero-caption{display:none}
@keyframes spiceFadeUp{from{opacity:0;transform:translateY(18px)}to{opacity:1;transform:translateY(0)}}
@keyframes spiceHeroDrift{from{transform:scale(1.015)}to{transform:scale(1.075)}}
@media(max-width:650px){.site-header .main-nav{background:#202719;color:#fffaf0;border-color:#ffffff22}.hero-cinematic{min-height:calc(100svh - 104px);padding:58px 7% 52px}.hero-cinematic h1{font-size:38px;line-height:1.1}.hero-cinematic .hero-description{font-size:15px;line-height:1.7}.hero-cinematic .hero-ctas{gap:12px}.hero-cinematic .hero-note{margin-top:27px}.hero-cinematic .hero-photo{background-position:54% center}}
@media(prefers-reduced-motion:reduce){.hero-cinematic .hero-copy,.hero-cinematic .eyebrow,.hero-cinematic h1,.hero-cinematic .hero-description,.hero-cinematic .hero-ctas,.hero-cinematic .hero-note,.hero-cinematic .hero-photo{animation:none!important;transition:none!important}}
"@
if ($css -notmatch 'Spices of Yash cinematic hero') { Add-Content -LiteralPath $cssPath -Value $cinematicCss -Encoding UTF8 }
Set-Content -LiteralPath $indexPath -Value $html -Encoding UTF8
try {
  Write-Host 'Running safe source checks...' -ForegroundColor Cyan
  & node --check (Join-Path $ProjectPath 'public\app.js')
  if ($LASTEXITCODE -ne 0) { throw 'Frontend JS syntax check failed.' }
  & node --check (Join-Path $ProjectPath 'server.js')
  if ($LASTEXITCODE -ne 0) { throw 'Backend JS syntax check failed.' }
  & npm test
  if ($LASTEXITCODE -ne 0) { throw 'npm test failed after the UI change.' }
} catch {
  Copy-Item -LiteralPath (Join-Path $backup 'index.html') -Destination $indexPath -Force
  Copy-Item -LiteralPath (Join-Path $backup 'styles.css') -Destination $cssPath -Force
  Write-Host "UI changes rolled back. Original files restored from $backup" -ForegroundColor Yellow
  throw
}
Write-Host 'Cinematic hero applied; product grid, cart and checkout markup preserved; syntax and npm test passed.' -ForegroundColor Green
Write-Host "Backup: $backup"
