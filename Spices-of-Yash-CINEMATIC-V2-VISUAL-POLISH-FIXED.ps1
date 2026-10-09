param(
  [string]$ProjectPath = "D:\Project\Spices-of-Yash-Complete-Local-Project (1)\spices-of-yash-store"
)

$ErrorActionPreference = "Stop"
$public = Join-Path $ProjectPath "public"
$indexPath = Join-Path $public "index.html"
$cssPath = Join-Path $public "styles.css"

if (!(Test-Path -LiteralPath $indexPath) -or !(Test-Path -LiteralPath $cssPath)) {
  throw "public/index.html or public/styles.css was not found."
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = Join-Path $ProjectPath ("frontend-v2-backup-" + $stamp)
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $indexPath -Destination (Join-Path $backup "index.html")
Copy-Item -LiteralPath $cssPath -Destination (Join-Path $backup "styles.css")

$html = [System.IO.File]::ReadAllText($indexPath)
$css = [System.IO.File]::ReadAllText($cssPath)

if ($html -notmatch 'id="product-grid"') {
  throw "Safety check failed: product-grid marker not found. Nothing changed."
}
if ($html -notmatch 'id="checkout-form"') {
  throw "Safety check failed: checkout-form marker not found. Nothing changed."
}
if ($html -notmatch 'id="cart-open"') {
  throw "Safety check failed: cart-open marker not found. Nothing changed."
}

# Ensure UTF-8 declaration.
if ($html -notmatch '(?i)<meta\s+charset\s*=') {
  $html = [regex]::Replace(
    $html,
    '(?i)<head([^>]*)>',
    '<head$1>`r`n<meta charset="UTF-8">',
    1
  )
}

# Remove the common replacement character if it exists.
$html = $html.Replace([string][char]0xFFFD, "")

# Add cinematic particles and a warm light sweep to the existing hero.
$motionLayer = @'
<div class="sy-v2-particles" aria-hidden="true">
  <i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i>
</div>
<div class="sy-v2-light-sweep" aria-hidden="true"></div>
<div class="sy-v2-hero-edge" aria-hidden="true"></div>
'@

if ($html -notmatch 'sy-v2-particles') {
  $heroOpen = '(?s)(<section\s+class="[^"]*hero[^"]*"[^>]*>)'
  if ([regex]::Matches($html, $heroOpen).Count -lt 1) {
    throw "Could not find the hero section safely. Nothing changed."
  }
  $html = [regex]::Replace(
    $html,
    $heroOpen,
    [System.Text.RegularExpressions.MatchEvaluator]{
      param($m)
      $m.Value + $motionLayer
    },
    1
  )
}

# Add a premium editorial card inside the hero.
$heroCard = @'
<div class="sy-v2-hero-card" aria-hidden="true">
  <span class="sy-v2-card-index">01</span>
  <strong>Ground with care</strong>
  <small>Whole spices / Ground spices / Signature blends</small>
  <span class="sy-v2-card-line"></span>
</div>
'@

if ($html -notmatch 'sy-v2-hero-card') {
  $heroClose = '(?s)(</section>)'
  $html = [regex]::Replace(
    $html,
    $heroClose,
    [System.Text.RegularExpressions.MatchEvaluator]{
      param($m)
      $heroCard + $m.Value
    },
    1
  )
}

# Add an editorial transition immediately before the existing product grid.
if ($html -notmatch 'sy-v2-pantry-intro') {
  $intro = @'
<section class="sy-v2-pantry-intro" aria-label="The Spice Pantry">
  <div class="sy-v2-pantry-kicker"><span></span> FROM THE SPICE PANTRY <span></span></div>
  <h2>Colour, aroma,<br><em>character.</em></h2>
  <p>Every spice has a place at the table. Explore everyday essentials selected for rich flavour, honest quality and Indian kitchens.</p>
</section>
'@
  $gridMarker = '<div id="product-grid"'
  $html = [regex]::Replace(
    $html,
    [regex]::Escape($gridMarker),
    [System.Text.RegularExpressions.MatchEvaluator]{
      param($m)
      $intro + "`r`n" + $m.Value
    },
    1
  )
}

# Add a narrow spice marquee before the existing product grid.
if ($html -notmatch 'sy-v2-marquee') {
  $marquee = @'
<div class="sy-v2-marquee" aria-hidden="true">
  <span>WHOLE SPICES</span><b>*</b><span>GROUND WITH CARE</span><b>*</b><span>INDIAN FLAVOUR</span><b>*</b><span>PACKED FRESH</span><b>*</b>
</div>
'@
  $gridMarker = '<div id="product-grid"'
  $html = [regex]::Replace(
    $html,
    [regex]::Escape($gridMarker),
    [System.Text.RegularExpressions.MatchEvaluator]{
      param($m)
      $marquee + "`r`n" + $m.Value
    },
    1
  )
}

$cssPatch = @'

/* =========================================================
   SPICES OF YASH - CINEMATIC V2 VISUAL POLISH
   Frontend only. Existing ecommerce markup and logic preserved.
   ========================================================= */

:root {
  --sy-ink: #160d08;
  --sy-ink-2: #24130c;
  --sy-cream: #fff8ea;
  --sy-gold: #e8b75a;
  --sy-gold-soft: #f2d18a;
  --sy-red: #b3361f;
  --sy-muted: #8f7965;
  --sy-border: rgba(232,183,90,.22);
}

html { scroll-behavior: smooth; }
body { overflow-x: hidden; background: var(--sy-cream); }

.sy-v2-particles {
  position: absolute;
  inset: 0;
  z-index: 2;
  pointer-events: none;
  overflow: hidden;
}
.sy-v2-particles i {
  position: absolute;
  width: 3px;
  height: 3px;
  border-radius: 50%;
  background: rgba(232,183,90,.72);
  box-shadow: 0 0 12px rgba(232,183,90,.48);
  animation: syV2Float 7s ease-in-out infinite;
}
.sy-v2-particles i:nth-child(1){left:9%;top:72%;animation-delay:-1s}
.sy-v2-particles i:nth-child(2){left:18%;top:34%;animation-delay:-4s}
.sy-v2-particles i:nth-child(3){left:31%;top:79%;animation-delay:-2s}
.sy-v2-particles i:nth-child(4){left:47%;top:25%;animation-delay:-5s}
.sy-v2-particles i:nth-child(5){left:58%;top:68%;animation-delay:-3s}
.sy-v2-particles i:nth-child(6){left:69%;top:39%;animation-delay:-6s}
.sy-v2-particles i:nth-child(7){left:78%;top:76%;animation-delay:-2.5s}
.sy-v2-particles i:nth-child(8){left:86%;top:28%;animation-delay:-4.5s}
.sy-v2-particles i:nth-child(9){left:92%;top:63%;animation-delay:-1.8s}
.sy-v2-particles i:nth-child(10){left:38%;top:53%;animation-delay:-5.5s}

@keyframes syV2Float {
  0%,100% { opacity:.15; transform:translate3d(0,10px,0) scale(.7); }
  50% { opacity:.9; transform:translate3d(18px,-26px,0) scale(1.15); }
}

.sy-v2-light-sweep {
  position:absolute;
  inset:-20%;
  z-index:1;
  pointer-events:none;
  background:linear-gradient(108deg,transparent 36%,rgba(232,183,90,.07) 47%,rgba(255,248,234,.10) 50%,transparent 61%);
  transform:translateX(-55%);
  animation:syV2Sweep 10s ease-in-out infinite;
}
@keyframes syV2Sweep {
  0%,25% { transform:translateX(-55%); opacity:0; }
  38% { opacity:1; }
  62% { opacity:1; }
  78%,100% { transform:translateX(55%); opacity:0; }
}

.sy-v2-hero-edge {
  position:absolute;
  inset:0;
  z-index:1;
  pointer-events:none;
  border:1px solid rgba(232,183,90,.09);
  box-shadow:inset 0 0 150px rgba(0,0,0,.38);
}

.hero-cinematic {
  background:var(--sy-ink)!important;
  min-height:calc(100svh - 80px)!important;
  overflow:hidden!important;
}
.hero-cinematic .hero-photo {
  filter:saturate(1.08) contrast(1.08) brightness(.78)!important;
  transform:scale(1.035)!important;
  animation:syV2KenBurns 18s ease-in-out infinite alternate!important;
}
@keyframes syV2KenBurns {
  from { transform:scale(1.035) translate3d(-.4%,0,0); }
  to { transform:scale(1.11) translate3d(.8%,-.8%,0); }
}
.hero-cinematic:before {
  content:"";
  position:absolute;
  inset:0;
  z-index:0;
  pointer-events:none;
  background:
    linear-gradient(90deg,rgba(22,13,8,.92) 0%,rgba(22,13,8,.70) 36%,rgba(22,13,8,.30) 68%,rgba(22,13,8,.68) 100%),
    linear-gradient(180deg,rgba(12,7,4,.46) 0%,transparent 34%,rgba(12,7,4,.62) 100%);
}
.hero-cinematic .hero-copy {
  position:relative;
  z-index:4;
  max-width:900px!important;
  text-align:left!important;
}
.hero-cinematic h1 {
  max-width:900px;
  letter-spacing:-.045em!important;
  text-shadow:0 5px 28px rgba(0,0,0,.28);
}
.hero-cinematic .hero-description {
  max-width:650px!important;
  color:rgba(255,248,234,.84)!important;
}
.hero-cinematic .hero-ctas {
  align-items:center!important;
}
.hero-cinematic .btn-light {
  box-shadow:0 12px 40px rgba(0,0,0,.20);
  transition:transform .35s ease,box-shadow .35s ease,background .35s ease!important;
}
.hero-cinematic .btn-light:hover {
  transform:translateY(-3px);
  box-shadow:0 18px 52px rgba(0,0,0,.32);
}
.hero-cinematic .hero-story-link {
  transition:color .3s ease,border-color .3s ease,transform .3s ease!important;
}
.hero-cinematic .hero-story-link:hover {
  color:var(--sy-gold-soft)!important;
  transform:translateX(4px);
}

.sy-v2-hero-card {
  position:absolute;
  right:7%;
  bottom:14%;
  z-index:5;
  width:235px;
  padding:24px 22px 20px;
  color:var(--sy-cream);
  background:rgba(22,13,8,.54);
  border:1px solid rgba(232,183,90,.28);
  backdrop-filter:blur(12px);
  box-shadow:0 24px 70px rgba(0,0,0,.30);
  animation:syV2CardIn 1.2s .7s both cubic-bezier(.2,.75,.25,1);
}
.sy-v2-card-index {
  display:block;
  color:var(--sy-gold);
  font-size:11px;
  letter-spacing:.24em;
  margin-bottom:18px;
}
.sy-v2-hero-card strong {
  display:block;
  font-family:Georgia,serif;
  font-size:27px;
  line-height:1.02;
  font-weight:500;
}
.sy-v2-hero-card small {
  display:block;
  margin-top:15px;
  color:rgba(255,248,234,.68);
  font-size:11px;
  line-height:1.55;
}
.sy-v2-card-line {
  display:block;
  width:38px;
  height:1px;
  margin-top:20px;
  background:var(--sy-gold);
}
@keyframes syV2CardIn {
  from { opacity:0; transform:translateY(24px); }
  to { opacity:1; transform:translateY(0); }
}

.sy-v2-pantry-intro {
  padding:120px 8% 48px;
  text-align:center;
  background:
    radial-gradient(circle at 50% 0,rgba(232,183,90,.13),transparent 34%),
    var(--sy-cream);
}
.sy-v2-pantry-kicker {
  display:flex;
  align-items:center;
  justify-content:center;
  gap:14px;
  color:#9b542f;
  font-size:11px;
  font-weight:700;
  letter-spacing:.25em;
}
.sy-v2-pantry-kicker span {
  width:38px;
  height:1px;
  background:#c88755;
}
.sy-v2-pantry-intro h2 {
  margin:20px auto 18px;
  max-width:850px;
  color:#241b14;
  font-family:Georgia,serif;
  font-size:clamp(52px,7vw,94px);
  font-weight:400;
  line-height:.94;
  letter-spacing:-.055em;
}
.sy-v2-pantry-intro h2 em {
  color:#ad592e;
}
.sy-v2-pantry-intro p {
  max-width:590px;
  margin:0 auto;
  color:#776858;
  font-size:16px;
  line-height:1.75;
}

.sy-v2-marquee {
  display:flex;
  justify-content:center;
  align-items:center;
  gap:20px;
  padding:18px 5%;
  overflow:hidden;
  background:#21130c;
  color:#f1d39a;
  font-size:10px;
  font-weight:700;
  letter-spacing:.24em;
}
.sy-v2-marquee b { color:#b3361f; }

#product-grid {
  scroll-margin-top:90px;
}
#product-grid > * {
  transition:transform .38s cubic-bezier(.2,.7,.2,1),box-shadow .38s ease!important;
}
#product-grid > *:hover {
  transform:translateY(-8px)!important;
  box-shadow:0 22px 48px rgba(74,42,22,.13)!important;
}
#product-grid img {
  transition:transform .7s cubic-bezier(.2,.7,.2,1),filter .5s ease!important;
}
#product-grid > *:hover img {
  transform:scale(1.045);
  filter:saturate(1.06);
}

@media (max-width:900px) {
  .hero-cinematic .hero-copy { max-width:720px!important; }
  .sy-v2-hero-card {
    right:5%;
    bottom:9%;
    width:190px;
    padding:18px;
  }
}
@media (max-width:700px) {
  .hero-cinematic {
    min-height:calc(100svh - 68px)!important;
    padding:78px 7% 110px!important;
    align-items:flex-end!important;
  }
  .hero-cinematic .hero-copy { text-align:left!important; }
  .hero-cinematic h1 { font-size:clamp(43px,12vw,64px)!important; }
  .hero-cinematic .hero-description { font-size:15px!important; }
  .sy-v2-hero-card { display:none; }
  .sy-v2-pantry-intro { padding:84px 7% 36px; }
  .sy-v2-pantry-intro h2 { font-size:clamp(48px,15vw,68px); }
  .sy-v2-marquee {
    gap:12px;
    white-space:nowrap;
    font-size:8px;
  }
}
@media (prefers-reduced-motion:reduce) {
  html { scroll-behavior:auto; }
  .sy-v2-light-sweep,
  .sy-v2-particles i,
  .sy-v2-hero-card,
  .hero-cinematic .hero-photo {
    animation:none!important;
  }
  #product-grid > *,
  #product-grid img {
    transition:none!important;
  }
}
'@

if ($css -notmatch 'CINEMATIC V2 VISUAL POLISH') {
  $css += $cssPatch
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($indexPath,$html,$utf8)
[System.IO.File]::WriteAllText($cssPath,$css,$utf8)

Write-Host ""
Write-Host "SPICES OF YASH CINEMATIC V2 APPLIED SUCCESSFULLY." -ForegroundColor Green
Write-Host "Visible changes: hero depth, spice dust, light sweep, editorial card, pantry transition, marquee, product hover and mobile refinement." -ForegroundColor Green
Write-Host "Frontend only: public/index.html and public/styles.css changed." -ForegroundColor Green
Write-Host "Backend, database, .env, server.js, app.js and package files were NOT changed." -ForegroundColor Green
Write-Host ("Backup: " + $backup) -ForegroundColor Cyan
Write-Host "Hard refresh localhost with Ctrl+F5." -ForegroundColor Yellow
