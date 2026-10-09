param(
  [string]$ProjectPath = "D:\Project\Spices-of-Yash-Complete-Local-Project (1)\spices-of-yash-store"
)

$ErrorActionPreference = "Stop"

$indexPath = Join-Path $ProjectPath "public\index.html"
$cssPath   = Join-Path $ProjectPath "public\styles.css"
$imagesDir = Join-Path $ProjectPath "public\images"

if (!(Test-Path -LiteralPath $indexPath)) { throw "public\index.html not found. Nothing changed." }
if (!(Test-Path -LiteralPath $cssPath)) { throw "public\styles.css not found. Nothing changed." }

$html = Get-Content -LiteralPath $indexPath -Raw
$css  = Get-Content -LiteralPath $cssPath -Raw

foreach ($marker in @('id="product-grid"','id="cart-open"','id="checkout-form"')) {
  if (!$html.Contains($marker)) { throw "Required storefront marker missing: $marker. Nothing changed." }
}

# Select existing local images only.
function Find-ImageUrl([string[]]$names) {
  foreach ($name in $names) {
    $p = Join-Path $imagesDir $name
    if (Test-Path -LiteralPath $p) { return "/images/$name" }
  }
  return "/images/story-spices.webp"
}

$heroImage = Find-ImageUrl @(
  "story-spices.webp","hero-spices.webp",
  "green-cardamom.jpg","green-cardamom.webp",
  "kashmiri-red-chilli.jpg","kashmiri-red-chilli.webp"
)

$cardamom = Find-ImageUrl @("green-cardamom.jpg","green-cardamom.webp","cardamom.jpg","cardamom.webp","story-spices.webp")
$chilli   = Find-ImageUrl @("kashmiri-red-chilli.jpg","kashmiri-red-chilli.webp","red-chilli.jpg","red-chilli.webp","hero-spices.webp")
$turmeric = Find-ImageUrl @("turmeric.jpg","turmeric.webp","haldi.jpg","haldi.webp","story-spices.webp")
$cumin    = Find-ImageUrl @("cumin.jpg","cumin.webp","jeera.jpg","jeera.webp","hero-spices.webp")
$pepper   = Find-ImageUrl @("black-pepper.jpg","black-pepper.webp","pepper.jpg","pepper.webp","story-spices.webp")
$garam    = Find-ImageUrl @("garam-masala.jpg","garam-masala.webp","garammasala.jpg","garammasala.webp","hero-spices.webp")

# BACKUP FIRST
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = Join-Path $ProjectPath ("cinematic-spice-backup-" + $stamp)
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $indexPath -Destination (Join-Path $backup "index.html") -Force
Copy-Item -LiteralPath $cssPath -Destination (Join-Path $backup "styles.css") -Force

# UTF-8/mojibake cleanup. The script itself stays ASCII-safe.
$badGood = @(
  @(([string][char](0xE2)+[char](0x86)+[char](0x92)),"&#8594;"),
  @(([string][char](0xE2)+[char](0x86)+[char](0x93)),"&#8595;"),
  @(([string][char](0xE2)+[char](0x86)+[char](0x91)),"&#8593;"),
  @(([string][char](0xE2)+[char](0x80)+[char](0xA2)),"&#183;"),
  @(([string][char](0xC2)+[char](0xB7)),"&#183;"),
  @(([string][char](0xE2)+[char](0x80)+[char](0x94)),"-"),
  @(([string][char](0xE2)+[char](0x80)+[char](0x93)),"-"),
  @(([string][char](0xE2)+[char](0x80)+[char](0x99)),"&#39;"),
  @(([string][char](0xE2)+[char](0x80)+[char](0x9C)),"&quot;"),
  @(([string][char](0xE2)+[char](0x80)+[char](0x9D)),"&quot;"),
  @(([string][char](0xC3)+[char](0xA2)+[char](0xE2)+[char](0x80)+[char](0x99)),"&#39;"),
  @(([string][char](0xC3)+[char](0xA2)+[char](0xE2)+[char](0x80)+[char](0x9C)),"&quot;"),
  @(([string][char](0xC3)+[char](0xA2)+[char](0xE2)+[char](0x80)+[char](0x9D)),"&quot;"),
  @(([string][char](0xC3)+[char](0xA2)+[char](0xE2)+[char](0x80)+[char](0x93)),"-"),
  @(([string][char](0xC3)+[char](0xA2)+[char](0xE2)+[char](0x80)+[char](0x94)),"-")
)
foreach ($pair in $badGood) {
  $html = $html.Replace($pair[0],$pair[1])
  $css  = $css.Replace($pair[0],$pair[1])
}

# Ensure UTF-8 meta.
if ($html -notmatch '(?is)<meta\s+charset\s*=') {
  $html = [regex]::Replace($html,'(?is)(<head\b[^>]*>)','$1' + "`r`n" + '<meta charset="UTF-8">',1)
} else {
  $html = [regex]::Replace($html,'(?is)<meta\s+charset\s*=\s*["''][^"'']*["'']\s*/?>','<meta charset="UTF-8">',1)
}

# Replace exactly one existing hero. The current storefront hero is preserved as a visual slot.
$heroPattern = '(?s)<section\s+class="hero[^"]*"[^>]*>.*?</section>'
$heroMatches = [regex]::Matches($html,$heroPattern)
if ($heroMatches.Count -ne 1) { throw "Expected exactly one hero section. Found $($heroMatches.Count). Nothing changed." }

$newHero = @"
<section class="hero sy-cinematic-hero" id="home" aria-label="Spices of Yash">
  <div class="sy-hero-media" aria-hidden="true" style="--sy-hero-image:url('$heroImage')"></div>
  <div class="sy-hero-overlay" aria-hidden="true"></div>
  <div class="sy-hero-grain" aria-hidden="true"></div>
  <div class="sy-spice-dust" aria-hidden="true">
    <i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i>
  </div>

  <div class="sy-hero-copy">
    <div class="sy-kicker"><span></span> THE SPICE PANTRY <span></span></div>
    <p class="sy-eyebrow">AUTHENTIC INDIAN FLAVOUR</p>
    <h1>Bring Every Meal<br><em>To Life With Flavour</em></h1>
    <p class="sy-hero-description">Discover carefully packed Indian spices for everyday kitchens, family recipes, restaurants and bulk buyers.</p>

    <div class="hero-ctas sy-hero-actions">
      <a class="btn btn-light sy-primary-cta" href="#shop">Explore Our Spices <span>&#8594;</span></a>
      <a class="text-link sy-story-cta" href="#story">Discover Our Story <span>&#8594;</span></a>
    </div>

    <div class="sy-trust-row">
      <span>Authentic Indian Spices</span>
      <span>Quality Packed</span>
      <span>Delivered Across India</span>
    </div>
  </div>

  <div class="sy-hero-editorial" aria-hidden="true">
    <span>01</span>
    <strong>GROUND<br>WITH CARE</strong>
    <small>Whole spices &#183; Ground spices &#183; Signature blends</small>
  </div>

  <div class="sy-scroll-indicator" aria-hidden="true">
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

# Editorial flavour discovery section.
$flavourSection = @"
<section class="sy-flavour-section" id="collections">
  <div class="sy-section-head sy-reveal">
    <div>
      <span class="sy-section-label">THE FLAVOURS OF INDIA</span>
      <h2>A pantry of aromas,<br><em>warmth and character.</em></h2>
    </div>
    <p>From fragrant cardamom to deep chilli warmth, discover the ingredients that define everyday Indian cooking.</p>
  </div>

  <div class="sy-flavour-grid">
    <a class="sy-flavour-card sy-reveal" href="#shop" style="--card-image:url('$cardamom')">
      <span class="sy-card-index">01</span><div class="sy-card-shade"></div>
      <div class="sy-card-content"><small>AROMATIC</small><h3>Green Cardamom</h3><p>Cool, floral and naturally fragrant.</p><span>Explore &#8594;</span></div>
    </a>
    <a class="sy-flavour-card sy-reveal" href="#shop" style="--card-image:url('$chilli')">
      <span class="sy-card-index">02</span><div class="sy-card-shade"></div>
      <div class="sy-card-content"><small>BOLD HEAT</small><h3>Kashmiri Red Chilli</h3><p>Deep colour with a gentle warmth.</p><span>Explore &#8594;</span></div>
    </a>
    <a class="sy-flavour-card sy-reveal" href="#shop" style="--card-image:url('$turmeric')">
      <span class="sy-card-index">03</span><div class="sy-card-shade"></div>
      <div class="sy-card-content"><small>EARTHY</small><h3>Turmeric</h3><p>Warm, golden and unmistakably Indian.</p><span>Explore &#8594;</span></div>
    </a>
    <a class="sy-flavour-card sy-reveal" href="#shop" style="--card-image:url('$cumin')">
      <span class="sy-card-index">04</span><div class="sy-card-shade"></div>
      <div class="sy-card-content"><small>TOASTED</small><h3>Cumin</h3><p>Nutty aroma for everyday tadka.</p><span>Explore &#8594;</span></div>
    </a>
    <a class="sy-flavour-card sy-reveal" href="#shop" style="--card-image:url('$pepper')">
      <span class="sy-card-index">05</span><div class="sy-card-shade"></div>
      <div class="sy-card-content"><small>PIQUANT</small><h3>Black Pepper</h3><p>Sharp, warm and intensely aromatic.</p><span>Explore &#8594;</span></div>
    </a>
    <a class="sy-flavour-card sy-reveal" href="#shop" style="--card-image:url('$garam')">
      <span class="sy-card-index">06</span><div class="sy-card-shade"></div>
      <div class="sy-card-content"><small>SIGNATURE</small><h3>Garam Masala</h3><p>A layered blend for unforgettable dishes.</p><span>Explore &#8594;</span></div>
    </a>
  </div>
</section>
"@

if ($html -notmatch 'class="sy-flavour-section"') {
  $html = [regex]::Replace(
    $html,
    '(?is)(<section\s+class="sy-cinematic-hero"[^>]*>.*?</section>)',
    [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $m.Groups[1].Value + "`r`n" + $flavourSection },
    1
  )
}

# Add an editorial marquee before the shop area.
$marquee = @'
<div class="sy-spice-marquee" aria-hidden="true">
  <div><span>WHOLE SPICES</span><b>&#183;</b><span>GROUND SPICES</span><b>&#183;</b><span>SIGNATURE BLENDS</span><b>&#183;</b><span>AUTHENTIC INDIAN FLAVOUR</span><b>&#183;</b><span>WHOLE SPICES</span><b>&#183;</b><span>GROUND SPICES</span><b>&#183;</b><span>SIGNATURE BLENDS</span><b>&#183;</b></div>
</div>
'@

if ($html -notmatch 'class="sy-spice-marquee"') {
  $html = [regex]::Replace(
    $html,
    '(?is)(<section[^>]*id="shop"[^>]*>)',
    [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $marquee + "`r`n" + $m.Groups[1].Value },
    1
  )
}

# Add a clean heading around the existing product grid only when no shop heading exists.
if ($html -notmatch '(?is)SHOP THE PANTRY') {
  $shopIntro = @'
<div class="sy-shop-intro sy-reveal">
  <span class="sy-section-label">SHOP THE PANTRY</span>
  <h2>Essential spices for<br><em>everyday Indian cooking.</em></h2>
</div>
'@
  $html = [regex]::Replace(
    $html,
    '(?is)(<[^>]*id="product-grid"[^>]*>)',
    [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $shopIntro + "`r`n" + $m.Groups[1].Value },
    1
  )
}

# Story section only if the project does not already have one.
$storySection = @"
<section class="sy-story-section" id="story">
  <div class="sy-story-image sy-reveal" style="--story-image:url('$heroImage')"></div>
  <div class="sy-story-copy sy-reveal">
    <span class="sy-section-label">FROM THE HEART OF INDIA</span>
    <h2>Spices aren't just ingredients.<br><em>They are memories, rituals and stories.</em></h2>
    <p>We bring carefully packed Indian spices into everyday kitchens, keeping the warmth, aroma and character of the pantry at the centre of every meal.</p>
    <a class="sy-editorial-link" href="#shop">Discover Our Story <span>&#8594;</span></a>
  </div>
</section>
"@
if ($html -notmatch '(?is)id="story"') {
  $html = [regex]::Replace(
    $html,
    '(?is)(<section[^>]*id="shop"[^>]*>)',
    [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $storySection + "`r`n" + $m.Groups[1].Value },
    1
  )
}

# Recipe section.
$recipeSection = @'
<section class="sy-recipe-section">
  <div class="sy-section-head sy-reveal">
    <div><span class="sy-section-label">COOK WITH SPICES</span><h2>What will you<br><em>cook today?</em></h2></div>
    <p>Every dish has a starting point. Discover a few familiar Indian favourites and the spices that bring them alive.</p>
  </div>
  <div class="sy-recipe-track">
    <article class="sy-recipe-card sy-reveal"><span>01</span><h3>Dal Tadka</h3><p>Cumin &#183; Turmeric &#183; Chilli</p></article>
    <article class="sy-recipe-card sy-reveal"><span>02</span><h3>Biryani</h3><p>Cardamom &#183; Cumin &#183; Garam Masala</p></article>
    <article class="sy-recipe-card sy-reveal"><span>03</span><h3>Butter Chicken</h3><p>Chilli &#183; Garam Masala &#183; Cumin</p></article>
    <article class="sy-recipe-card sy-reveal"><span>04</span><h3>Masala Chai</h3><p>Cardamom &#183; Cinnamon &#183; Pepper</p></article>
    <article class="sy-recipe-card sy-reveal"><span>05</span><h3>Paneer Tikka</h3><p>Chilli &#183; Turmeric &#183; Garam Masala</p></article>
  </div>
</section>
'@
if ($html -notmatch 'class="sy-recipe-section"') {
  $insertPoint = '(?is)(<footer\b)'
  if ($html -match $insertPoint) {
    $html = [regex]::Replace($html,$insertPoint,[System.Text.RegularExpressions.MatchEvaluator]{ param($m) $recipeSection + "`r`n" + $m.Groups[1].Value },1)
  } else {
    $html += $recipeSection
  }
}

$trustSection = @'
<section class="sy-trust-section">
  <div class="sy-section-head sy-reveal"><div><span class="sy-section-label">WHY SPICES OF YASH</span><h2>Good flavour begins<br><em>with good ingredients.</em></h2></div></div>
  <div class="sy-trust-grid">
    <div class="sy-trust-item sy-reveal"><strong>01</strong><h3>AUTHENTIC FLAVOUR</h3><p>Spices chosen for aroma, warmth and everyday cooking.</p></div>
    <div class="sy-trust-item sy-reveal"><strong>02</strong><h3>CAREFULLY PACKED</h3><p>Thoughtful packaging that keeps your pantry fresh.</p></div>
    <div class="sy-trust-item sy-reveal"><strong>03</strong><h3>QUALITY YOU CAN TASTE</h3><p>Made to bring depth and character to familiar recipes.</p></div>
    <div class="sy-trust-item sy-reveal"><strong>04</strong><h3>DELIVERED ACROSS INDIA</h3><p>From our pantry to kitchens across the country.</p></div>
  </div>
</section>
'@
if ($html -notmatch 'class="sy-trust-section"') {
  $html = [regex]::Replace($html,'(?is)(<section class="sy-recipe-section".*?</section>)',[System.Text.RegularExpressions.MatchEvaluator]{param($m)$m.Groups[1].Value+"`r`n"+$trustSection},1)
}

$wholesaleSection = @'
<section class="sy-wholesale-section">
  <div class="sy-wholesale-inner sy-reveal">
    <span class="sy-section-label">FOR EVERY KIND OF KITCHEN</span>
    <h2>FOR HOMES.<br>FOR RESTAURANTS.<br><em>FOR BUSINESS.</em></h2>
    <div class="sy-wholesale-paths">
      <a href="#shop"><span>01</span><strong>EVERYDAY KITCHENS</strong><small>Reliable pantry essentials for family cooking.</small><b>&#8594;</b></a>
      <a href="#shop"><span>02</span><strong>RESTAURANTS &amp; BULK BUYERS</strong><small>Spices for larger kitchens and regular supply.</small><b>&#8594;</b></a>
    </div>
  </div>
</section>
'@
if ($html -notmatch 'class="sy-wholesale-section"') {
  $html = [regex]::Replace($html,'(?is)(<footer\b)',[System.Text.RegularExpressions.MatchEvaluator]{param($m)$wholesaleSection+"`r`n"+$m.Groups[1].Value},1)
}

$finalCta = @'
<section class="sy-final-cta sy-reveal">
  <div><span class="sy-section-label">THE SPICE PANTRY</span><h2>BRING MORE<br><em>FLAVOUR HOME.</em></h2><p>Discover the spices that turn everyday cooking into something worth remembering.</p><a class="btn btn-light sy-primary-cta" href="#shop">Explore Our Spices <span>&#8594;</span></a></div>
</section>
'@
if ($html -notmatch 'class="sy-final-cta"') {
  $html = [regex]::Replace($html,'(?is)(<footer\b)',[System.Text.RegularExpressions.MatchEvaluator]{param($m)$finalCta+"`r`n"+$m.Groups[1].Value},1)
}

$cssPatch = @"

/* =========================================================
   SPICES OF YASH - CINEMATIC INDIAN SPICE HOUSE
   Frontend only. Existing commerce behavior remains untouched.
   ========================================================= */

:root{
  --sy-deep:#160d08;
  --sy-brown:#24140c;
  --sy-gold:#e8b75a;
  --sy-turmeric:#f2d18a;
  --sy-red:#b3361f;
  --sy-cream:#fff8ea;
  --sy-muted:#8f7965;
}

html{scroll-behavior:smooth;scrollbar-width:none}
html::-webkit-scrollbar{width:0;height:0}
body{overflow-x:hidden;background:var(--sy-cream);color:var(--sy-deep)}
img{max-width:100%}
:focus-visible{outline:2px solid var(--sy-gold);outline-offset:3px}

.site-header{
  background:rgba(22,13,8,.90)!important;
  color:var(--sy-cream)!important;
  border-bottom:1px solid rgba(255,248,234,.12)!important;
  box-shadow:0 8px 30px rgba(0,0,0,.14)!important;
  backdrop-filter:blur(14px);
  -webkit-backdrop-filter:blur(14px);
}
.site-header a{color:inherit}
.site-header .main-nav a{font-size:14px!important;font-weight:400!important;color:rgba(255,248,234,.90)!important}
.site-header .main-nav a:hover{color:var(--sy-gold)!important}
.site-header .brand{color:var(--sy-cream)!important}
.site-header .brand small{color:var(--sy-turmeric)!important}
.site-header .cart-btn{color:var(--sy-cream)!important;border-color:rgba(255,248,234,.35)!important}
.site-header .cart-btn:hover{background:var(--sy-cream)!important;color:var(--sy-deep)!important}

.sy-cinematic-hero{
  position:relative!important;
  isolation:isolate;
  min-height:100svh!important;
  display:flex!important;
  align-items:center!important;
  justify-content:flex-start!important;
  overflow:hidden!important;
  padding:100px clamp(22px,7vw,110px) 80px!important;
  background:var(--sy-deep)!important;
  color:var(--sy-cream)!important;
  text-align:left!important;
}
.sy-hero-media{
  position:absolute;
  inset:-5%;
  z-index:-5;
  background-image:var(--sy-hero-image);
  background-size:cover;
  background-position:center;
  filter:saturate(1.08) contrast(1.06);
  transform:scale(1.04);
  animation:syKenBurns 20s ease-in-out infinite alternate;
}
.sy-hero-overlay{
  position:absolute;
  inset:0;
  z-index:-4;
  background:
    radial-gradient(circle at 72% 42%,rgba(179,54,31,.20),transparent 30%),
    linear-gradient(90deg,rgba(22,13,8,.94) 0%,rgba(22,13,8,.72) 43%,rgba(22,13,8,.34) 76%,rgba(22,13,8,.62) 100%),
    linear-gradient(180deg,rgba(22,13,8,.24),rgba(22,13,8,.76));
}
.sy-hero-overlay:after{
  content:"";
  position:absolute;
  inset:0;
  background:radial-gradient(circle at 50% 48%,transparent 0 27%,rgba(0,0,0,.16) 58%,rgba(0,0,0,.52) 100%);
}
.sy-hero-grain{
  position:absolute;
  inset:0;
  z-index:3;
  pointer-events:none;
  opacity:.075;
  background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='160' height='160'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.8' numOctaves='3' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='.55'/%3E%3C/svg%3E");
  animation:syGrain .4s steps(2) infinite;
}
.sy-hero-copy{
  position:relative;
  z-index:8;
  width:min(780px,100%);
  animation:syHeroIn 1s .15s cubic-bezier(.22,.61,.36,1) both;
}
.sy-kicker{
  display:flex;
  align-items:center;
  gap:11px;
  margin-bottom:16px;
  color:var(--sy-turmeric);
  font-size:9px;
  font-weight:800;
  letter-spacing:.28em;
  animation:syRevealLeft .8s .15s both;
}
.sy-kicker span{width:26px;height:1px;background:var(--sy-gold);display:block}
.sy-eyebrow{
  margin:0 0 20px!important;
  color:var(--sy-cream)!important;
  font-size:11px!important;
  letter-spacing:.25em!important;
  font-weight:700!important;
  animation:syRevealLeft .8s .28s both;
}
.sy-hero-copy h1{
  margin:0 0 23px!important;
  max-width:850px;
  color:var(--sy-cream)!important;
  font-family:Georgia,"Times New Roman",serif!important;
  font-size:clamp(48px,6.5vw,86px)!important;
  line-height:.93!important;
  letter-spacing:-.055em!important;
  font-weight:500!important;
  animation:syHeadlineIn 1s .38s cubic-bezier(.22,.61,.36,1) both;
}
.sy-hero-copy h1 em{
  color:var(--sy-gold)!important;
  font-style:italic!important;
  font-weight:500!important;
}
.sy-hero-description{
  max-width:590px!important;
  margin:0 0 30px!important;
  color:rgba(255,248,234,.90)!important;
  font-size:16px!important;
  line-height:1.72!important;
  animation:syFadeUp .85s .62s both;
}
.sy-hero-actions{justify-content:flex-start!important;gap:22px!important;animation:syFadeUp .85s .78s both}
.sy-primary-cta{
  background:var(--sy-cream)!important;
  color:var(--sy-deep)!important;
  border-color:var(--sy-cream)!important;
  padding:13px 25px!important;
  box-shadow:0 18px 42px rgba(0,0,0,.25);
  transition:transform .28s ease,box-shadow .28s ease,background .28s ease!important;
}
.sy-primary-cta:hover{
  background:var(--sy-turmeric)!important;
  border-color:var(--sy-turmeric)!important;
  transform:translateY(-4px) scale(1.025)!important;
  box-shadow:0 24px 52px rgba(232,183,90,.20);
}
.sy-primary-cta span{display:inline-block;margin-left:10px;transition:transform .28s ease}
.sy-primary-cta:hover span{transform:translateX(5px)}
.sy-story-cta{color:var(--sy-cream)!important;border-color:rgba(255,248,234,.45)!important}
.sy-story-cta:hover{color:var(--sy-gold)!important;border-color:var(--sy-gold)!important}
.sy-trust-row{
  display:flex;
  flex-wrap:wrap;
  gap:0;
  max-width:690px;
  margin-top:38px;
  padding-top:17px;
  border-top:1px solid rgba(255,248,234,.18);
  animation:syFadeUp .85s .96s both;
}
.sy-trust-row span{
  color:rgba(255,248,234,.88);
  font-size:11px;
  line-height:1.5;
  padding:0 16px;
  border-right:1px solid rgba(255,248,234,.18);
}
.sy-trust-row span:first-child{padding-left:0}
.sy-trust-row span:last-child{border-right:0}

.sy-hero-editorial{
  position:absolute;
  right:7%;
  bottom:16%;
  z-index:8;
  width:215px;
  padding:21px;
  border:1px solid rgba(255,248,234,.23);
  background:rgba(22,13,8,.36);
  backdrop-filter:blur(10px);
  box-shadow:0 25px 60px rgba(0,0,0,.24);
  animation:syBadgeIn 1s 1s both,syBadgeFloat 6s 2s ease-in-out infinite;
}
.sy-hero-editorial span{color:var(--sy-gold);font-size:10px;font-weight:700;letter-spacing:.18em}
.sy-hero-editorial strong{display:block;margin-top:12px;color:var(--sy-cream);font:500 22px/1.04 Georgia,"Times New Roman",serif}
.sy-hero-editorial small{display:block;margin-top:14px;color:#dccdbc;font-size:9px;line-height:1.5}

.sy-scroll-indicator{
  position:absolute;
  right:30px;
  bottom:24px;
  z-index:9;
  display:flex;
  flex-direction:column;
  align-items:center;
  gap:6px;
}
.sy-scroll-indicator span{font-size:7px;letter-spacing:.25em;color:rgba(255,248,234,.68)}
.sy-scroll-indicator i{width:1px;height:48px;background:linear-gradient(var(--sy-gold),transparent);overflow:hidden;position:relative}
.sy-scroll-indicator i:after{content:"";position:absolute;top:-14px;left:0;width:1px;height:14px;background:var(--sy-cream);animation:syScroll 1.7s ease-in-out infinite}

.sy-spice-dust{position:absolute;inset:0;z-index:4;pointer-events:none;overflow:hidden}
.sy-spice-dust i{
  position:absolute;
  left:var(--x);
  bottom:-12px;
  width:var(--s);
  height:var(--s);
  border-radius:50%;
  background:var(--sy-gold);
  box-shadow:0 0 14px rgba(232,183,90,.55);
  opacity:0;
  animation:syDust 9s var(--d) ease-in-out infinite;
}
.sy-spice-dust i:nth-child(1){--x:8%;--s:3px;--d:0s}.sy-spice-dust i:nth-child(2){--x:18%;--s:4px;--d:1s}.sy-spice-dust i:nth-child(3){--x:29%;--s:3px;--d:2.2s}.sy-spice-dust i:nth-child(4){--x:41%;--s:5px;--d:.7s}.sy-spice-dust i:nth-child(5){--x:53%;--s:3px;--d:3.3s}.sy-spice-dust i:nth-child(6){--x:64%;--s:4px;--d:1.8s}.sy-spice-dust i:nth-child(7){--x:75%;--s:3px;--d:4s}.sy-spice-dust i:nth-child(8){--x:84%;--s:5px;--d:2.7s}.sy-spice-dust i:nth-child(9){--x:91%;--s:3px;--d:5s}.sy-spice-dust i:nth-child(10){--x:48%;--s:3px;--d:6s}

.sy-spice-marquee{
  overflow:hidden;
  background:var(--sy-deep);
  color:var(--sy-turmeric);
  border-top:1px solid rgba(232,183,90,.16);
  border-bottom:1px solid rgba(232,183,90,.16);
  padding:16px 0;
}
.sy-spice-marquee>div{
  display:flex;
  width:max-content;
  gap:18px;
  align-items:center;
  white-space:nowrap;
  animation:syMarquee 30s linear infinite;
}
.sy-spice-marquee span{font-size:9px;font-weight:800;letter-spacing:.23em}
.sy-spice-marquee b{color:var(--sy-red);font-size:14px}

.sy-flavour-section,.sy-story-section,.sy-recipe-section,.sy-trust-section{
  padding:110px clamp(22px,7vw,110px);
  background:var(--sy-cream);
}
.sy-section-head{
  display:flex;
  align-items:flex-end;
  justify-content:space-between;
  gap:50px;
  margin:0 auto 45px;
  max-width:1250px;
}
.sy-section-label{
  display:block;
  margin-bottom:14px;
  color:#9b633c;
  font-size:9px;
  font-weight:800;
  letter-spacing:.24em;
}
.sy-section-head h2,.sy-story-copy h2,.sy-wholesale-inner h2,.sy-final-cta h2{
  margin:0;
  color:var(--sy-deep);
  font-family:Georgia,"Times New Roman",serif;
  font-size:clamp(39px,5vw,70px);
  line-height:.96;
  letter-spacing:-.045em;
  font-weight:500;
}
.sy-section-head h2 em,.sy-story-copy h2 em,.sy-wholesale-inner h2 em,.sy-final-cta h2 em{color:#a74a2e;font-style:italic}
.sy-section-head>p{
  max-width:390px;
  margin:0;
  color:#6f5d4f;
  font-size:14px;
  line-height:1.75;
}

.sy-flavour-grid{
  max-width:1250px;
  margin:auto;
  display:grid;
  grid-template-columns:repeat(3,1fr);
  gap:14px;
}
.sy-flavour-card{
  position:relative;
  min-height:390px;
  overflow:hidden;
  display:flex;
  align-items:flex-end;
  color:var(--sy-cream);
  background-image:var(--card-image);
  background-size:cover;
  background-position:center;
  text-decoration:none!important;
  transition:transform .5s ease,box-shadow .5s ease;
}
.sy-flavour-card:before{
  content:"";
  position:absolute;
  inset:0;
  background:linear-gradient(180deg,rgba(0,0,0,.04),rgba(22,13,8,.82));
  transition:background .5s ease;
}
.sy-flavour-card:hover{transform:translateY(-7px);box-shadow:0 25px 55px rgba(22,13,8,.18)}
.sy-flavour-card:hover:before{background:linear-gradient(180deg,rgba(0,0,0,.02),rgba(22,13,8,.92))}
.sy-card-index{position:absolute;top:18px;left:18px;color:var(--sy-turmeric);font-size:9px;letter-spacing:.15em;z-index:2}
.sy-card-content{position:relative;z-index:2;padding:25px;width:100%}
.sy-card-content small{font-size:8px;letter-spacing:.20em;color:var(--sy-turmeric)}
.sy-card-content h3{margin:8px 0 7px;font:500 29px/1.05 Georgia,"Times New Roman",serif;color:var(--sy-cream)}
.sy-card-content p{margin:0 0 15px;color:rgba(255,248,234,.80);font-size:11px}
.sy-card-content>span{font-size:10px;font-weight:700;letter-spacing:.10em;color:var(--sy-cream)}

#shop{scroll-margin-top:90px;background:var(--sy-cream)!important}
#product-grid{position:relative}
.sy-shop-intro{max-width:1250px;margin:0 auto 34px;padding:70px clamp(0px,1vw,12px) 0}
.sy-shop-intro h2{margin:0;color:var(--sy-deep);font:500 clamp(39px,5vw,68px)/.96 Georgia,"Times New Roman",serif;letter-spacing:-.045em}
.sy-shop-intro h2 em{color:#a74a2e;font-style:italic}

.sy-story-section{
  display:grid;
  grid-template-columns:1.1fr .9fr;
  gap:70px;
  align-items:center;
  background:#f1e5d3;
}
.sy-story-image{
  min-height:650px;
  background-image:var(--story-image);
  background-size:cover;
  background-position:center;
  box-shadow:20px 25px 60px rgba(22,13,8,.13);
  transform:translateY(20px);
  transition:transform 1s ease;
}
.sy-story-image.is-visible{transform:none}
.sy-story-copy{max-width:560px}
.sy-story-copy p{max-width:500px;color:#6f5d4f;font-size:15px;line-height:1.8;margin:28px 0}
.sy-editorial-link{display:inline-flex;gap:12px;color:var(--sy-deep);font-size:11px;font-weight:800;letter-spacing:.10em;text-decoration:none;border-bottom:1px solid rgba(22,13,8,.35);padding-bottom:7px}
.sy-editorial-link:hover{color:#9b3e27;border-color:#9b3e27}

.sy-recipe-section{background:var(--sy-deep);color:var(--sy-cream)}
.sy-recipe-section .sy-section-head h2{color:var(--sy-cream)}
.sy-recipe-section .sy-section-head h2 em{color:var(--sy-gold)}
.sy-recipe-section .sy-section-label{color:var(--sy-gold)}
.sy-recipe-section .sy-section-head>p{color:#d4c4b4}
.sy-recipe-track{
  max-width:1250px;
  margin:auto;
  display:grid;
  grid-template-columns:repeat(5,minmax(190px,1fr));
  gap:12px;
}
.sy-recipe-card{
  min-height:280px;
  padding:22px;
  border:1px solid rgba(255,248,234,.15);
  background:linear-gradient(145deg,rgba(255,248,234,.06),rgba(179,54,31,.06));
  display:flex;
  flex-direction:column;
  justify-content:flex-end;
  transition:transform .4s ease,border-color .4s ease,background .4s ease;
}
.sy-recipe-card:hover{transform:translateY(-7px);border-color:rgba(232,183,90,.55);background:rgba(232,183,90,.08)}
.sy-recipe-card>span{color:var(--sy-gold);font-size:9px;letter-spacing:.15em;margin-bottom:auto}
.sy-recipe-card h3{margin:0 0 10px;color:var(--sy-cream);font:500 27px/1.05 Georgia,"Times New Roman",serif}
.sy-recipe-card p{margin:0;color:#d2c0ad;font-size:10px;line-height:1.6}

.sy-trust-section{background:#eadbc5}
.sy-trust-grid{max-width:1250px;margin:auto;display:grid;grid-template-columns:repeat(4,1fr);border-top:1px solid rgba(22,13,8,.20)}
.sy-trust-item{padding:30px 22px 15px;border-right:1px solid rgba(22,13,8,.16)}
.sy-trust-item:last-child{border-right:0}
.sy-trust-item strong{color:#a84d2f;font-size:10px;letter-spacing:.15em}
.sy-trust-item h3{margin:45px 0 13px;color:var(--sy-deep);font-size:12px;letter-spacing:.13em}
.sy-trust-item p{margin:0;color:#765f4d;font-size:11px;line-height:1.7}

.sy-wholesale-section{
  padding:120px clamp(22px,7vw,110px);
  background:#1b100b;
  color:var(--sy-cream);
}
.sy-wholesale-inner{max-width:1100px;margin:auto}
.sy-wholesale-inner .sy-section-label{color:var(--sy-gold)}
.sy-wholesale-inner h2{color:var(--sy-cream);font-size:clamp(45px,6vw,82px)}
.sy-wholesale-inner h2 em{color:var(--sy-gold)}
.sy-wholesale-paths{display:grid;grid-template-columns:1fr 1fr;margin-top:60px;border-top:1px solid rgba(255,248,234,.16)}
.sy-wholesale-paths a{
  position:relative;
  display:block;
  padding:25px 30px 25px 0;
  color:var(--sy-cream);
  text-decoration:none;
  border-right:1px solid rgba(255,248,234,.16);
  transition:padding .3s ease,color .3s ease;
}
.sy-wholesale-paths a+ a{padding-left:30px;border-right:0}
.sy-wholesale-paths a:hover{color:var(--sy-gold);padding-top:21px}
.sy-wholesale-paths span{display:block;color:var(--sy-gold);font-size:9px;margin-bottom:25px}
.sy-wholesale-paths strong{display:block;font-size:12px;letter-spacing:.12em}
.sy-wholesale-paths small{display:block;margin-top:10px;color:#cbbbaa;font-size:11px;line-height:1.6}
.sy-wholesale-paths b{position:absolute;right:25px;bottom:25px;font-size:18px;font-weight:400}

.sy-final-cta{
  padding:130px 22px;
  text-align:center;
  background:
    radial-gradient(circle at 50% 30%,rgba(232,183,90,.16),transparent 30%),
    linear-gradient(145deg,#4d1e12,#24100b);
  color:var(--sy-cream);
}
.sy-final-cta>div{max-width:850px;margin:auto}
.sy-final-cta .sy-section-label{color:var(--sy-turmeric)}
.sy-final-cta h2{color:var(--sy-cream);font-size:clamp(48px,7vw,92px)}
.sy-final-cta h2 em{color:var(--sy-gold)}
.sy-final-cta p{max-width:520px;margin:25px auto 30px;color:#e6d5c3;font-size:14px;line-height:1.75}

.sy-reveal{opacity:0;transform:translateY(26px);transition:opacity .85s ease,transform .85s cubic-bezier(.22,.61,.36,1)}
.sy-reveal.is-visible{opacity:1;transform:none}

@keyframes syKenBurns{from{transform:scale(1.04) translate3d(-.5%,0,0)}to{transform:scale(1.10) translate3d(.6%,-.5%,0)}}
@keyframes syHeroIn{from{opacity:0;transform:translate3d(-24px,20px,0);filter:blur(4px)}to{opacity:1;transform:none;filter:blur(0)}}
@keyframes syRevealLeft{from{opacity:0;transform:translateX(-18px)}to{opacity:1;transform:none}}
@keyframes syHeadlineIn{from{opacity:0;transform:translateY(38px);filter:blur(5px)}to{opacity:1;transform:none;filter:blur(0)}}
@keyframes syFadeUp{from{opacity:0;transform:translateY(18px)}to{opacity:1;transform:none}}
@keyframes syBadgeIn{from{opacity:0;transform:translateY(20px)}to{opacity:1;transform:none}}
@keyframes syBadgeFloat{0%,100%{transform:translateY(0)}50%{transform:translateY(-8px)}}
@keyframes syScroll{0%{transform:translateY(0);opacity:0}25%{opacity:1}100%{transform:translateY(58px);opacity:0}}
@keyframes syDust{0%{opacity:0;transform:translate(0,25px) scale(.5)}15%{opacity:.55}60%{opacity:.8;transform:translate(15px,-130px) scale(1)}100%{opacity:0;transform:translate(-14px,-235px) scale(.3)}}
@keyframes syMarquee{from{transform:translateX(0)}to{transform:translateX(-50%)}}
@keyframes syGrain{0%{transform:translate(0,0)}25%{transform:translate(-1%,1%)}50%{transform:translate(1%,-1%)}75%{transform:translate(1%,1%)}100%{transform:translate(-1%,-1%)}}

@media(max-width:1000px){
  .sy-flavour-grid{grid-template-columns:repeat(2,1fr)}
  .sy-recipe-track{grid-template-columns:repeat(3,1fr)}
  .sy-trust-grid{grid-template-columns:repeat(2,1fr)}
  .sy-trust-item:nth-child(2){border-right:0}
  .sy-trust-item:nth-child(n+3){border-top:1px solid rgba(22,13,8,.16)}
}
@media(max-width:760px){
  .sy-cinematic-hero{min-height:calc(100svh - 90px)!important;padding:75px 20px 80px!important;justify-content:center!important;text-align:center!important}
  .sy-hero-media{background-position:58% center}
  .sy-hero-copy{max-width:100%}
  .sy-kicker{justify-content:center;font-size:8px}
  .sy-kicker span{width:18px}
  .sy-eyebrow{font-size:9px!important}
  .sy-hero-copy h1{font-size:clamp(40px,11vw,56px)!important;line-height:.98!important}
  .sy-hero-description{font-size:14px!important;line-height:1.65!important;margin-left:auto!important;margin-right:auto!important}
  .sy-hero-actions{justify-content:center!important;flex-wrap:wrap}
  .sy-trust-row{justify-content:center;gap:7px 0}
  .sy-trust-row span{padding:0 10px;font-size:10px}
  .sy-hero-editorial{display:none}
  .sy-scroll-indicator{right:12px;bottom:12px;transform:scale(.75)}
  .sy-section-head{display:block;margin-bottom:30px}
  .sy-section-head>p{margin-top:20px}
  .sy-flavour-section,.sy-story-section,.sy-recipe-section,.sy-trust-section{padding:78px 20px}
  .sy-flavour-grid{grid-template-columns:1fr}
  .sy-flavour-card{min-height:330px}
  .sy-shop-intro{padding:50px 20px 0}
  .sy-story-section{display:block}
  .sy-story-image{min-height:430px;margin-bottom:42px}
  .sy-recipe-track{display:flex;overflow-x:auto;scroll-snap-type:x mandatory;padding-bottom:8px}
  .sy-recipe-card{min-width:260px;scroll-snap-align:start}
  .sy-trust-grid{grid-template-columns:1fr}
  .sy-trust-item,.sy-trust-item:nth-child(2){border-right:0;border-top:1px solid rgba(22,13,8,.16)}
  .sy-trust-item:first-child{border-top:0}
  .sy-wholesale-section{padding:85px 20px}
  .sy-wholesale-paths{grid-template-columns:1fr}
  .sy-wholesale-paths a,.sy-wholesale-paths a+a{padding:24px 0;border-right:0;border-bottom:1px solid rgba(255,248,234,.16)}
  .sy-wholesale-paths a+a{padding-left:0}
  .sy-final-cta{padding:95px 20px}
}
@media(max-width:380px){
  .sy-hero-copy h1{font-size:38px!important}
  .sy-primary-cta{width:100%;justify-content:center}
  .sy-story-cta{font-size:11px}
}
@media(prefers-reduced-motion:reduce){
  html{scroll-behavior:auto}
  .sy-hero-media,.sy-hero-grain,.sy-spice-dust i,.sy-hero-copy,.sy-kicker,.sy-eyebrow,
  .sy-hero-copy h1,.sy-hero-description,.sy-hero-actions,.sy-trust-row,.sy-hero-editorial,
  .sy-scroll-indicator i:after,.sy-spice-marquee>div,.sy-reveal{
    animation:none!important;transition:none!important
  }
  .sy-reveal{opacity:1!important;transform:none!important}
}
"@

if ($css -notmatch 'SPICES OF YASH - CINEMATIC INDIAN SPICE HOUSE') {
  $css += $cssPatch
}

# Add a tiny IntersectionObserver enhancement to the existing page without editing app.js.
$observer = @'
<script>
(function(){
  if (window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    document.querySelectorAll(".sy-reveal").forEach(function(el){el.classList.add("is-visible");});
    return;
  }
  if (!("IntersectionObserver" in window)) {
    document.querySelectorAll(".sy-reveal").forEach(function(el){el.classList.add("is-visible");});
    return;
  }
  var io = new IntersectionObserver(function(entries){
    entries.forEach(function(entry){
      if(entry.isIntersecting){
        entry.target.classList.add("is-visible");
        io.unobserve(entry.target);
      }
    });
  },{threshold:.12,rootMargin:"0px 0px -40px 0px"});
  document.querySelectorAll(".sy-reveal").forEach(function(el){io.observe(el);});
})();
</script>
'@

if ($html -notmatch 'querySelectorAll\("\.sy-reveal"\)') {
  $html = [regex]::Replace($html,'(?is)</body>',$observer + "`r`n</body>",1)
}

# Write UTF-8 without BOM.
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($indexPath,$html,$utf8)
[System.IO.File]::WriteAllText($cssPath,$css,$utf8)

# Validation. Restore the backup on failure.
try {
  $checkHtml = Get-Content -LiteralPath $indexPath -Raw
  $checkCss = Get-Content -LiteralPath $cssPath -Raw

  foreach ($marker in @('id="product-grid"','id="cart-open"','id="checkout-form"')) {
    if (!$checkHtml.Contains($marker)) { throw "Storefront marker lost: $marker" }
  }
  if ($checkHtml -notmatch '(?i)<meta\s+charset="UTF-8"') { throw "UTF-8 charset validation failed." }
  if ($checkHtml -notmatch 'sy-cinematic-hero') { throw "Hero validation failed." }
  if ($checkCss -notmatch 'SPICES OF YASH - CINEMATIC INDIAN SPICE HOUSE') { throw "CSS validation failed." }
} catch {
  Copy-Item -LiteralPath (Join-Path $backup "index.html") -Destination $indexPath -Force
  Copy-Item -LiteralPath (Join-Path $backup "styles.css") -Destination $cssPath -Force
  throw
}

Write-Host ""
Write-Host "SPICES OF YASH CINEMATIC INDIAN SPICE HOUSE APPLIED." -ForegroundColor Green
Write-Host "Frontend only: public\index.html and public\styles.css changed." -ForegroundColor Green
Write-Host "Hero media: $heroImage" -ForegroundColor Cyan
Write-Host "Added cinematic hero, flavour discovery, marquee, editorial story, recipes, trust, wholesale and final CTA." -ForegroundColor Green
Write-Host "Added scroll reveal, spice dust, Ken Burns motion, responsive layout and reduced-motion support." -ForegroundColor Green
Write-Host "Backend, database, .env, package.json, payments and server.js were NOT changed." -ForegroundColor Green
Write-Host "Backup: $backup" -ForegroundColor Cyan
Write-Host ""
Write-Host "Now run: npm start" -ForegroundColor Yellow
Write-Host "Open: http://localhost:3000" -ForegroundColor Yellow
Write-Host "Then hard refresh with Ctrl+F5." -ForegroundColor Yellow
