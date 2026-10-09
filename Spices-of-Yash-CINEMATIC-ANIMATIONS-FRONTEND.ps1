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

# Safety markers: do not touch the storefront if the core commerce hooks are missing.
foreach ($marker in @('id="product-grid"', 'id="cart-open"', 'id="checkout-form"')) {
  if ($html -notmatch [regex]::Escape($marker)) {
    throw "Safety check failed: $marker was not found. Nothing changed."
  }
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = Join-Path $ProjectPath ("frontend-animation-backup-" + $stamp)
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $indexPath -Destination (Join-Path $backup "index.html")
Copy-Item -LiteralPath $cssPath -Destination (Join-Path $backup "styles.css")

# Remove a previous copy of this animation layer so the script is safe to run again.
$html = [regex]::Replace(
  $html,
  '(?s)\s*<script id="sy-animation-engine">.*?</script>\s*',
  "`r`n",
  1
)

# Ensure UTF-8 is explicitly declared.
if ($html -notmatch '(?i)<meta\s+charset\s*=') {
  $html = [regex]::Replace(
    $html,
    '(?i)(<head[^>]*>)',
    '$1' + "`r`n" + '<meta charset="UTF-8">',
    1
  )
}

$animationScript = @'
<script id="sy-animation-engine">
(function () {
  "use strict";

  var reduceMotion = window.matchMedia &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  function addClass(el, name) {
    if (el) el.classList.add(name);
  }

  function setup() {
    var header = document.querySelector(
      ".site-header, header.site-header, header, nav"
    );
    var hero = document.querySelector(
      ".hero-cinematic, .hero, .hero-video, .hero-section, main > section:first-of-type"
    );

    addClass(header, "sy-motion-header");
    addClass(hero, "sy-motion-hero");

    var sections = Array.prototype.slice.call(
      document.querySelectorAll("main section, section")
    );

    sections.forEach(function (section, index) {
      if (section === hero) return;
      if (section.querySelector("#product-grid")) {
        addClass(section, "sy-motion-shop");
      } else {
        addClass(section, "sy-reveal-section");
      }
    });

    var cards = document.querySelectorAll(
      "#product-grid > *, .product-card, .product-item, .card"
    );
    Array.prototype.forEach.call(cards, function (card, index) {
      addClass(card, "sy-motion-card");
      card.style.setProperty("--sy-delay", Math.min(index, 7) * 55 + "ms");
    });

    var buttons = document.querySelectorAll(
      ".btn, .button, .primary-btn, button, a[role='button']"
    );
    Array.prototype.forEach.call(buttons, function (button) {
      addClass(button, "sy-motion-button");
    });

    if (!reduceMotion && "IntersectionObserver" in window) {
      var observer = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible");
            observer.unobserve(entry.target);
          }
        });
      }, { threshold: 0.12, rootMargin: "0px 0px -50px 0px" });

      document.querySelectorAll(
        ".sy-reveal-section, .sy-motion-card"
      ).forEach(function (el) {
        observer.observe(el);
      });
    } else {
      document.querySelectorAll(
        ".sy-reveal-section, .sy-motion-card"
      ).forEach(function (el) {
        el.classList.add("is-visible");
      });
    }

    var lastScroll = 0;
    function updateHeader() {
      var y = window.scrollY || window.pageYOffset || 0;
      if (header) {
        header.classList.toggle("sy-header-scrolled", y > 18);
        header.classList.toggle("sy-header-top", y <= 18);
      }
      lastScroll = y;
    }

    updateHeader();
    window.addEventListener("scroll", updateHeader, { passive: true });

    var cart = document.querySelector(
      "#cart-open, .cart-btn, [data-cart-open]"
    );

    if (cart) {
      addClass(cart, "sy-cart-motion");

      var count = cart.querySelector(
        ".cart-count, [data-cart-count], span"
      );

      if (count && window.MutationObserver) {
        var oldValue = count.textContent;
        new MutationObserver(function () {
          var newValue = count.textContent;
          if (newValue !== oldValue) {
            oldValue = newValue;
            count.classList.remove("sy-cart-pulse");
            void count.offsetWidth;
            count.classList.add("sy-cart-pulse");
          }
        }).observe(count, {
          childList: true,
          characterData: true,
          subtree: true
        });
      }
    }

    /* Tiny parallax on the existing hero image only. */
    if (!reduceMotion && hero) {
      var heroImage = hero.querySelector(
        ".hero-photo, .hero-image, img"
      );

      if (heroImage) {
        window.addEventListener("scroll", function () {
          var y = window.scrollY || 0;
          if (y < window.innerHeight * 1.15) {
            heroImage.style.setProperty(
              "--sy-parallax",
              Math.min(y * 0.045, 28) + "px"
            );
          }
        }, { passive: true });
      }
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", setup);
  } else {
    setup();
  }
})();
</script>
'@

$html = [regex]::Replace(
  $html,
  '(?i)</body>',
  $animationScript + "`r`n</body>",
  1
)

$animationCss = @'

/* =========================================================
   SPICES OF YASH - CINEMATIC MOTION SYSTEM
   Frontend-only progressive enhancement.
   Does not change cart, checkout, API or product logic.
   ========================================================= */

html {
  scroll-behavior: smooth;
}

body {
  overflow-x: hidden;
}

/* Header: calm glass transition on scroll */
.sy-motion-header {
  transition:
    background-color .45s ease,
    border-color .45s ease,
    box-shadow .45s ease,
    backdrop-filter .45s ease,
    transform .35s ease;
}

.sy-motion-header.sy-header-scrolled {
  background: rgba(22, 13, 8, .88) !important;
  border-bottom-color: rgba(232, 183, 90, .18) !important;
  box-shadow: 0 14px 38px rgba(0,0,0,.16);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
}

/* Navigation links: understated gold line */
.sy-motion-header a {
  position: relative;
}

.sy-motion-header nav a::after,
.sy-motion-header .main-nav a::after {
  content: "";
  position: absolute;
  left: 0;
  right: 100%;
  bottom: -7px;
  height: 1px;
  background: #e8b75a;
  transition: right .32s cubic-bezier(.2,.7,.2,1);
}

.sy-motion-header nav a:hover::after,
.sy-motion-header .main-nav a:hover::after {
  right: 0;
}

/* Hero depth */
.sy-motion-hero {
  overflow: hidden;
  isolation: isolate;
}

.sy-motion-hero .hero-photo,
.sy-motion-hero .hero-image {
  transform:
    translate3d(0, var(--sy-parallax, 0px), 0)
    scale(1.035);
  transition: transform .12s linear;
  animation: sy-hero-breathe 14s ease-in-out infinite alternate;
}

.sy-motion-hero::before {
  content: "";
  position: absolute;
  inset: 0;
  pointer-events: none;
  z-index: 1;
  background:
    radial-gradient(circle at 76% 35%, rgba(232,183,90,.10), transparent 24%),
    linear-gradient(90deg, rgba(22,13,8,.40), transparent 56%, rgba(22,13,8,.22));
}

.sy-motion-hero::after {
  content: "";
  position: absolute;
  inset: -20%;
  pointer-events: none;
  z-index: 2;
  background: linear-gradient(
    105deg,
    transparent 42%,
    rgba(255,248,234,.055) 49%,
    transparent 56%
  );
  transform: translateX(-55%);
  animation: sy-light-sweep 11s ease-in-out infinite;
}

/* Hero content entrance */
.sy-motion-hero .hero-copy,
.sy-motion-hero .hero-content {
  animation: sy-hero-content-in .9s cubic-bezier(.2,.75,.2,1) both;
}

.sy-motion-hero h1 {
  animation: sy-title-in 1.05s .12s cubic-bezier(.2,.75,.2,1) both;
}

.sy-motion-hero .hero-description {
  animation: sy-title-in .85s .30s cubic-bezier(.2,.75,.2,1) both;
}

.sy-motion-hero .hero-ctas,
.sy-motion-hero .hero-actions {
  animation: sy-title-in .85s .44s cubic-bezier(.2,.75,.2,1) both;
}

.sy-motion-hero .hero-note,
.sy-motion-hero .hero-trust {
  animation: sy-title-in .85s .58s cubic-bezier(.2,.75,.2,1) both;
}

/* Spice dust: subtle, premium, not flashy */
.sy-motion-hero .spice-dust,
.sy-motion-hero .hero-particles,
.sy-motion-hero .particles {
  pointer-events: none;
}

.sy-motion-hero .spice-dust::before,
.sy-motion-hero .hero-particles::before,
.sy-motion-hero .particles::before {
  content: "";
  position: absolute;
  width: 4px;
  height: 4px;
  top: 34%;
  left: 72%;
  border-radius: 50%;
  background: #e8b75a;
  box-shadow:
    54px 38px 0 0 rgba(232,183,90,.65),
    -92px 70px 0 0 rgba(232,183,90,.42),
    116px 126px 0 -1px rgba(242,209,138,.52),
    -40px 150px 0 -1px rgba(232,183,90,.34),
    162px 62px 0 -1px rgba(255,248,234,.30);
  opacity: .55;
  animation: sy-dust-drift 9s ease-in-out infinite alternate;
}

/* Section reveal */
.sy-reveal-section {
  opacity: 0;
  transform: translateY(34px);
  transition:
    opacity .85s ease,
    transform .85s cubic-bezier(.2,.75,.2,1);
}

.sy-reveal-section.is-visible {
  opacity: 1;
  transform: translateY(0);
}

/* Product cards */
#product-grid > *,
.product-card,
.product-item,
.card {
  --sy-delay: 0ms;
}

.sy-motion-card {
  opacity: 0;
  transform: translateY(28px);
  transition:
    opacity .72s var(--sy-delay, 0ms) ease,
    transform .72s var(--sy-delay, 0ms) cubic-bezier(.2,.75,.2,1),
    box-shadow .38s ease,
    border-color .38s ease;
}

.sy-motion-card.is-visible {
  opacity: 1;
  transform: translateY(0);
}

#product-grid > *:hover,
.product-card:hover,
.product-item:hover,
.card:hover {
  transform: translateY(-7px);
  box-shadow: 0 22px 52px rgba(45,24,12,.14);
}

#product-grid img,
.product-card img,
.product-item img {
  transition:
    transform .75s cubic-bezier(.2,.75,.2,1),
    filter .5s ease;
}

#product-grid > *:hover img,
.product-card:hover img,
.product-item:hover img {
  transform: scale(1.055);
  filter: saturate(1.07) contrast(1.02);
}

/* Buttons: sweep + press */
.sy-motion-button {
  position: relative;
  overflow: hidden;
  isolation: isolate;
  transition:
    transform .25s cubic-bezier(.2,.75,.2,1),
    box-shadow .3s ease,
    background-color .3s ease,
    border-color .3s ease;
}

.sy-motion-button::before {
  content: "";
  position: absolute;
  top: -30%;
  bottom: -30%;
  left: -75%;
  width: 45%;
  background: linear-gradient(
    105deg,
    transparent,
    rgba(255,248,234,.30),
    transparent
  );
  transform: skewX(-18deg);
  transition: left .65s ease;
  pointer-events: none;
  z-index: -1;
}

.sy-motion-button:hover {
  transform: translateY(-2px);
  box-shadow: 0 12px 30px rgba(45,24,12,.15);
}

.sy-motion-button:hover::before {
  left: 130%;
}

.sy-motion-button:active {
  transform: translateY(0) scale(.985);
}

/* Cart badge */
.sy-cart-motion {
  transition: transform .25s ease;
}

.sy-cart-pulse {
  animation: sy-cart-pulse .55s cubic-bezier(.2,.8,.2,1);
}

/* Scroll indicator if the current hero has one */
.sy-motion-hero .scroll-indicator,
.sy-motion-hero .scroll-cue {
  animation: sy-scroll-cue 2.1s ease-in-out infinite;
}

/* Keep existing forms usable while adding focus polish */
input:focus,
select:focus,
textarea:focus {
  transition:
    border-color .25s ease,
    box-shadow .25s ease;
}

/* Keyframes */
@keyframes sy-hero-breathe {
  from { transform: translate3d(0, var(--sy-parallax, 0px), 0) scale(1.035); }
  to   { transform: translate3d(0, var(--sy-parallax, 0px), 0) scale(1.075); }
}

@keyframes sy-light-sweep {
  0%, 58% { transform: translateX(-55%); opacity: 0; }
  66% { opacity: 1; }
  82%, 100% { transform: translateX(55%); opacity: 0; }
}

@keyframes sy-hero-content-in {
  from { opacity: 0; transform: translateY(22px); }
  to   { opacity: 1; transform: translateY(0); }
}

@keyframes sy-title-in {
  from { opacity: 0; transform: translateY(18px); }
  to   { opacity: 1; transform: translateY(0); }
}

@keyframes sy-dust-drift {
  from { transform: translate3d(-12px, 8px, 0); opacity: .30; }
  to   { transform: translate3d(18px, -22px, 0); opacity: .72; }
}

@keyframes sy-cart-pulse {
  0%   { transform: scale(1); }
  45%  { transform: scale(1.22); }
  100% { transform: scale(1); }
}

@keyframes sy-scroll-cue {
  0%, 100% { transform: translateY(0); opacity: .55; }
  50% { transform: translateY(7px); opacity: 1; }
}

/* Mobile: preserve performance and touch usability */
@media (max-width: 700px) {
  .sy-motion-hero .hero-photo,
  .sy-motion-hero .hero-image {
    animation-duration: 18s;
  }

  #product-grid > *:hover,
  .product-card:hover,
  .product-item:hover,
  .card:hover {
    transform: translateY(-3px);
  }

  .sy-motion-button:hover {
    transform: none;
    box-shadow: none;
  }

  .sy-motion-hero::after {
    animation-duration: 15s;
  }
}

/* Accessibility */
@media (prefers-reduced-motion: reduce) {
  html { scroll-behavior: auto; }

  *,
  *::before,
  *::after {
    animation-duration: .001ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: .001ms !important;
    scroll-behavior: auto !important;
  }

  .sy-motion-hero .hero-photo,
  .sy-motion-hero .hero-image {
    transform: none !important;
  }

  .sy-reveal-section,
  .sy-motion-card {
    opacity: 1 !important;
    transform: none !important;
  }
}
'@

# Replace an older copy of this exact CSS block if the script is rerun.
$css = [regex]::Replace(
  $css,
  '(?s)/\* =========================================================\s+SPICES OF YASH - CINEMATIC MOTION SYSTEM.*?/\* Accessibility \*/.*?\n\}',
  '',
  1
)

$css += $animationCss

$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($indexPath, $html, $utf8)
[System.IO.File]::WriteAllText($cssPath, $css, $utf8)

# Final source checks.
$finalHtml = [System.IO.File]::ReadAllText($indexPath)
$finalCss  = [System.IO.File]::ReadAllText($cssPath)

foreach ($marker in @('id="product-grid"', 'id="cart-open"', 'id="checkout-form"', 'sy-animation-engine', 'sy-motion-card')) {
  if ($marker -notin @('id="product-grid"', 'id="cart-open"', 'id="checkout-form"')) {
    if (($finalHtml + "`n" + $finalCss) -notmatch [regex]::Escape($marker)) {
      Copy-Item -LiteralPath (Join-Path $backup "index.html") -Destination $indexPath -Force
      Copy-Item -LiteralPath (Join-Path $backup "styles.css") -Destination $cssPath -Force
      throw "Final validation failed for $marker. Original frontend restored."
    }
  }
}

Write-Host ""
Write-Host "SPICES OF YASH CINEMATIC ANIMATION SYSTEM APPLIED." -ForegroundColor Green
Write-Host "Added: cinematic hero motion, spice dust, light sweep, scroll reveal, product hover, button micro-interactions, header scroll state, cart pulse and mobile/reduced-motion support." -ForegroundColor Green
Write-Host "Frontend only: public\index.html and public\styles.css changed." -ForegroundColor Green
Write-Host "NOT changed: server.js, app.js, database, .env, package.json, admin logic, cart logic and checkout logic." -ForegroundColor Green
Write-Host ("Backup: " + $backup) -ForegroundColor Cyan
Write-Host "Refresh localhost with Ctrl+F5 to see the animation layer." -ForegroundColor Yellow
