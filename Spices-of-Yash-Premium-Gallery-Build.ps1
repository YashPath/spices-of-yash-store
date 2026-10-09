$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$index = Join-Path $root "public\index.html"
$cssPath = Join-Path $root "public\styles.css"

if (!(Test-Path -LiteralPath $index)) { throw "public\index.html not found. Put this script in spices-of-yash-store." }
if (!(Test-Path -LiteralPath $cssPath)) { throw "public\styles.css not found. Nothing changed." }

$html = [System.IO.File]::ReadAllText($index)
$css = [System.IO.File]::ReadAllText($cssPath)

# Safety gates: the customer shopping and checkout hooks must remain present.
foreach ($marker in @('id="product-grid"', 'id="cart-open"', 'id="checkout-form"', 'id="home"')) {
  if (!$html.Contains($marker)) { throw "Safety check failed: $marker missing. Nothing changed." }
}

# Identify the current hero by its id. Refuse to make assumptions if it is ambiguous.
$heroPattern = '(?is)<section\b(?=[^>]*\bid\s*=\s*["'']home["''])[^>]*>.*?</section>'
$heroMatches = [regex]::Matches($html, $heroPattern)
if ($heroMatches.Count -ne 1) {
  throw "Expected exactly one <section id='home'> hero; found $($heroMatches.Count). Nothing changed."
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = Join-Path $root "premium-spice-gallery-backup-$stamp"
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $index -Destination (Join-Path $backup "index.html")
Copy-Item -LiteralPath $cssPath -Destination (Join-Path $backup "styles.css")

# New premium hero. Keep the existing header, product grid, cart, checkout and JS intact.
$hero = @'
<section id="home" class="sy-pg-hero" aria-label="Spices of Yash">
  <div class="sy-pg-hero-photo" aria-hidden="true"></div>
  <div class="sy-pg-hero-shade" aria-hidden="true"></div>
  <div class="sy-pg-hero-content">
    <p class="sy-pg-eyebrow">SINGLE ORIGIN <span>•</span> INDIAN FARMS <span>•</span> PURE FLAVOUR</p>
    <h1>Real Spices.<br><em>Richer Stories.</em></h1>
    <p class="sy-pg-lede">Authentic Indian spices, carefully sourced from trusted farms, for everyday kitchens and unforgettable meals.</p>
    <div class="sy-pg-actions">
      <a class="sy-pg-cta" href="#shop">Shop the Pantry <span aria-hidden="true">→</span></a>
      <a class="sy-pg-secondary" href="#story">Our Story <span aria-hidden="true">↗</span></a>
    </div>
    <div class="sy-pg-trust">
      <span>✳ <b>100% Natural</b></span><span>↗ <b>India Delivery</b></span><span>◇ <b>Retail &amp; Wholesale</b></span><span>⬡ <b>Quality Assured</b></span>
    </div>
  </div>
  <div class="sy-pg-hero-caption"><span>FEATURED SPICE</span><strong>Green Cardamom</strong><small>Warm aroma · Naturally bold</small></div>
  <div class="sy-pg-scroll">SCROLL TO DISCOVER <span></span></div>
</section>
<section id="sy-spice-gallery" class="sy-pg-gallery" aria-label="Discover our spices">
  <article class="sy-pg-spice sy-pg-cardamom">
    <div class="sy-pg-spice-number">01 <small>/ 04</small></div><div class="sy-pg-spice-copy"><p>PREMIUM QUALITY</p><h2>Green<br>Cardamom</h2><span>Aromatic, fresh and full of flavour.</span><a href="#shop">Explore <b>→</b></a></div>
  </article>
  <article class="sy-pg-spice sy-pg-chilli">
    <div class="sy-pg-spice-number">02 <small>/ 04</small></div><div class="sy-pg-spice-copy"><p>BOLD FLAVOUR</p><h2>Kashmiri<br>Red Chilli</h2><span>Vibrant colour. Rich taste.</span><a href="#shop">Explore <b>→</b></a></div>
  </article>
  <article class="sy-pg-spice sy-pg-turmeric">
    <div class="sy-pg-spice-number">03 <small>/ 04</small></div><div class="sy-pg-spice-copy"><p>GOLDEN PURITY</p><h2>Turmeric</h2><span>Golden goodness, from farm to kitchen.</span><a href="#shop">Explore <b>→</b></a></div>
  </article>
  <article class="sy-pg-spice sy-pg-masala">
    <div class="sy-pg-spice-number">04 <small>/ 04</small></div><div class="sy-pg-spice-copy"><p>PERFECT BLEND</p><h2>Garam<br>Masala</h2><span>A timeless blend. Tradition in every pinch.</span><a href="#shop">Explore <b>→</b></a></div>
  </article>
</section>
<script id="sy-pg-reveal">
(function(){
  var cards = document.querySelectorAll('.sy-pg-spice');
  if (!('IntersectionObserver' in window) || window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    cards.forEach(function(card){card.classList.add('sy-pg-visible');});
    return;
  }
  var observer = new IntersectionObserver(function(entries){
    entries.forEach(function(entry){
      if(entry.isIntersecting){
        entry.target.classList.add('sy-pg-visible');
        observer.unobserve(entry.target);
      }
    });
  }, {threshold:0.16, rootMargin:'0px 0px -5% 0px'});
  cards.forEach(function(card, index){
    card.style.setProperty('--sy-pg-delay', (index * 90) + 'ms');
    observer.observe(card);
  });
})();
</script>
'@

$html = [regex]::Replace($html, $heroPattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $hero }, 1)

# Remove the previous experimental scroll journey if it exists, so there is no duplicate/overlapping reveal.
$html = [regex]::Replace($html, '(?is)<section\b(?=[^>]*\bid\s*=\s*["'']spice-journey["''])[^>]*>.*?</section>\s*', '', 1)
$html = [regex]::Replace($html, '(?is)<section\b(?=[^>]*\bid\s*=\s*["'']spice-reveal["''])[^>]*>.*?</section>\s*', '', 1)
$html = [regex]::Replace($html, '(?is)<script\b(?=[^>]*\bid\s*=\s*["'']sy-v11-spice-journey["''])[^>]*>.*?</script>\s*', '', 1)
$html = [regex]::Replace($html, '(?is)<script\b(?=[^>]*\bid\s*=\s*["'']sy-v12-spice-reveal["''])[^>]*>.*?</script>\s*', '', 1)

# Put the gallery immediately after the hero, preserving all shop/product markup.
# It is included in $hero above; no second insertion is required.

$cssBlock = @'

/* =========================================================
   SPICES OF YASH — PREMIUM GALLERY BUILD
   Presentation only. Store logic and commerce hooks untouched.
   ========================================================= */
:root{--sy-pg-ink:#140b06;--sy-pg-gold:#c88c39;--sy-pg-cream:#fff4df;--sy-pg-lime:#dfff35}
.sy-pg-hero{position:relative;isolation:isolate;min-height:590px;height:min(690px,calc(100svh - 64px));max-height:760px;overflow:hidden;background:#130b06;color:#fff8ee;display:flex;align-items:center;border-bottom:1px solid rgba(207,153,73,.35)}
.sy-pg-hero-photo{position:absolute;inset:0;z-index:0;background-image:url('/images/story-spices.webp'),url('/images/green-cardamom.jpg');background-size:cover;background-position:center 52%;transform:scale(1.035);animation:syPgHeroDrift 22s ease-in-out infinite alternate}
.sy-pg-hero-shade{position:absolute;inset:0;z-index:1;background:linear-gradient(90deg,rgba(11,6,3,.94) 0%,rgba(15,8,4,.79) 34%,rgba(17,8,3,.2) 70%,rgba(13,7,3,.35) 100%),linear-gradient(0deg,rgba(8,4,2,.62),transparent 45%,rgba(8,4,2,.18)}
.sy-pg-hero-content{width:min(1280px,calc(100% - 12vw));margin:0 auto;padding:58px 0 76px;position:relative;z-index:2}
.sy-pg-eyebrow{font:700 10px/1.5 'DM Mono',monospace;letter-spacing:.25em;color:#e7b653;margin:0 0 20px}
.sy-pg-eyebrow span{padding:0 7px;color:#ffdc83}
.sy-pg-hero h1{font:600 clamp(52px,6vw,90px)/.94 Georgia,'Times New Roman',serif;letter-spacing:-.055em;max-width:720px;margin:0;color:#fff8ed;text-wrap:balance}
.sy-pg-hero h1 em{font-style:normal;color:#d7a04b}
.sy-pg-lede{font-size:16px;line-height:1.7;color:rgba(255,247,234,.84);max-width:465px;margin:22px 0 25px}
.sy-pg-actions{display:flex;align-items:center;gap:26px;flex-wrap:wrap}
.sy-pg-cta{display:inline-flex;align-items:center;gap:18px;background:var(--sy-pg-lime);color:#160e06!important;border-radius:999px;padding:15px 22px;font-weight:750;text-decoration:none;transition:transform .25s,box-shadow .25s}
.sy-pg-cta:hover{transform:translateY(-3px);box-shadow:0 10px 32px rgba(223,255,53,.18)}
.sy-pg-secondary{color:#fff7e8!important;text-decoration:none;border-bottom:1px solid rgba(255,255,255,.45);padding:9px 0}
.sy-pg-trust{display:flex;gap:22px;flex-wrap:wrap;margin-top:31px;color:#f3cf83;font-size:12px}
.sy-pg-trust span{display:inline-flex;gap:7px;align-items:center}.sy-pg-trust b{font-weight:500;color:#fff4e3}
.sy-pg-hero-caption{position:absolute;z-index:2;right:8%;bottom:18%;display:flex;flex-direction:column;gap:6px;text-align:right;text-shadow:0 2px 15px #000;max-width:250px}
.sy-pg-hero-caption span{font:700 9px 'DM Mono',monospace;letter-spacing:.22em;color:#e8bd6a}
.sy-pg-hero-caption strong{font:italic 27px Georgia,serif;color:#fff2ce}.sy-pg-hero-caption small{color:#f4e3c6;font-size:11px}
.sy-pg-scroll{position:absolute;z-index:2;right:4%;bottom:25px;display:flex;align-items:center;gap:15px;color:#f1d7a3;font:700 9px 'DM Mono',monospace;letter-spacing:.18em}
.sy-pg-scroll span{width:40px;height:1px;background:#d8a24a}
.sy-pg-gallery{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));background:#100904;color:#fff5e7}
.sy-pg-spice{position:relative;isolation:isolate;min-height:305px;overflow:hidden;padding:24px clamp(18px,2.3vw,38px);display:flex;flex-direction:column;justify-content:space-between;border-right:1px solid rgba(255,255,255,.08);background-color:#1b1008;background-size:cover;background-position:center;transition:background-size .7s ease,filter .35s,opacity .65s ease,transform .65s cubic-bezier(.2,.7,.2,1);opacity:0;transform:translateY(28px);transition-delay:var(--sy-pg-delay,0ms)} 
.sy-pg-spice.sy-pg-visible{opacity:1;transform:translateY(0)}
.sy-pg-spice:before{content:"";position:absolute;inset:0;z-index:-1;background:linear-gradient(90deg,rgba(10,5,2,.83),rgba(10,5,2,.15)),linear-gradient(0deg,rgba(8,4,2,.62),transparent 60%);transition:opacity .4s}
.sy-pg-spice:hover:before{opacity:.82}
.sy-pg-cardamom{background-image:url('https://images.unsplash.com/photo-1615485500704-8e990f9900f7?auto=format&fit=crop&w=900&q=85')}
.sy-pg-chilli{background-image:url('https://images.unsplash.com/photo-1599909533608-19f4e2b7e3b1?auto=format&fit=crop&w=900&q=85')}
.sy-pg-turmeric{background-image:url('https://images.unsplash.com/photo-1615485290382-441e4d049cb5?auto=format&fit=crop&w=900&q=85')}
.sy-pg-masala{background-image:url('https://images.unsplash.com/photo-1596040033229-a9821ebd058d?auto=format&fit=crop&w=900&q=85')}
.sy-pg-spice-number{font:600 clamp(28px,3vw,44px)/1 Georgia,serif;color:#d9a04a}.sy-pg-spice-number small{font:700 9px 'DM Mono',monospace;letter-spacing:.12em;color:#f1d4a0}
.sy-pg-spice-copy p{font:700 9px 'DM Mono',monospace;letter-spacing:.18em;color:#e8bf70;margin:0 0 10px}
.sy-pg-spice-copy h2{font:600 clamp(25px,2.4vw,36px)/.98 Georgia,serif;letter-spacing:-.035em;margin:0 0 12px;color:#fff6e9}
.sy-pg-spice-copy>span{font-size:12px;line-height:1.55;color:rgba(255,246,232,.85);display:block;max-width:220px}
.sy-pg-spice-copy a{display:inline-flex;gap:10px;align-items:center;color:#f3ca75!important;text-decoration:none;font-size:12px;margin-top:18px}
.sy-pg-spice-copy a b{font-size:18px;font-weight:400;transition:transform .2s}.sy-pg-spice-copy a:hover b{transform:translateX(4px)}
/* Let the existing real product grid continue to own prices and add-to-bag actions. */
#product-grid{scroll-margin-top:90px}
@keyframes syPgHeroDrift{from{transform:scale(1.035) translateX(0)}to{transform:scale(1.09) translateX(-1.2%)}}
@media(max-width:900px){.sy-pg-hero{min-height:590px;height:auto}.sy-pg-hero-content{width:calc(100% - 48px);padding:70px 0 90px}.sy-pg-hero-caption{right:24px;bottom:25%;max-width:190px}.sy-pg-gallery{grid-template-columns:repeat(2,minmax(0,1fr))}.sy-pg-spice{min-height:285px}.sy-pg-trust{gap:12px 18px}}
@media(max-width:560px){.sy-pg-hero{min-height:670px}.sy-pg-hero-content{width:calc(100% - 36px);padding:54px 0 110px}.sy-pg-hero h1{font-size:clamp(48px,13vw,68px)}.sy-pg-lede{font-size:14px;max-width:350px}.sy-pg-hero-caption{right:18px;bottom:22%;max-width:150px}.sy-pg-hero-caption strong{font-size:20px}.sy-pg-trust{display:grid;grid-template-columns:1fr 1fr;font-size:11px}.sy-pg-scroll{right:18px;bottom:17px}.sy-pg-gallery{grid-template-columns:1fr 1fr}.sy-pg-spice{min-height:270px;padding:17px 15px}.sy-pg-spice-copy h2{font-size:25px}.sy-pg-spice-copy>span{font-size:11px}}
@media(prefers-reduced-motion:reduce){.sy-pg-hero-photo{animation:none}.sy-pg-cta,.sy-pg-spice,.sy-pg-spice:before{transition:none}.sy-pg-spice{opacity:1;transform:none}}
'@

if ($css -notmatch 'SPICES OF YASH — PREMIUM GALLERY BUILD') { $css += $cssBlock }

# Validate before writing. We require all original commerce hooks and exactly one new gallery.
foreach ($marker in @('id="product-grid"', 'id="cart-open"', 'id="checkout-form"', 'id="home"', 'id="sy-spice-gallery"')) {
  if (!$html.Contains($marker)) { throw "Validation failed: $marker missing. Restoring backup." }
}
if ($html -notmatch 'Real Spices\.<br><em>Richer Stories\.</em>') { throw "New hero validation failed. Restoring backup." }

try {
  [System.IO.File]::WriteAllText($index, $html, [System.Text.UTF8Encoding]::new($false))
  [System.IO.File]::WriteAllText($cssPath, $css, [System.Text.UTF8Encoding]::new($false))
  Write-Host ""
  Write-Host "SUCCESS: Premium Spice Gallery applied." -ForegroundColor Green
  Write-Host "Backup saved at: $backup" -ForegroundColor Cyan
  Write-Host "Changed only public/index.html and public/styles.css." -ForegroundColor Yellow
  Write-Host "server.js, database, .env, app.js, admin, cart and checkout were not modified." -ForegroundColor Green
} catch {
  Copy-Item (Join-Path $backup "index.html") $index -Force
  Copy-Item (Join-Path $backup "styles.css") $cssPath -Force
  throw
}
