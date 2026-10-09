param(
  [string]$ProjectPath = "D:\Project\Spices-of-Yash-Complete-Local-Project (1)\spices-of-yash-store"
)

$ErrorActionPreference = "Stop"

$indexPath = Join-Path $ProjectPath "public\index.html"
$cssPath   = Join-Path $ProjectPath "public\styles.css"

if (!(Test-Path -LiteralPath $indexPath)) { throw "public\index.html not found." }
if (!(Test-Path -LiteralPath $cssPath)) { throw "public\styles.css not found." }

$html = Get-Content -LiteralPath $indexPath -Raw
$css  = Get-Content -LiteralPath $cssPath -Raw

# Safety gates: this is a storefront-only visual patch.
foreach ($marker in @('id="product-grid"','id="cart-open"','id="checkout-form"')) {
  if (!$html.Contains($marker)) {
    throw "Required storefront marker missing: $marker. Nothing changed."
  }
}

$heroMatches = [regex]::Matches($html, '(?s)<section\s+class="hero[^"]*"[^>]*>.*?</section>')
if ($heroMatches.Count -ne 1) {
  throw "Expected exactly one hero section. Found $($heroMatches.Count). Nothing changed."
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = Join-Path $ProjectPath ("frontend-spice-brand-backup-" + $stamp)
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $indexPath -Destination (Join-Path $backup "index.html") -Force
Copy-Item -LiteralPath $cssPath   -Destination (Join-Path $backup "styles.css") -Force

# Use an existing local spice image rather than the generic airline video.
$storyImage = Join-Path $ProjectPath "public\images\story-spices.webp"
$heroImage  = Join-Path $ProjectPath "public\images\hero-spices.webp"
$heroUrl = if (Test-Path -LiteralPath $storyImage) { "/images/story-spices.webp" } elseif (Test-Path -LiteralPath $heroImage) { "/images/hero-spices.webp" } else { "" }

if ($heroUrl -eq "") {
  throw "No local spice hero image found. Expected public\images\story-spices.webp or hero-spices.webp. Nothing changed."
}

$newHero = @"
<section class="hero hero-spice-brand" aria-label="Spices of Yash">
  <div class="spice-hero-bg" style="background-image:url('$heroUrl')" aria-hidden="true"></div>
  <div class="spice-hero-wash" aria-hidden="true"></div>
  <div class="spice-hero-glow" aria-hidden="true"></div>
  <div class="spice-particles" aria-hidden="true"><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i></div>

  <div class="spice-hero-inner">
    <div class="spice-hero-copy">
      <p class="eyebrow spice-eyebrow"><span></span> AUTHENTIC INDIAN FLAVOUR</p>
      <h1>Bring Every Meal<br><em>To Life With Flavour</em></h1>
      <p class="hero-description">Authentic Indian spices, carefully selected and packed to bring rich aroma, bold flavour and everyday goodness to your kitchen.</p>

      <div class="hero-ctas spice-hero-ctas">
        <a class="btn btn-light hero-primary" href="#shop">Explore Our Spices <span class="cta-arrow">→</span></a>
        <a class="text-link hero-story-link" href="#story">Discover Our Story <span>→</span></a>
      </div>

      <div class="spice-trust-row" aria-label="Why choose Spices of Yash">
        <span><b>01</b> Authentic Indian Spices</span>
        <span><b>02</b> Quality Packed</span>
        <span><b>03</b> Delivered Across India</span>
      </div>
    </div>

    <div class="spice-hero-side" aria-hidden="true">
      <div class="spice-side-card">
        <span class="side-kicker">THE SPICE PANTRY</span>
        <strong>From everyday tadka<br>to unforgettable feasts.</strong>
        <span class="side-rule"></span>
        <small>Whole spices · Ground spices · Signature blends</small>
      </div>
    </div>
  </div>

  <a class="scroll-cue" href="#shop" aria-label="Scroll to explore">
    <span>SCROLL</span>
    <b>↓</b>
    <span>TO EXPLORE</span>
  </a>
</section>
"@

$html = [regex]::Replace(
  $html,
  '(?s)<section\s+class="hero[^"]*"[^>]*>.*?</section>',
  [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $newHero },
  1
)

# Preserve the existing navigation links and cart behavior. The redesign styles the existing header in place.

$spiceCss = @'

/* =========================================================
   SPICES OF YASH — BRAND LANDING REDESIGN
   Visual-only storefront layer. Commerce IDs and JS untouched.
   ========================================================= */

:root{
  --spice-ink:#17170f;
  --spice-charcoal:#202018;
  --spice-cream:#f7f1e5;
  --spice-paper:#fbf8f1;
  --spice-saffron:#d28a2d;
  --spice-gold:#e1ad55;
  --spice-red:#8f3526;
  --spice-olive:#303b22;
  --spice-line:rgba(40,32,18,.14);
}

/* Global */
html{scroll-behavior:smooth;scrollbar-width:none}
html::-webkit-scrollbar{width:0;height:0}
body{overflow-x:hidden;background:var(--spice-paper);color:var(--spice-ink)}
::selection{background:#d28a2d;color:#17170f}

/* Cinematic transparent navigation */
.site-header{
  position:absolute!important;
  top:0;left:0;right:0;
  z-index:80;
  background:linear-gradient(to bottom,rgba(8,9,6,.72),rgba(8,9,6,0))!important;
  border-bottom:1px solid rgba(255,255,255,.10)!important;
  box-shadow:none!important;
  color:#fffaf0!important;
  backdrop-filter:none!important;
}
.site-header .brand,
.site-header .main-nav,
.site-header .cart-btn,
.site-header .icon-btn,
.site-header .menu-toggle{color:#fffaf0!important}
.site-header .brand small{color:rgba(255,250,240,.72)!important}
.site-header .brand-mark{color:#e0aa59!important}
.site-header .main-nav a{position:relative;color:rgba(255,250,240,.88)!important}
.site-header .main-nav a:after{
  background:#e1ad55!important;
  height:1px!important;
}
.site-header .main-nav a:hover{color:#fff!important}
.site-header .cart-btn{border-color:rgba(255,255,255,.42)!important;background:rgba(255,255,255,.07)!important}
.site-header .cart-btn span{background:#b95032!important;color:#fff!important}

/* Hero */
.hero-spice-brand{
  position:relative;
  isolation:isolate;
  min-height:100svh;
  height:100svh;
  width:100%;
  display:flex;
  align-items:center;
  overflow:hidden;
  background:#20170f;
  color:#fffaf0;
}
.spice-hero-bg{
  position:absolute;
  inset:0;
  z-index:-5;
  background-size:cover;
  background-position:center 48%;
  transform:scale(1.025);
  filter:saturate(1.08) contrast(1.04);
}
.spice-hero-wash{
  position:absolute;
  inset:0;
  z-index:-4;
  background:
    linear-gradient(90deg,rgba(15,13,8,.88) 0%,rgba(15,13,8,.63) 34%,rgba(15,13,8,.22) 64%,rgba(15,13,8,.38) 100%),
    linear-gradient(180deg,rgba(10,10,7,.22) 0%,rgba(10,10,7,.08) 45%,rgba(10,10,7,.70) 100%);
}
.spice-hero-glow{
  position:absolute;
  inset:-20%;
  z-index:-3;
  pointer-events:none;
  background:
    radial-gradient(circle at 72% 42%,rgba(222,158,54,.19),transparent 24%),
    radial-gradient(circle at 38% 72%,rgba(146,45,27,.14),transparent 25%);
  mix-blend-mode:screen;
}
.spice-hero-inner{
  width:min(1240px,88vw);
  margin:0 auto;
  padding:110px 0 70px;
  display:grid;
  grid-template-columns:minmax(0,1fr) 320px;
  gap:70px;
  align-items:end;
}
.spice-hero-copy{max-width:760px;text-align:left}
.spice-eyebrow{
  display:flex;
  align-items:center;
  gap:14px;
  margin:0 0 20px;
  color:#f0dfbf!important;
  letter-spacing:.22em!important;
  font-size:12px!important;
  font-weight:700!important;
}
.spice-eyebrow span{
  width:38px;height:1px;display:block;
  background:#dca354;
}
.hero-spice-brand h1{
  margin:0;
  max-width:820px;
  color:#fffaf0!important;
  font-size:clamp(50px,6.4vw,92px)!important;
  line-height:.96!important;
  letter-spacing:-.045em!important;
  font-weight:500!important;
  text-wrap:balance;
}
.hero-spice-brand h1 em{
  color:#e4b35d!important;
  font-style:italic!important;
  font-weight:400!important;
}
.hero-spice-brand .hero-description{
  max-width:620px;
  margin:28px 0 0!important;
  color:rgba(255,250,240,.82)!important;
  font-size:16px!important;
  line-height:1.72!important;
}
.spice-hero-ctas{
  display:flex;
  align-items:center;
  gap:28px;
  margin-top:30px!important;
}
.spice-hero-ctas .hero-primary{
  border:0!important;
  background:#fbf5e9!important;
  color:#18150f!important;
  padding:14px 23px!important;
  box-shadow:0 14px 40px rgba(0,0,0,.22)!important;
}
.spice-hero-ctas .hero-primary:hover{
  transform:translateY(-2px) scale(1.02)!important;
  box-shadow:0 20px 48px rgba(0,0,0,.30)!important;
}
.spice-hero-ctas .cta-arrow{margin-left:12px}
.spice-hero-ctas .hero-story-link{
  color:#fffaf0!important;
  border-color:rgba(255,255,255,.44)!important;
}
.spice-hero-ctas .hero-story-link:hover{color:#e7b867!important;border-color:#e7b867!important}
.spice-trust-row{
  display:flex;
  flex-wrap:wrap;
  gap:0;
  margin-top:48px;
  border-top:1px solid rgba(255,255,255,.18);
  padding-top:18px;
}
.spice-trust-row span{
  color:rgba(255,250,240,.74);
  font-size:12px;
  letter-spacing:.02em;
  padding-right:24px;
  margin-right:24px;
  border-right:1px solid rgba(255,255,255,.20);
}
.spice-trust-row span:last-child{border-right:0;margin-right:0;padding-right:0}
.spice-trust-row b{
  color:#e3ae58;
  font-size:10px;
  letter-spacing:.12em;
  margin-right:7px;
}
.spice-hero-side{
  align-self:end;
  padding-bottom:18px;
}
.spice-side-card{
  padding:22px 22px 20px;
  border:1px solid rgba(255,255,255,.18);
  background:rgba(20,17,11,.30);
  backdrop-filter:blur(12px);
  box-shadow:0 18px 60px rgba(0,0,0,.18);
}
.spice-side-card .side-kicker{
  display:block;
  color:#e1ad55;
  font-size:10px;
  font-weight:800;
  letter-spacing:.18em;
  margin-bottom:14px;
}
.spice-side-card strong{
  display:block;
  color:#fffaf0;
  font-size:21px;
  line-height:1.25;
  font-weight:500;
}
.spice-side-card .side-rule{
  display:block;
  width:46px;
  height:1px;
  background:#c97839;
  margin:18px 0 14px;
}
.spice-side-card small{
  color:rgba(255,250,240,.65);
  font-size:11px;
  line-height:1.6;
}
.scroll-cue{
  position:absolute;
  right:5vw;
  bottom:28px;
  display:flex;
  flex-direction:column;
  align-items:center;
  gap:5px;
  color:rgba(255,250,240,.62)!important;
  font-size:8px;
  letter-spacing:.18em;
  text-decoration:none!important;
}
.scroll-cue b{
  color:#e1ad55;
  font-size:18px;
  line-height:1;
  font-weight:400;
}
.spice-particles{position:absolute;inset:0;pointer-events:none;z-index:-1;opacity:.65}
.spice-particles i{
  position:absolute;
  width:3px;height:3px;border-radius:50%;
  background:#e7b65d;
  box-shadow:0 0 14px rgba(231,182,93,.55);
  animation:spice-float 7s ease-in-out infinite;
}
.spice-particles i:nth-child(1){left:59%;top:28%;animation-delay:-1s}
.spice-particles i:nth-child(2){left:68%;top:34%;width:2px;height:2px;animation-delay:-3s}
.spice-particles i:nth-child(3){left:76%;top:24%;width:4px;height:4px;animation-delay:-5s}
.spice-particles i:nth-child(4){left:84%;top:47%;width:2px;height:2px;animation-delay:-2s}
.spice-particles i:nth-child(5){left:54%;top:57%;width:2px;height:2px;animation-delay:-6s}
.spice-particles i:nth-child(6){left:91%;top:30%;width:3px;height:3px;animation-delay:-4s}
.spice-particles i:nth-child(7){left:72%;top:62%;width:2px;height:2px;animation-delay:-7s}
.spice-particles i:nth-child(8){left:63%;top:45%;width:2px;height:2px;animation-delay:-2.5s}
@keyframes spice-float{
  0%,100%{transform:translate3d(0,0,0);opacity:.25}
  50%{transform:translate3d(8px,-18px,0);opacity:.8}
}

/* Make the shop feel like the second act of a spice brand, not a generic store. */
#shop{
  background:var(--spice-paper)!important;
  color:var(--spice-ink)!important;
  padding-top:92px!important;
  padding-bottom:96px!important;
}
#shop:before{
  content:"OUR SIGNATURE RANGE";
  display:block;
  width:min(1180px,88vw);
  margin:0 auto 12px;
  color:#9a632e;
  font-size:10px;
  font-weight:800;
  letter-spacing:.24em;
}
#shop h2{
  color:#222015!important;
  letter-spacing:-.035em!important;
}
#shop h2 em,#shop h2 span{color:#a45d2d!important}
#product-grid>*{
  border:1px solid rgba(50,40,24,.09)!important;
  background:#fffdf8!important;
  box-shadow:0 10px 35px rgba(46,35,20,.06)!important;
  border-radius:2px!important;
  transition:transform .3s ease,box-shadow .3s ease,border-color .3s ease!important;
}
#product-grid>*:hover{
  transform:translateY(-8px)!important;
  box-shadow:0 24px 60px rgba(46,35,20,.13)!important;
  border-color:rgba(180,111,45,.28)!important;
}

/* Existing product images get a warm editorial treatment without changing their files. */
#product-grid img{
  transition:transform .55s cubic-bezier(.2,.7,.2,1),filter .35s ease;
}
#product-grid>*:hover img{transform:scale(1.035);filter:saturate(1.06)}
#product-grid .btn,#product-grid .button,#product-grid .primary-btn{
  background:#29321e!important;
  color:#fffaf0!important;
  border-color:#29321e!important;
}
#product-grid .btn:hover,#product-grid .button:hover,#product-grid .primary-btn:hover{
  background:#9b492e!important;
  border-color:#9b492e!important;
}

/* Mobile */
@media(max-width:900px){
  .spice-hero-inner{
    grid-template-columns:1fr;
    width:min(900px,88vw);
    padding:128px 0 70px;
    gap:24px;
  }
  .spice-hero-copy{max-width:720px}
  .spice-hero-side{display:none}
  .hero-spice-brand h1{font-size:clamp(46px,9vw,72px)!important}
  .spice-trust-row{margin-top:34px}
  .scroll-cue{right:24px}
}
@media(max-width:650px){
  .site-header{background:linear-gradient(to bottom,rgba(8,9,6,.86),rgba(8,9,6,.05))!important}
  .spice-hero-inner{width:86vw;padding:122px 0 62px}
  .hero-spice-brand h1{font-size:clamp(40px,12vw,58px)!important;line-height:1!important}
  .hero-spice-brand .hero-description{font-size:14px!important;line-height:1.65!important}
  .spice-hero-ctas{flex-direction:column;align-items:flex-start;gap:16px}
  .spice-hero-ctas .hero-primary{width:auto}
  .spice-trust-row{display:grid;grid-template-columns:1fr;gap:11px;border-top:0;padding-top:20px}
  .spice-trust-row span{border-right:0;border-left:1px solid rgba(255,255,255,.24);padding:2px 0 2px 12px;margin:0}
  .scroll-cue{display:none}
}
@media(prefers-reduced-motion:reduce){
  .spice-particles i{animation:none!important}
  .spice-hero-bg{transform:none}
  #product-grid>*{transition:none!important}
}

/* Keep the existing mobile menu readable on the cinematic background. */
.mobile-menu,.mobile-nav,.menu-panel{
  background:#1d2117!important;
  color:#fffaf0!important;
}
'@

if ($css -notmatch 'SPICES OF YASH — BRAND LANDING REDESIGN') {
  $css += $spiceCss
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($indexPath,$html,$utf8)
[System.IO.File]::WriteAllText($cssPath,$css,$utf8)

Write-Host ""
Write-Host "SPICES OF YASH BRAND LANDING REDESIGN APPLIED." -ForegroundColor Green
Write-Host "Frontend only: index.html and styles.css changed." -ForegroundColor Green
Write-Host "Backend, database, .env, payments and server.js were NOT changed." -ForegroundColor Green
Write-Host "Backup: $backup" -ForegroundColor Cyan
Write-Host "Refresh localhost with Ctrl+F5." -ForegroundColor Yellow
