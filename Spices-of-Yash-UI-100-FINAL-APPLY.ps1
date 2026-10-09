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

# Commerce safety gates.
foreach ($marker in @('id="product-grid"', 'id="cart-open"', 'id="checkout-form"')) {
  if ($html -notmatch [regex]::Escape($marker)) {
    throw "Safety check failed: $marker was not found. Nothing changed."
  }
}

# Backup current final UI.
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = Join-Path $ProjectPath ("UI-100-FINAL-BACKUP-" + $stamp)
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $indexPath -Destination (Join-Path $backup "index.html")
Copy-Item -LiteralPath $cssPath -Destination (Join-Path $backup "styles.css")

# Remove accidental visible raw "html" text left by earlier encoding patches.
$html = [regex]::Replace(
  $html,
  '(?is)^\s*html\s*(?=<\s*!doctype|<\s*html\b)',
  '',
  1
)
$html = [regex]::Replace(
  $html,
  '(?is)(<html\b[^>]*>\s*)html(\s*<head\b)',
  '$1$2',
  1
)

# Ensure UTF-8.
if ($html -notmatch '(?i)<meta\s+charset\s*=') {
  $html = [regex]::Replace(
    $html,
    '(?i)(<head\b[^>]*>)',
    '$1' + "`r`n" + '<meta charset="UTF-8">',
    1
  )
}

# Remove duplicate motion/ticker blocks created by previous frontend-only patches.
$html = [regex]::Replace(
  $html,
  '(?s)\s*<script id="sy-animation-engine">.*?</script>\s*',
  "`r`n",
  1
)

# Remove previous custom ticker blocks if they have our known class.
$html = [regex]::Replace(
  $html,
  '(?s)\s*<div[^>]*class="[^"]*sy-v2-marquee[^"]*"[^>]*>.*?</div>\s*',
  "`r`n",
  1
)

# Remove previous final cleanup marker if present.
$html = [regex]::Replace(
  $html,
  '(?s)\s*<!-- SPICES OF YASH FINAL CINEMATIC UI START -->.*?<!-- SPICES OF YASH FINAL CINEMATIC UI END -->\s*',
  "`r`n",
  1
)

# Add one controlled ticker immediately after the first hero section.
$ticker = @'
<!-- SPICES OF YASH FINAL CINEMATIC UI START -->
<div class="sy-final-ticker" aria-label="Spices of Yash flavour categories">
  <div class="sy-final-ticker-track">
    <span>AUTHENTIC INDIAN FLAVOUR</span><b>•</b>
    <span>WHOLE SPICES</span><b>•</b>
    <span>GROUND SPICES</span><b>•</b>
    <span>SIGNATURE BLENDS</span><b>•</b>
    <span>AUTHENTIC INDIAN FLAVOUR</span><b>•</b>
    <span>WHOLE SPICES</span><b>•</b>
    <span>GROUND SPICES</span><b>•</b>
    <span>SIGNATURE BLENDS</span><b>•</b>
  </div>
</div>
<!-- SPICES OF YASH FINAL CINEMATIC UI END -->
'@

if ($html -match '(?s)<section\s+class="[^"]*hero[^"]*"[^>]*>.*?</section>') {
  $html = [regex]::Replace(
    $html,
    '(?s)(<section\s+class="[^"]*hero[^"]*"[^>]*>.*?</section>)',
    '$1' + "`r`n" + $ticker,
    1
  )
} elseif ($html -match '(?s)<section[^>]*class="[^"]*hero[^"]*"[^>]*>.*?</section>') {
  $html = [regex]::Replace(
    $html,
    '(?s)(<section[^>]*class="[^"]*hero[^"]*"[^>]*>.*?</section>)',
    '$1' + "`r`n" + $ticker,
    1
  )
} else {
  throw "Could not safely locate the hero section."
}

# Final UI motion engine. It only adds classes to existing DOM elements.
$motionScript = @'
<script id="sy-animation-engine">
(function () {
  "use strict";

  function initSpicesMotion() {
    var reduced = window.matchMedia &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    var header = document.querySelector(".site-header, header.site-header");
    var hero = document.querySelector(
      ".hero-cinematic, .hero-video, .hero, .hero-section"
    );

    if (header) {
      header.classList.add("sy-final-header");
    }

    if (hero) {
      hero.classList.add("sy-final-hero");
    }

    var shop = document.querySelector("#shop");
    if (shop) {
      shop.classList.add("sy-final-shop");
      shop.style.scrollMarginTop = "104px";
    }

    var revealTargets = document.querySelectorAll(
      "main section:not(.sy-final-hero), " +
      "section:not(.sy-final-hero), " +
      "#story, #promise, #recipes, #wholesale, #product-grid"
    );

    Array.prototype.forEach.call(revealTargets, function (el) {
      if (el) el.classList.add("sy-final-reveal");
    });

    var cards = document.querySelectorAll(
      "#product-grid > *, .product-card, .product-item"
    );

    Array.prototype.forEach.call(cards, function (card, i) {
      card.classList.add("sy-final-product-card");
      card.style.setProperty("--sy-final-delay", Math.min(i, 7) * 65 + "ms");
    });

    var buttons = document.querySelectorAll(
      ".btn, .button, .primary-btn, #product-grid button"
    );

    Array.prototype.forEach.call(buttons, function (button) {
      button.classList.add("sy-final-button");
    });

    if (!reduced && "IntersectionObserver" in window) {
      var observer = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add("sy-final-visible");
            observer.unobserve(entry.target);
          }
        });
      }, {
        threshold: 0.10,
        rootMargin: "0px 0px -60px 0px"
      });

      document.querySelectorAll(
        ".sy-final-reveal, .sy-final-product-card"
      ).forEach(function (el) {
        observer.observe(el);
      });
    } else {
      document.querySelectorAll(
        ".sy-final-reveal, .sy-final-product-card"
      ).forEach(function (el) {
        el.classList.add("sy-final-visible");
      });
    }

    function headerState() {
      if (!header) return;
      var y = window.scrollY || window.pageYOffset || 0;
      header.classList.toggle("sy-final-scrolled", y > 16);
    }

    headerState();
    window.addEventListener("scroll", headerState, { passive: true });

    /* Only parallax an existing hero image/video. */
    if (!reduced && hero) {
      var media = hero.querySelector(
        ".hero-photo, .hero-image, video, picture img, img"
      );

      if (media) {
        window.addEventListener("scroll", function () {
          var y = window.scrollY || 0;
          if (y < window.innerHeight) {
            media.style.setProperty(
              "--sy-final-parallax",
              Math.min(y * 0.035, 22) + "px"
            );
          }
        }, { passive: true });
      }
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initSpicesMotion);
  } else {
    initSpicesMotion();
  }
})();
</script>
'@

$html = [regex]::Replace(
  $html,
  '(?i)</body>',
  $motionScript + "`r`n</body>",
  1
)

# Final CSS layer: no layout rewrite, only polish and animation.
$css = [regex]::Replace(
  $css,
  '(?s)/\* SPICES OF YASH FINAL UI MOTION START \*/.*?/\* SPICES OF YASH FINAL UI MOTION END \*/',
  '',
  1
)

$finalCss = @'

/* SPICES OF YASH FINAL UI MOTION START */

/* Palette */
:root {
  --sy-brown: #160D08;
  --sy-brown-2: #24140C;
  --sy-gold: #E8B75A;
  --sy-gold-soft: #F2D18A;
  --sy-red: #B3361F;
  --sy-cream: #FFF8EA;
  --sy-muted: #8F7965;
}

html {
  scroll-behavior: smooth;
}

body {
  overflow-x: hidden;
}

/* Navbar */
.sy-final-header {
  position: sticky !important;
  top: 0;
  z-index: 1000 !important;
  transition:
    background-color .45s ease,
    border-color .45s ease,
    box-shadow .45s ease,
    backdrop-filter .45s ease;
}

.sy-final-header.sy-final-scrolled {
  background: rgba(22,13,8,.94) !important;
  border-bottom: 1px solid rgba(232,183,90,.18) !important;
  box-shadow: 0 14px 42px rgba(0,0,0,.18) !important;
  backdrop-filter: blur(18px);
  -webkit-backdrop-filter: blur(18px);
}

.sy-final-header a {
  transition: color .28s ease, opacity .28s ease;
}

.sy-final-header nav a:hover,
.sy-final-header .main-nav a:hover {
  color: var(--sy-gold) !important;
}

.sy-final-header nav a::after,
.sy-final-header .main-nav a::after {
  content: "";
  position: absolute;
  left: 0;
  right: 100%;
  bottom: -7px;
  height: 1px;
  background: var(--sy-gold);
  transition: right .32s cubic-bezier(.2,.75,.2,1);
}

.sy-final-header nav a:hover::after,
.sy-final-header .main-nav a:hover::after {
  right: 0;
}

/* Hero */
.sy-final-hero {
  position: relative;
  isolation: isolate;
  overflow: hidden;
}

.sy-final-hero .hero-photo,
.sy-final-hero .hero-image,
.sy-final-hero video {
  transform:
    translate3d(0,var(--sy-final-parallax,0px),0)
    scale(1.035);
  animation: sy-final-kenburns 18s ease-in-out infinite alternate;
  will-change: transform;
}

.sy-final-hero::after {
  content: "";
  position: absolute;
  inset: -20%;
  z-index: 2;
  pointer-events: none;
  background: linear-gradient(
    105deg,
    transparent 42%,
    rgba(255,248,234,.055) 49%,
    transparent 56%
  );
  transform: translateX(-60%);
  animation: sy-final-light-sweep 12s ease-in-out infinite;
}

/* Hero staged reveal */
.sy-final-hero .eyebrow {
  animation: sy-final-rise .75s .10s both cubic-bezier(.2,.75,.2,1);
}

.sy-final-hero h1 {
  animation: sy-final-rise 1s .22s both cubic-bezier(.2,.75,.2,1);
}

.sy-final-hero .hero-description {
  animation: sy-final-rise .85s .38s both cubic-bezier(.2,.75,.2,1);
}

.sy-final-hero .hero-ctas,
.sy-final-hero .hero-actions {
  animation: sy-final-rise .85s .52s both cubic-bezier(.2,.75,.2,1);
}

.sy-final-hero .hero-trust,
.sy-final-hero .hero-note {
  animation: sy-final-rise .85s .66s both cubic-bezier(.2,.75,.2,1);
}

/* One ticker only */
.sy-final-ticker {
  width: 100%;
  overflow: hidden;
  background: var(--sy-brown);
  color: var(--sy-gold-soft);
  border-top: 1px solid rgba(232,183,90,.10);
  border-bottom: 1px solid rgba(232,183,90,.12);
  white-space: nowrap;
}

.sy-final-ticker-track {
  display: inline-flex;
  align-items: center;
  gap: 20px;
  min-width: max-content;
  padding: 14px 0;
  animation: sy-final-ticker 28s linear infinite;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: .20em;
}

.sy-final-ticker b {
  color: var(--sy-red);
  font-size: 9px;
}

/* Shop anchor fix: never hide headings under sticky navbar */
#shop {
  scroll-margin-top: 104px !important;
}

/* Product cards */
#product-grid {
  perspective: 1200px;
}

.sy-final-product-card {
  opacity: 0;
  transform: translateY(30px);
  transition:
    opacity .72s var(--sy-final-delay,0ms) ease,
    transform .72s var(--sy-final-delay,0ms) cubic-bezier(.2,.75,.2,1),
    box-shadow .4s ease;
}

.sy-final-product-card.sy-final-visible {
  opacity: 1;
  transform: translateY(0);
}

#product-grid > *,
#product-grid .product-card,
#product-grid .product-item {
  position: relative;
  overflow: hidden;
  transition:
    transform .42s cubic-bezier(.2,.75,.2,1),
    box-shadow .42s ease;
}

#product-grid > *:hover,
#product-grid .product-card:hover,
#product-grid .product-item:hover {
  transform: translateY(-8px) !important;
  box-shadow: 0 24px 54px rgba(45,24,12,.15) !important;
}

#product-grid img,
#product-grid .product-image img {
  transition: transform .75s cubic-bezier(.2,.75,.2,1), filter .5s ease;
}

#product-grid > *:hover img,
#product-grid .product-card:hover img,
#product-grid .product-item:hover img {
  transform: scale(1.055);
  filter: saturate(1.06);
}

/* Product image sweep */
#product-grid > *::after,
#product-grid .product-card::after,
#product-grid .product-item::after {
  content: "";
  position: absolute;
  top: -10%;
  bottom: -10%;
  left: -80%;
  width: 45%;
  pointer-events: none;
  background: linear-gradient(
    105deg,
    transparent,
    rgba(255,248,234,.22),
    transparent
  );
  transform: skewX(-18deg);
  transition: left .8s ease;
  z-index: 5;
}

#product-grid > *:hover::after,
#product-grid .product-card:hover::after,
#product-grid .product-item:hover::after {
  left: 135%;
}

/* Add button */
#product-grid button,
#product-grid .add-btn,
#product-grid .add-to-cart {
  transition:
    transform .28s cubic-bezier(.2,.75,.2,1),
    box-shadow .28s ease;
}

#product-grid button:hover,
#product-grid .add-btn:hover,
#product-grid .add-to-cart:hover {
  transform: scale(1.08) rotate(1deg);
  box-shadow: 0 10px 24px rgba(45,24,12,.16);
}

/* Filter and search */
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
  transition: border-color .3s ease, box-shadow .3s ease, transform .3s ease;
}

input[type="search"]:focus,
.search-input:focus,
input[placeholder*="flavour" i]:focus,
input[placeholder*="flavor" i]:focus {
  transform: translateY(-1px);
  border-color: #B98245 !important;
  box-shadow: 0 8px 24px rgba(75,40,18,.10) !important;
}

/* Section reveal */
.sy-final-reveal {
  opacity: 0;
  transform: translateY(34px);
  transition:
    opacity .9s ease,
    transform .9s cubic-bezier(.2,.75,.2,1);
}

.sy-final-reveal.sy-final-visible {
  opacity: 1;
  transform: translateY(0);
}

/* Buttons */
.sy-final-button,
.btn,
.button,
.primary-btn {
  transition:
    transform .25s cubic-bezier(.2,.75,.2,1),
    box-shadow .3s ease,
    background-color .3s ease,
    border-color .3s ease;
}

.sy-final-button:hover,
.btn:hover,
.button:hover,
.primary-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 12px 30px rgba(45,24,12,.13);
}

.sy-final-button:active,
.btn:active,
.button:active,
.primary-btn:active {
  transform: scale(.985);
}

/* Mobile */
@media (max-width: 700px) {
  .sy-final-hero .hero-photo,
  .sy-final-hero .hero-image,
  .sy-final-hero video {
    animation-duration: 22s;
  }

  .sy-final-ticker-track {
    animation-duration: 32s;
    font-size: 9px;
    gap: 14px;
  }

  #shop {
    scroll-margin-top: 82px !important;
  }

  #product-grid > *:hover,
  #product-grid .product-card:hover,
  #product-grid .product-item:hover {
    transform: translateY(-4px) !important;
  }

  #product-grid > *::after,
  #product-grid .product-card::after,
  #product-grid .product-item::after {
    display: none;
  }

  .sy-final-button:hover,
  .btn:hover,
  .button:hover,
  .primary-btn:hover {
    transform: none;
    box-shadow: none;
  }
}

/* Accessibility */
@media (prefers-reduced-motion: reduce) {
  html {
    scroll-behavior: auto;
  }

  .sy-final-hero .hero-photo,
  .sy-final-hero .hero-image,
  .sy-final-hero video,
  .sy-final-hero::after,
  .sy-final-ticker-track {
    animation: none !important;
  }

  .sy-final-reveal,
  .sy-final-product-card {
    opacity: 1 !important;
    transform: none !important;
  }

  *,
  *::before,
  *::after {
    transition-duration: .001ms !important;
  }
}

@keyframes sy-final-rise {
  from {
    opacity: 0;
    transform: translateY(22px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes sy-final-kenburns {
  from { transform: translate3d(0,var(--sy-final-parallax,0px),0) scale(1.035); }
  to { transform: translate3d(0,var(--sy-final-parallax,0px),0) scale(1.075); }
}

@keyframes sy-final-light-sweep {
  0%, 58% { transform: translateX(-60%); opacity: 0; }
  66% { opacity: 1; }
  82%, 100% { transform: translateX(60%); opacity: 0; }
}

@keyframes sy-final-ticker {
  from { transform: translateX(0); }
  to { transform: translateX(-50%); }
}

/* SPICES OF YASH FINAL UI MOTION END */
'@

$css += $finalCss

$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($indexPath, $html, $utf8)
[System.IO.File]::WriteAllText($cssPath, $css, $utf8)

# Final validation.
$finalHtml = [System.IO.File]::ReadAllText($indexPath)
$finalCss  = [System.IO.File]::ReadAllText($cssPath)

foreach ($marker in @('id="product-grid"', 'id="cart-open"', 'id="checkout-form",')) {
  # Handle typo-safe validation below instead of trusting this list.
}

foreach ($marker in @('id="product-grid"', 'id="cart-open"', 'id="checkout-form"')) {
  if ($finalHtml -notmatch [regex]::Escape($marker)) {
    Copy-Item (Join-Path $backup "index.html") $indexPath -Force
    Copy-Item (Join-Path $backup "styles.css") $cssPath -Force
    throw "Final validation failed for $marker. Original frontend restored."
  }
}

if (($finalHtml -split 'sy-final-ticker').Count -gt 3) {
  Copy-Item (Join-Path $backup "index.html") $indexPath -Force
  Copy-Item (Join-Path $backup "styles.css") $cssPath -Force
  throw "Duplicate ticker detected. Original frontend restored."
}

Write-Host ""
Write-Host "SPICES OF YASH FINAL UI APPLIED SUCCESSFULLY." -ForegroundColor Green
Write-Host "Final UI: cinematic hero, premium navbar, one ticker, scroll reveals, product motion, search/filter polish, responsive motion and reduced-motion support." -ForegroundColor Green
Write-Host "Visible stray html cleanup included." -ForegroundColor Green
Write-Host "Frontend only: public\index.html and public\styles.css changed." -ForegroundColor Green
Write-Host "NOT changed: server.js, app.js, database, .env, package.json, admin, cart or checkout logic." -ForegroundColor Green
Write-Host ("Backup: " + $backup) -ForegroundColor Cyan
Write-Host "Run npm start and hard refresh localhost with Ctrl+F5." -ForegroundColor Yellow
Write-Host "After visual verification, the UI phase is ready to close." -ForegroundColor Cyan
