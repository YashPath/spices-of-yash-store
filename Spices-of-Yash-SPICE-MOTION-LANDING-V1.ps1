param(
  [string]$ProjectPath = "D:\Project\Spices-of-Yash-Complete-Local-Project (1)\spices-of-yash-store"
)

$ErrorActionPreference = "Stop"

$indexPath = Join-Path $ProjectPath "public\index.html"
$cssPath   = Join-Path $ProjectPath "public\styles.css"
$imagesDir = Join-Path $ProjectPath "public\images"

if (!(Test-Path -LiteralPath $indexPath)) { throw "public\index.html not found. Nothing changed." }
if (!(Test-Path -LiteralPath $cssPath))   { throw "public\styles.css not found. Nothing changed." }

$html = Get-Content -LiteralPath $indexPath -Raw
$css  = Get-Content -LiteralPath $cssPath -Raw

foreach ($marker in @('id="product-grid"','id="cart-open"','id="checkout-form"')) {
  if (!$html.Contains($marker)) { throw "Required storefront marker missing: $marker. Nothing changed." }
}

$heroPattern = '(?s)<section\s+class="hero[^"]*"[^>]*>.*?</section>'
$heroMatches = [regex]::Matches($html, $heroPattern)
if ($heroMatches.Count -ne 1) {
  throw "Expected exactly one hero section. Found $($heroMatches.Count). Nothing changed."
}

# Find the best existing local spice image.
$imageNames = @(
  "story-spices.webp","hero-spices.webp",
  "green-cardamom.webp","kashmiri-red-chilli.webp",
  "turmeric.webp","cumin.webp","black-pepper.webp","garam-masala.webp"
)
$heroImageUrl = $null
foreach ($name in $imageNames) {
  if (Test-Path -LiteralPath (Join-Path $imagesDir $name)) {
    $heroImageUrl = "/images/$name"
    break
  }
}
if (!$heroImageUrl) {
  throw "No suitable local spice image was found in public\images. Nothing changed."
}

# Backup before any write.
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = Join-Path $ProjectPath ("spice-motion-landing-backup-" + $stamp)
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $indexPath -Destination (Join-Path $backup "index.html") -Force
Copy-Item -LiteralPath $cssPath -Destination (Join-Path $backup "styles.css") -Force

# Repair common mojibake in existing HTML/CSS.
$fixes = [ordered]@{
  'Ã¢â‚¬â„¢' = '’'
  'Ã¢â‚¬Å“' = '“'
  'Ã¢â‚¬Â' = '”'
  'Ã¢â‚¬â€œ' = '–'
  'Ã¢â‚¬â€' = '—'
  'Ã¢â‚¬Â¢' = '•'
  'Â·' = '·'
  'â†’' = '→'
  'â†' = '←'
  'â†‘' = '↑'
  'â†“' = '↓'
  'â€¢' = '·'
  'âœ“' = '✓'
  'âœ³' = '✳'
}
foreach ($pair in $fixes.GetEnumerator()) {
  $html = $html.Replace($pair.Key, $pair.Value)
  $css  = $css.Replace($pair.Key, $pair.Value)
}

# Ensure charset.
if ($html -notmatch '(?is)<meta\s+charset\s*=') {
  $html = [regex]::Replace($html,'(?is)(<head\b[^>]*>)','$1' + "`r`n" + '<meta charset="UTF-8">',1)
} else {
  $html = [regex]::Replace($html,'(?is)<meta\s+charset\s*=\s*["''][^"'']*["'']\s*/?>','<meta charset="UTF-8">',1)
}

# New spice-brand hero: no airplane imagery, no external video.
$newHero = @"
<section class="hero sy-spice-motion" aria-label="Spices of Yash">
  <div class="sy-hero-image" aria-hidden="true"></div>
  <div class="sy-hero-dark" aria-hidden="true"></div>

  <div class="sy-ingredient ingredient-turmeric">TURMERIC</div>
  <div class="sy-ingredient ingredient-chilli">CHILLI</div>
  <div class="sy-ingredient ingredient-cardamom">CARDAMOM</div>
  <div class="sy-ingredient ingredient-cumin">CUMIN</div>

  <div class="sy-spice-grain" aria-hidden="true"></div>
  <div class="sy-spice-dust" aria-hidden="true">
    <i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i>
  </div>

  <div class="hero-copy sy-motion-copy">
    <div class="sy-brand-kicker"><span></span> THE SPICE PANTRY <span></span></div>
    <p class="eyebrow sy-motion-eyebrow">AUTHENTIC INDIAN FLAVOUR</p>
    <h1>Bring Every Meal<br><em>To Life With Flavour</em></h1>
    <p class="hero-description">Discover carefully packed Indian spices for everyday kitchens, family recipes, restaurants and bulk buyers.</p>

    <div class="hero-ctas">
      <a class="btn btn-light hero-primary" href="#shop">Explore Our Spices <span class="sy-arrow">&#8594;</span></a>
      <a class="text-link hero-story-link" href="#story">Discover Our Story <span>&#8594;</span></a>
    </div>

    <div class="hero-trust">
      <span>Authentic Indian Spices</span>
      <span>Quality Packed</span>
      <span>Delivered Across India</span>
    </div>
  </div>

  <div class="sy-hero-badge" aria-hidden="true">
    <span>01</span>
    <strong>GROUND<br>WITH CARE</strong>
    <small>Whole spices &amp; signature blends</small>
  </div>

  <div class="sy-scroll" aria-hidden="true">
    <span>SCROLL</span><i></i>
  </div>
</section>
"@

$html = [regex]::Replace(
  $html,
  $heroPattern,
  [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $newHero },
  1
)

# Add a spice-motion transition immediately before the existing shop section.
$transition = @'
<section class="sy-spice-transition" aria-hidden="true">
  <div class="sy-transition-line"></div>
  <div class="sy-marquee">
    <span>WHOLE SPICES</span><b>·</b>
    <span>GROUND SPICES</span><b>·</b>
    <span>SIGNATURE BLENDS</span><b>·</b>
    <span>AUTHENTIC INDIAN FLAVOUR</span><b>·</b>
    <span>WHOLE SPICES</span><b>·</b>
    <span>GROUND SPICES</span><b>·</b>
    <span>SIGNATURE BLENDS</span><b>·</b>
    <span>AUTHENTIC INDIAN FLAVOUR</span><b>·</b>
  </div>
</section>
'@

if ($html -notmatch 'class="sy-spice-transition"') {
  if ($html -match '(?is)<section[^>]*id="shop"') {
    $html = [regex]::Replace(
      $html,
      '(?is)(<section[^>]*id="shop")',
      [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $transition + "`r`n" + $m.Groups[1].Value },
      1
    )
  } elseif ($html -match '(?is)<section[^>]*class="[^"]*(products|shop)[^"]*"') {
    $html = [regex]::Replace(
      $html,
      '(?is)(<section[^>]*class="[^"]*(?:products|shop)[^"]*")',
      [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $transition + "`r`n" + $m.Groups[1].Value },
      1
    )
  }
}

$cssPatch = @"

/* =========================================================
   SPICES OF YASH — SPICE MOTION LANDING
   Frontend-only visual system. Storefront behavior untouched.
   ========================================================= */

:root{
  --sy-ink:#17110d;
  --sy-brown:#24140c;
  --sy-brown-deep:#120906;
  --sy-gold:#e8b75a;
  --sy-gold-soft:#f2d18a;
  --sy-red:#b3361f;
  --sy-cream:#fff8ea;
  --sy-muted:#d9cbbb;
}

html{scroll-behavior:smooth}
body{overflow-x:hidden}
html::-webkit-scrollbar{width:0;height:0}
html{scrollbar-width:none}

/* Header becomes part of the spice-brand world without changing its links/buttons. */
.site-header{
  background:rgba(23,17,13,.94)!important;
  color:var(--sy-cream)!important;
  border-bottom:1px solid rgba(255,248,234,.10)!important;
  box-shadow:0 10px 35px rgba(0,0,0,.12)!important;
  backdrop-filter:blur(12px);
}
.announcement{
  background:#18120e!important;
  color:#f3e5d2!important;
}

/* Main animated hero */
.sy-spice-motion{
  position:relative!important;
  min-height:calc(100svh - 80px)!important;
  isolation:isolate;
  overflow:hidden;
  display:flex!important;
  align-items:center!important;
  justify-content:flex-start!important;
  padding:82px clamp(24px,7vw,110px)!important;
  background:var(--sy-brown-deep)!important;
  color:var(--sy-cream)!important;
}

.sy-hero-image{
  position:absolute;
  inset:-4%;
  z-index:-5;
  background-image:url("$heroImageUrl");
  background-size:cover;
  background-position:center;
  filter:saturate(1.12) contrast(1.08);
  transform:scale(1.04);
  animation:syCameraMove 20s ease-in-out infinite alternate;
  will-change:transform;
}

.sy-hero-dark{
  position:absolute;
  inset:0;
  z-index:-4;
  background:
    radial-gradient(circle at 70% 45%,rgba(179,54,31,.16),transparent 31%),
    radial-gradient(circle at 24% 62%,rgba(232,183,90,.10),transparent 28%),
    linear-gradient(90deg,rgba(18,9,6,.92) 0%,rgba(18,9,6,.66) 44%,rgba(18,9,6,.30) 76%,rgba(18,9,6,.58) 100%),
    linear-gradient(180deg,rgba(18,9,6,.22),rgba(18,9,6,.72));
}

.sy-hero-dark:after{
  content:"";
  position:absolute;
  inset:-10%;
  background:radial-gradient(circle at 52% 50%,transparent 0 25%,rgba(0,0,0,.14) 54%,rgba(0,0,0,.54) 100%);
}

.sy-spice-grain{
  position:absolute;
  inset:0;
  z-index:2;
  pointer-events:none;
  opacity:.08;
  background-image:url("data:image/svg+xml,%3Csvg viewBox='0 0 180 180' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.85' numOctaves='3' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='.45'/%3E%3C/svg%3E");
  mix-blend-mode:soft-light;
  animation:syGrain .35s steps(2) infinite;
}

.sy-motion-copy{
  position:relative!important;
  z-index:8!important;
  width:min(760px,100%);
  max-width:760px!important;
  text-align:left!important;
  animation:syHeroReveal 1s cubic-bezier(.22,.61,.36,1) both;
}

.sy-brand-kicker{
  display:flex;
  align-items:center;
  gap:12px;
  color:var(--sy-gold-soft);
  font-size:9px;
  font-weight:800;
  letter-spacing:.28em;
  margin-bottom:18px;
  animation:syRevealLeft .8s .05s both;
}
.sy-brand-kicker span{
  width:28px;
  height:1px;
  background:var(--sy-gold);
  display:block;
}

.sy-motion-eyebrow{
  color:#fff1d7!important;
  letter-spacing:.25em!important;
  font-size:11px!important;
  margin-bottom:20px!important;
  animation:syRevealLeft .8s .14s both;
}

.sy-motion-copy h1{
  margin:0 0 22px!important;
  color:var(--sy-cream)!important;
  font-family:Georgia,"Times New Roman",serif!important;
  font-size:clamp(48px,6.3vw,82px)!important;
  line-height:.94!important;
  letter-spacing:-.055em!important;
  font-weight:500!important;
  text-wrap:balance;
  animation:syHeadlineReveal 1.1s .20s cubic-bezier(.22,.61,.36,1) both;
}
.sy-motion-copy h1 em{
  color:var(--sy-gold)!important;
  font-style:italic!important;
  font-weight:500!important;
}

.sy-motion-copy .hero-description{
  max-width:590px!important;
  margin:0 0 30px!important;
  color:#fff8ea!important;
  font-size:16px!important;
  line-height:1.75!important;
  text-shadow:0 2px 12px rgba(0,0,0,.35);
  animation:syFadeUp .9s .42s both;
}

.sy-motion-copy .hero-ctas{
  justify-content:flex-start!important;
  margin-top:0!important;
  gap:22px!important;
  animation:syFadeUp .9s .58s both;
}

.sy-motion-copy .btn-light{
  background:var(--sy-cream)!important;
  color:var(--sy-ink)!important;
  border-color:var(--sy-cream)!important;
  padding:14px 22px!important;
  box-shadow:0 15px 38px rgba(0,0,0,.25);
  transition:transform .3s ease,box-shadow .3s ease,background .3s ease!important;
}
.sy-motion-copy .btn-light:hover{
  background:var(--sy-gold-soft)!important;
  border-color:var(--sy-gold-soft)!important;
  transform:translateY(-4px) scale(1.025)!important;
  box-shadow:0 22px 48px rgba(232,183,90,.22);
}
.sy-arrow{
  display:inline-block;
  margin-left:10px;
  transition:transform .3s ease;
}
.sy-motion-copy .btn-light:hover .sy-arrow{transform:translateX(5px)}

.sy-motion-copy .hero-story-link{
  color:var(--sy-cream)!important;
  border-color:rgba(255,248,234,.50)!important;
}
.sy-motion-copy .hero-story-link:hover{
  color:var(--sy-gold-soft)!important;
  border-color:var(--sy-gold)!important;
}

.sy-motion-copy .hero-trust{
  justify-content:flex-start!important;
  margin-top:38px!important;
  padding-top:18px;
  border-top:1px solid rgba(255,248,234,.18);
  max-width:680px;
  animation:syFadeUp .9s .76s both;
}
.sy-motion-copy .hero-trust span{
  color:#fff8ea!important;
  font-size:11px!important;
}

/* Floating ingredient labels make the page feel like a moving spice editorial. */
.sy-ingredient{
  position:absolute;
  z-index:5;
  color:rgba(255,248,234,.72);
  font-size:8px;
  letter-spacing:.25em;
  writing-mode:vertical-rl;
  opacity:.7;
  pointer-events:none;
}
.ingredient-turmeric{
  top:21%;
  right:8%;
  color:var(--sy-gold-soft);
  animation:syFloatA 6s ease-in-out infinite;
}
.ingredient-chilli{
  top:45%;
  right:3%;
  color:#e58b74;
  animation:syFloatB 7s 1s ease-in-out infinite;
}
.ingredient-cardamom{
  bottom:23%;
  left:4%;
  animation:syFloatB 8s .5s ease-in-out infinite;
}
.ingredient-cumin{
  bottom:15%;
  right:18%;
  color:var(--sy-gold);
  animation:syFloatA 7s 1.2s ease-in-out infinite;
}

.sy-spice-dust{
  position:absolute;
  inset:0;
  z-index:4;
  pointer-events:none;
  overflow:hidden;
}
.sy-spice-dust i{
  position:absolute;
  left:var(--x);
  bottom:-10px;
  width:var(--s);
  height:var(--s);
  border-radius:50%;
  background:var(--sy-gold);
  box-shadow:0 0 14px rgba(232,183,90,.55);
  opacity:0;
  animation:syDustRise 9s var(--d) ease-in-out infinite;
}
.sy-spice-dust i:nth-child(1){--x:12%;--s:3px;--d:0s}
.sy-spice-dust i:nth-child(2){--x:22%;--s:5px;--d:1.2s}
.sy-spice-dust i:nth-child(3){--x:34%;--s:3px;--d:3s}
.sy-spice-dust i:nth-child(4){--x:47%;--s:4px;--d:.7s}
.sy-spice-dust i:nth-child(5){--x:58%;--s:3px;--d:2.4s}
.sy-spice-dust i:nth-child(6){--x:69%;--s:5px;--d:4s}
.sy-spice-dust i:nth-child(7){--x:77%;--s:3px;--d:1.6s}
.sy-spice-dust i:nth-child(8){--x:86%;--s:4px;--d:5s}
.sy-spice-dust i:nth-child(9){--x:91%;--s:3px;--d:2.1s}
.sy-spice-dust i:nth-child(10){--x:52%;--s:3px;--d:6s}

.sy-hero-badge{
  position:absolute;
  right:8%;
  bottom:15%;
  z-index:8;
  width:205px;
  padding:20px;
  border:1px solid rgba(255,248,234,.22);
  background:rgba(18,9,6,.38);
  backdrop-filter:blur(10px);
  box-shadow:0 24px 55px rgba(0,0,0,.25);
  animation:syBadgeFloat 6s ease-in-out infinite;
}
.sy-hero-badge span{
  color:var(--sy-gold);
  font:600 10px/1 var(--sans,Arial,sans-serif);
  letter-spacing:.18em;
}
.sy-hero-badge strong{
  display:block;
  margin-top:12px;
  color:var(--sy-cream);
  font:500 21px/1.05 Georgia,"Times New Roman",serif;
}
.sy-hero-badge small{
  display:block;
  margin-top:14px;
  color:#d8c8b7;
  font-size:9px;
  line-height:1.5;
}

.sy-scroll{
  position:absolute;
  right:36px;
  bottom:26px;
  z-index:9;
  display:flex;
  flex-direction:column;
  align-items:center;
  gap:6px;
}
.sy-scroll span{
  color:#fff8ea;
  font-size:7px;
  letter-spacing:.25em;
  opacity:.65;
}
.sy-scroll i{
  width:1px;
  height:48px;
  background:linear-gradient(var(--sy-gold),transparent);
  position:relative;
  overflow:hidden;
}
.sy-scroll i:after{
  content:"";
  position:absolute;
  top:-14px;
  left:0;
  width:1px;
  height:14px;
  background:var(--sy-cream);
  animation:syScrollLine 1.7s ease-in-out infinite;
}

/* Animated spice strip between hero and products. */
.sy-spice-transition{
  position:relative;
  overflow:hidden;
  background:var(--sy-brown-deep);
  color:var(--sy-gold-soft);
  border-top:1px solid rgba(232,183,90,.16);
  border-bottom:1px solid rgba(232,183,90,.16);
  padding:17px 0;
}
.sy-transition-line{
  position:absolute;
  left:0;
  top:0;
  width:28%;
  height:1px;
  background:linear-gradient(90deg,transparent,var(--sy-gold),transparent);
  animation:syLineTravel 5s linear infinite;
}
.sy-marquee{
  display:flex;
  width:max-content;
  align-items:center;
  gap:18px;
  white-space:nowrap;
  animation:syMarquee 28s linear infinite;
}
.sy-marquee span{
  font-size:9px;
  font-weight:800;
  letter-spacing:.22em;
}
.sy-marquee b{
  color:var(--sy-red);
  font-size:14px;
}

/* Product section receives a warm visual landing instead of an abrupt cut. */
#shop{
  position:relative;
  scroll-margin-top:80px;
}
#shop:before{
  content:"";
  display:block;
  position:absolute;
  left:0;
  right:0;
  top:0;
  height:150px;
  transform:translateY(-100%);
  background:linear-gradient(180deg,transparent,var(--sy-brown-deep));
  pointer-events:none;
}

/* Motion */
@keyframes syCameraMove{
  from{transform:scale(1.04) translate3d(-.4%,0,0)}
  to{transform:scale(1.10) translate3d(.4%,-.5%,0)}
}
@keyframes syHeroReveal{
  from{opacity:0;transform:translate3d(-25px,25px,0);filter:blur(4px)}
  to{opacity:1;transform:none;filter:blur(0)}
}
@keyframes syRevealLeft{
  from{opacity:0;transform:translateX(-22px)}
  to{opacity:1;transform:none}
}
@keyframes syHeadlineReveal{
  from{opacity:0;transform:translate3d(0,45px,0);filter:blur(5px)}
  to{opacity:1;transform:none;filter:blur(0)}
}
@keyframes syFadeUp{
  from{opacity:0;transform:translateY(20px)}
  to{opacity:1;transform:none}
}
@keyframes syDustRise{
  0%{opacity:0;transform:translate3d(0,30px,0) scale(.45)}
  15%{opacity:.55}
  55%{opacity:.85;transform:translate3d(16px,-130px,0) scale(1)}
  82%{opacity:.20}
  100%{opacity:0;transform:translate3d(-18px,-230px,0) scale(.3)}
}
@keyframes syFloatA{
  0%,100%{transform:translateY(0) rotate(0deg)}
  50%{transform:translateY(-15px) rotate(2deg)}
}
@keyframes syFloatB{
  0%,100%{transform:translateY(0) rotate(0deg)}
  50%{transform:translateY(12px) rotate(-2deg)}
}
@keyframes syBadgeFloat{
  0%,100%{transform:translateY(0)}
  50%{transform:translateY(-8px)}
}
@keyframes syScrollLine{
  0%{transform:translateY(0);opacity:0}
  25%{opacity:1}
  100%{transform:translateY(60px);opacity:0}
}
@keyframes syLineTravel{
  0%{transform:translateX(-120%)}
  100%{transform:translateX(430%)}
}
@keyframes syMarquee{
  from{transform:translateX(0)}
  to{transform:translateX(-50%)}
}
@keyframes syGrain{
  0%{transform:translate(0,0)}
  25%{transform:translate(-2%,1%)}
  50%{transform:translate(1%,-2%)}
  75%{transform:translate(2%,2%)}
  100%{transform:translate(-1%,-1%)}
}

@media(max-width:900px){
  .sy-spice-motion{padding-left:6%!important;padding-right:6%!important}
  .sy-hero-badge{right:5%;bottom:11%;width:175px;padding:16px}
  .sy-hero-badge strong{font-size:18px}
}

@media(max-width:650px){
  .sy-spice-motion{
    min-height:calc(100svh - 104px)!important;
    justify-content:center!important;
    text-align:center!important;
    padding:62px 20px 80px!important;
  }
  .sy-hero-image{background-position:58% center}
  .sy-motion-copy{
    max-width:100%!important;
    text-align:center!important;
  }
  .sy-brand-kicker{justify-content:center;font-size:8px;letter-spacing:.22em}
  .sy-brand-kicker span{width:20px}
  .sy-motion-eyebrow{font-size:9px!important}
  .sy-motion-copy h1{
    font-size:clamp(39px,11vw,52px)!important;
    line-height:.98!important;
  }
  .sy-motion-copy .hero-description{
    font-size:14px!important;
    line-height:1.65!important;
    margin-left:auto!important;
    margin-right:auto!important;
  }
  .sy-motion-copy .hero-ctas{
    justify-content:center!important;
    flex-wrap:wrap;
  }
  .sy-motion-copy .hero-trust{
    justify-content:center!important;
    flex-wrap:wrap;
    gap:8px 14px!important;
  }
  .sy-hero-badge,.sy-ingredient{display:none}
  .sy-scroll{right:13px;bottom:13px;transform:scale(.78)}
  .sy-spice-dust i:nth-child(2n){display:none}
  .sy-marquee{animation-duration:22s}
}

@media(prefers-reduced-motion:reduce){
  .sy-hero-image,.sy-spice-grain,.sy-spice-dust i,
  .sy-motion-copy,.sy-brand-kicker,.sy-motion-eyebrow,
  .sy-motion-copy h1,.sy-motion-copy .hero-description,
  .sy-motion-copy .hero-ctas,.sy-motion-copy .hero-trust,
  .sy-hero-badge,.sy-scroll i:after,.sy-ingredient,
  .sy-transition-line,.sy-marquee{
    animation:none!important;
    transition:none!important;
  }
}
"@

if ($css -notmatch 'SPICES OF YASH — SPICE MOTION LANDING') {
  $css += $cssPatch
}

# Write UTF-8 without BOM.
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($indexPath,$html,$utf8)
[System.IO.File]::WriteAllText($cssPath,$css,$utf8)

# Validate after write.
$checkHtml = Get-Content -LiteralPath $indexPath -Raw
$checkCss = Get-Content -LiteralPath $cssPath -Raw
if ($checkHtml -notmatch '(?i)<meta\s+charset="UTF-8"') { throw "UTF-8 charset validation failed." }
foreach ($marker in @('id="product-grid"','id="cart-open"','id="checkout-form"')) {
  if (!$checkHtml.Contains($marker)) { throw "Storefront marker lost: $marker" }
}
if ($checkHtml -notmatch 'sy-spice-motion') { throw "Hero validation failed." }
if ($checkCss -notmatch 'SPICES OF YASH — SPICE MOTION LANDING') { throw "CSS validation failed." }

Write-Host ""
Write-Host "SPICES OF YASH SPICE MOTION LANDING APPLIED." -ForegroundColor Green
Write-Host "Frontend only: public\index.html and public\styles.css changed." -ForegroundColor Green
Write-Host "Hero uses local spice image: $heroImageUrl" -ForegroundColor Cyan
Write-Host "Added animated spice dust, ingredient motion, editorial badge, moving spice strip and cinematic camera motion." -ForegroundColor Green
Write-Host "Backend, database, .env, payments and server.js were NOT changed." -ForegroundColor Green
Write-Host "Backup: $backup" -ForegroundColor Cyan
Write-Host ""
Write-Host "Now run: npm start" -ForegroundColor Yellow
Write-Host "Open: http://localhost:3000" -ForegroundColor Yellow
