$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$indexPath = Join-Path $root "public\index.html"
$cssPath = Join-Path $root "public\styles.css"
if (!(Test-Path $indexPath) -or !(Test-Path $cssPath)) { throw "Run this script from the spices-of-yash-store project root; public\index.html and public\styles.css must exist." }

$html = [System.IO.File]::ReadAllText($indexPath)
$css = [System.IO.File]::ReadAllText($cssPath)
foreach ($marker in @('id="product-grid"', 'id="cart-open"', 'id="checkout-form"', 'id="home"')) {
  if (!$html.Contains($marker)) { throw "Safety check failed: missing $marker. No files changed." }
}

$heroPattern = '(?is)<section\b(?=[^>]*\bid\s*=\s*["'']home["''])[^>]*>.*?</section>'
$heroMatches = [regex]::Matches($html, $heroPattern)
if ($heroMatches.Count -ne 1) { throw "Expected one home hero section; found $($heroMatches.Count). No files changed." }

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = Join-Path $root "premium-refresh-backup-$stamp"
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item $indexPath (Join-Path $backup "index.html")
Copy-Item $cssPath (Join-Path $backup "styles.css")

$hero = @'
<section id="home" class="sy-refresh-hero" aria-label="Spices of Yash">
  <div class="sy-refresh-hero-image" aria-hidden="true"></div>
  <div class="sy-refresh-hero-overlay" aria-hidden="true"></div>
  <div class="sy-refresh-hero-inner">
    <p class="sy-refresh-eyebrow"><span></span> ROOTED IN INDIA · MADE FOR YOUR TABLE</p>
    <h1>A little spice.<br><em>A lot of soul.</em></h1>
    <p class="sy-refresh-intro">Bring home the colour, aroma and warmth of thoughtfully sourced Indian spices — from everyday essentials to signature blends.</p>
    <div class="sy-refresh-hero-actions">
      <a href="#shop" class="sy-refresh-primary">Explore the pantry <span>↗</span></a>
      <a href="#story" class="sy-refresh-text-link">The story behind our spices</a>
    </div>
    <div class="sy-refresh-proof"><span>01 <b>Whole spices</b></span><span>02 <b>Freshly ground</b></span><span>03 <b>Signature blends</b></span></div>
  </div>
  <div class="sy-refresh-feature"><span>THE PANTRY FAVOURITE</span><strong>Green Cardamom</strong><small>Floral · Warm · Distinctive</small></div>
  <a class="sy-refresh-scroll" href="#sy-spice-gallery">DISCOVER THE INGREDIENTS <span>↓</span></a>
</section>
<section id="sy-spice-gallery" class="sy-refresh-gallery" aria-label="Discover our signature spices">
  <div class="sy-refresh-gallery-heading"><p>THE DETAILS MAKE THE DIFFERENCE</p><h2>Meet the flavours<br><em>behind every meal.</em></h2><span>Four pantry favourites. Endless ways to make them yours.</span></div>
  <div class="sy-refresh-spices">
    <article class="sy-refresh-spice sy-refresh-cardamom"><div class="sy-refresh-photo" role="img" aria-label="Green cardamom spices"></div><div class="sy-refresh-card-meta"><span>01 / WHOLE SPICE</span><h3>Green Cardamom</h3><p>Floral aroma, naturally bold.</p><a href="#shop">Find your favourite <b>↗</b></a></div></article>
    <article class="sy-refresh-spice sy-refresh-chilli"><div class="sy-refresh-photo" role="img" aria-label="Red chillies"></div><div class="sy-refresh-card-meta"><span>02 / BOLD COLOUR</span><h3>Kashmiri Chilli</h3><p>Vibrant colour with gentle warmth.</p><a href="#shop">Find your favourite <b>↗</b></a></div></article>
    <article class="sy-refresh-spice sy-refresh-turmeric"><div class="sy-refresh-photo" role="img" aria-label="Golden turmeric"></div><div class="sy-refresh-card-meta"><span>03 / GOLDEN ROOT</span><h3>Golden Turmeric</h3><p>Earthy character for everyday cooking.</p><a href="#shop">Find your favourite <b>↗</b></a></div></article>
    <article class="sy-refresh-spice sy-refresh-masala"><div class="sy-refresh-photo" role="img" aria-label="Garam masala spices"></div><div class="sy-refresh-card-meta"><span>04 / HOUSE BLEND</span><h3>Garam Masala</h3><p>Layered warmth in every pinch.</p><a href="#shop">Find your favourite <b>↗</b></a></div></article>
  </div>
</section>
'@

$html = [regex]::Replace($html, '(?is)<section\b(?=[^>]*\bid\s*=\s*["'']sy-spice-gallery["''])[^>]*>.*?</section>\s*', '', 1)
$html = [regex]::Replace($html, $heroPattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $hero }, 1)

# Remove duplicate decorative marquees/transition strips left by earlier experiments.
$html = [regex]::Replace($html, '(?is)<div\b(?=[^>]*\bclass\s*=\s*["''][^"'']*sy-v7-ticker[^"'']*["''])[^>]*>.*?</div>\s*</div>\s*<!-- SPICES OF YASH FINAL CINEMATIC UI END -->', '', 1)
$html = [regex]::Replace($html, '(?is)<section\b(?=[^>]*\bclass\s*=\s*["''][^"'']*sy-spice-transition[^"'']*["''])[^>]*>.*?</section>\s*', '', 1)
$html = [regex]::Replace($html, '(?is)<div\b(?=[^>]*\bclass\s*=\s*["''][^"'']*sy-spice-marquee[^"'']*["''])[^>]*>.*?</div>\s*</div>\s*', '', 1)

# Drop any old reveal JS that only targets the prior gallery cards.
$html = [regex]::Replace($html, '(?is)<script\b(?=[^>]*\bid\s*=\s*["'']sy-pg-reveal["''])[^>]*>.*?</script>\s*', '', 1)
if (!$html.Contains('id="sy-refresh-reveal"')) {
  $js = @'
<script id="sy-refresh-reveal">
(function(){
  var items = document.querySelectorAll('.sy-refresh-spice');
  if (!('IntersectionObserver' in window) || window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    items.forEach(function(item){ item.classList.add('is-visible'); });
    return;
  }
  var observer = new IntersectionObserver(function(entries){
    entries.forEach(function(entry){
      if(entry.isIntersecting){ entry.target.classList.add('is-visible'); observer.unobserve(entry.target); }
    });
  }, {threshold:0.12, rootMargin:'0px 0px -6% 0px'});
  items.forEach(function(item,index){ item.style.setProperty('--reveal-delay',(index*100)+'ms'); observer.observe(item); });
})();
</script>
'@
  $html = $html.Replace('</main>', $js + "`r`n</main>")
}

$cssBlock = @'

/* ===== Premium refresh: clean cinematic hero + editorial ingredient gallery ===== */
.sy-refresh-hero{position:relative;isolation:isolate;display:flex;align-items:center;min-height:clamp(640px,calc(100svh - 90px),820px);overflow:hidden;background:#170d07;color:#fff6e7;border-bottom:1px solid rgba(205,157,73,.22)}
.sy-refresh-hero-image{position:absolute;inset:0;z-index:-2;background-image:url('/images/story-spices.webp'),url('/images/green-cardamom.jpg');background-size:cover;background-position:center 52%;animation:syRefreshDrift 24s ease-in-out infinite alternate}
.sy-refresh-hero-overlay{position:absolute;inset:0;z-index:-1;background:linear-gradient(90deg,rgba(16,8,4,.94) 0%,rgba(18,9,4,.82) 38%,rgba(17,8,3,.34) 68%,rgba(14,7,3,.16) 100%),linear-gradient(0deg,rgba(13,6,3,.64),transparent 38%,rgba(12,6,3,.12))}
.sy-refresh-hero-inner{width:min(1240px,calc(100% - 12vw));margin:0 auto;padding:84px 0 110px;position:relative;z-index:1}
.sy-refresh-eyebrow,.sy-refresh-gallery-heading>p{font:700 10px/1.5 'DM Mono',monospace;letter-spacing:.2em;color:#e3b35e}
.sy-refresh-eyebrow span{display:inline-block;width:24px;height:1px;background:#e3b35e;vertical-align:middle;margin-right:10px}
.sy-refresh-hero h1{font:500 clamp(54px,7vw,100px)/.94 'Playfair Display',Georgia,serif;letter-spacing:-.055em;margin:24px 0;color:#fff7e9;max-width:760px}
.sy-refresh-hero h1 em,.sy-refresh-gallery-heading h2 em{font-weight:500;color:#d7a14d}
.sy-refresh-intro{max-width:480px;font-size:15px;line-height:1.85;color:rgba(255,245,226,.82);margin:24px 0 28px}
.sy-refresh-hero-actions{display:flex;align-items:center;gap:28px;flex-wrap:wrap}
.sy-refresh-primary{display:inline-flex;align-items:center;gap:22px;padding:15px 22px;border-radius:2px;background:#d5a14e;color:#1a0e06!important;text-decoration:none;font-size:12px;font-weight:700;letter-spacing:.03em;transition:background .25s,transform .25s}
.sy-refresh-primary:hover{background:#f0c777;transform:translateY(-2px)}
.sy-refresh-text-link{color:#fff2dc!important;font-size:12px;text-decoration:none;border-bottom:1px solid rgba(255,242,220,.5);padding:10px 0}
.sy-refresh-proof{display:flex;gap:26px;flex-wrap:wrap;margin-top:48px;padding-top:18px;border-top:1px solid rgba(255,245,225,.22);max-width:630px}
.sy-refresh-proof span{font:700 9px 'DM Mono',monospace;letter-spacing:.08em;color:#d6a452}
.sy-refresh-proof b{font:500 11px 'DM Sans',sans-serif;letter-spacing:0;color:#fff0d9;margin-left:7px}
.sy-refresh-feature{position:absolute;right:7%;bottom:19%;z-index:2;display:flex;flex-direction:column;align-items:flex-end;gap:7px;text-align:right;text-shadow:0 2px 18px #000}
.sy-refresh-feature>span{font:700 9px 'DM Mono',monospace;letter-spacing:.19em;color:#e5bb70}
.sy-refresh-feature strong{font:500 clamp(21px,2.5vw,34px) 'Playfair Display',Georgia,serif;color:#fff2d8}
.sy-refresh-feature small{font-size:11px;color:#e9d7ba}
.sy-refresh-scroll{position:absolute;right:5%;bottom:24px;z-index:2;display:flex;gap:16px;align-items:center;color:#f4dfbd!important;text-decoration:none;font:700 9px 'DM Mono',monospace;letter-spacing:.16em}
.sy-refresh-scroll span{display:grid;place-items:center;width:25px;height:25px;border:1px solid rgba(239,197,121,.65);border-radius:50%;font-size:14px}
.sy-refresh-gallery{background:#f2eadc;color:#27180e;padding:clamp(65px,8vw,112px) clamp(22px,7vw,100px) clamp(72px,9vw,125px)}
.sy-refresh-gallery-heading{display:grid;grid-template-columns:1.1fr .9fr;column-gap:35px;align-items:end;max-width:1240px;margin:0 auto 34px}
.sy-refresh-gallery-heading>p{grid-column:1/-1;color:#96652b;margin:0 0 17px}
.sy-refresh-gallery-heading h2{font:500 clamp(38px,5vw,65px)/1.02 'Playfair Display',Georgia,serif;letter-spacing:-.045em;margin:0}
.sy-refresh-gallery-heading h2 em{color:#a86d28}
.sy-refresh-gallery-heading>span{max-width:300px;justify-self:end;color:#796756;font-size:13px;line-height:1.8}
.sy-refresh-spices{max-width:1240px;margin:0 auto;display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:14px}
.sy-refresh-spice{background:#e5d8c4;min-width:0;opacity:0;transform:translateY(20px);transition:opacity .65s ease,transform .65s cubic-bezier(.2,.7,.2,1);transition-delay:var(--reveal-delay,0ms)}
.sy-refresh-spice.is-visible{opacity:1;transform:translateY(0)}
.sy-refresh-photo{height:clamp(200px,24vw,330px);background-color:#392317;background-size:cover;background-position:center;position:relative;overflow:hidden}
.sy-refresh-photo:after{content:"";position:absolute;inset:0;background:linear-gradient(0deg,rgba(22,11,5,.2),transparent 55%);pointer-events:none}
.sy-refresh-cardamom .sy-refresh-photo{background-image:url('/images/green-cardamom.jpg'),url('/images/story-spices.webp')}
.sy-refresh-chilli .sy-refresh-photo{background-image:url('/images/kashmiri-chilli.jpg'),url('/images/story-spices.webp')}
.sy-refresh-turmeric .sy-refresh-photo{background-image:url('/images/golden-turmeric.jpg'),url('/images/story-spices.webp')}
.sy-refresh-masala .sy-refresh-photo{background-image:url('/images/garam-masala.jpg'),url('/images/story-spices.webp')}
.sy-refresh-card-meta{padding:19px 18px 22px}
.sy-refresh-card-meta>span{font:700 9px 'DM Mono',monospace;letter-spacing:.13em;color:#95672f}
.sy-refresh-card-meta h3{font:500 clamp(19px,1.8vw,25px)/1.15 'Playfair Display',Georgia,serif;margin:12px 0 8px;color:#2a190d}
.sy-refresh-card-meta p{font-size:12px;line-height:1.65;color:#796756;margin:0 0 16px}
.sy-refresh-card-meta a{display:flex;justify-content:space-between;align-items:center;border-top:1px solid rgba(67,43,23,.2);padding-top:13px;text-decoration:none;color:#563719!important;font-size:11px;font-weight:700}
.sy-refresh-card-meta a b{font-size:16px;font-weight:400;transition:transform .2s}
.sy-refresh-card-meta a:hover b{transform:translate(3px,-3px)}
@keyframes syRefreshDrift{from{transform:scale(1.01)}to{transform:scale(1.075)}}
@media(max-width:900px){.sy-refresh-hero{min-height:690px}.sy-refresh-hero-inner{width:calc(100% - 48px)}.sy-refresh-feature{right:24px;bottom:17%}.sy-refresh-gallery-heading{grid-template-columns:1fr;gap:15px}.sy-refresh-gallery-heading>span{justify-self:start}.sy-refresh-spices{grid-template-columns:repeat(2,minmax(0,1fr))}.sy-refresh-photo{height:clamp(220px,42vw,330px)}}
@media(max-width:560px){.sy-refresh-hero{min-height:720px}.sy-refresh-hero-inner{width:calc(100% - 36px);padding:60px 0 135px}.sy-refresh-hero h1{font-size:clamp(48px,13vw,68px)}.sy-refresh-intro{font-size:14px}.sy-refresh-proof{gap:13px 18px;margin-top:32px}.sy-refresh-proof span{font-size:8px}.sy-refresh-proof b{font-size:10px}.sy-refresh-feature{bottom:17%;right:18px}.sy-refresh-feature strong{font-size:21px}.sy-refresh-scroll{right:18px;bottom:16px;font-size:8px}.sy-refresh-gallery{padding:62px 16px 72px}.sy-refresh-spices{gap:9px}.sy-refresh-photo{height:230px}.sy-refresh-card-meta{padding:14px 12px 16px}.sy-refresh-card-meta h3{font-size:19px}.sy-refresh-card-meta p{font-size:11px}}
@media(prefers-reduced-motion:reduce){.sy-refresh-hero-image{animation:none}.sy-refresh-primary,.sy-refresh-spice,.sy-refresh-card-meta a b{transition:none}.sy-refresh-spice{opacity:1;transform:none}}
'@
if ($css -notmatch 'Premium refresh: clean cinematic hero') { $css += "`r`n" + $cssBlock }

foreach ($marker in @('id="product-grid"', 'id="cart-open"', 'id="checkout-form"', 'id="home"', 'id="sy-spice-gallery"', 'id="sy-refresh-reveal"')) {
  if (!$html.Contains($marker)) { throw "Validation failed: $marker missing. No files written." }
}
if ($html -notmatch 'A little spice\.<br><em>A lot of soul\.</em>') { throw "Hero validation failed. No files written." }

try {
  [System.IO.File]::WriteAllText($indexPath,$html,[System.Text.UTF8Encoding]::new($false))
  [System.IO.File]::WriteAllText($cssPath,$css,[System.Text.UTF8Encoding]::new($false))
  Write-Host "SUCCESS: Premium landing refresh applied." -ForegroundColor Green
  Write-Host "Backup: $backup" -ForegroundColor Cyan
  Write-Host "Only public\index.html and public\styles.css were changed." -ForegroundColor Yellow
  Write-Host "Backend, database, .env, app.js, admin, cart and checkout were not modified." -ForegroundColor Green
} catch {
  Copy-Item (Join-Path $backup "index.html") $indexPath -Force
  Copy-Item (Join-Path $backup "styles.css") $cssPath -Force
  throw
}
