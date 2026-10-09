# Spices of Yash - Landing V5 Precision Polish
# Frontend-only. Safe patch for the current V3/V4 storefront.
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$index = Join-Path $root "public\index.html"
$css   = Join-Path $root "public\styles.css"

if (!(Test-Path $index)) { throw "public\index.html not found." }
if (!(Test-Path $css))   { throw "public\styles.css not found." }

$html = Get-Content $index -Raw
$styles = Get-Content $css -Raw

foreach ($marker in @('id="product-grid"','id="cart-open"','id="checkout-form"','id="home"','sy-v3-hero')) {
    if ($html.IndexOf($marker, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "Safety check failed: $marker not found. Nothing changed."
    }
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = Join-Path $root "landing-v5-backup-$stamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Copy-Item $index (Join-Path $backupDir "index.html")
Copy-Item $css   (Join-Path $backupDir "styles.css")

# ------------------------------------------------------------
# 1) Remove common mojibake characters from the visible HTML.
# Character codes are used so this script itself stays ASCII-safe.
# ------------------------------------------------------------
$c2 = [string]([char]0x00C2)
$e2 = [string]([char]0x00E2)
$e9 = [string]([char]0x00E9)
$badArrow = $e2 + [string]([char]0x2020) + [string]([char]0x2019)
$badBullet = $e2 + [string]([char]0x20AC) + [string]([char]0x00A2)
$badDash = $e2 + [string]([char]0x20AC) + [string]([char]0x201D)
$badTM = $e2 + [string]([char]0x201E) + [string]([char]0x00A2)
$badCopyright = $e2 + [string]([char]0x2020) + [string]([char]0x00A9)

$replacements = @(
    @($badArrow, '&rarr;'),
    @($badBullet, '&bull;'),
    @($badDash, '&mdash;'),
    @($badTM, '&trade;'),
    @($badCopyright, '&copy;'),
    @($c2 + [string]([char]0x00B7), '&middot;')
)

foreach ($pair in $replacements) {
    $html = $html.Replace($pair[0], $pair[1])
    $styles = $styles.Replace($pair[0], $pair[1])
}

# Remove the most common stray C2 before spaces / punctuation.
foreach ($ch in @(' ',':',';','|','-','+')) {
    $html = $html.Replace($c2 + $ch, $ch)
    $styles = $styles.Replace($c2 + $ch, $ch)
}

# ------------------------------------------------------------
# 2) Add a precise visual polish layer.
# Existing styles are left intact; these rules override only V3.
# ------------------------------------------------------------
$cssBlock = @'

/* =========================================================
   SPICES OF YASH - V5 PRECISION POLISH
   ========================================================= */
.sy-v3-hero{
  min-height:clamp(650px,calc(100svh - 72px),820px);
}
.sy-v3-inner{
  padding:82px 0 64px;
  gap:56px;
}
.sy-v3-copy{
  transform:translateY(-2px);
}
.sy-v3-hero h1{
  font-size:clamp(52px,6.25vw,92px);
  line-height:.88;
}
.sy-v3-description{
  margin-top:25px;
  max-width:570px;
}
.sy-v3-actions{
  margin-top:28px;
}
.sy-v3-proof{
  margin-top:38px;
}
.sy-v3-product{
  min-height:390px;
  perspective:1100px;
}
.sy-v3-card{
  transform:rotate(2deg) translateZ(0);
  transform-style:preserve-3d;
  will-change:transform;
  transition:transform .18s cubic-bezier(.2,.7,.2,1),box-shadow .18s ease;
}
.sy-v3-card:before{
  content:"";
  position:absolute;
  inset:10px;
  border-radius:22px;
  pointer-events:none;
  border:1px solid rgba(255,255,255,.05);
  transform:translateZ(10px);
}
.sy-v3-card-image{
  transform:translateZ(1px);
}
.sy-v3-orbit{
  transition:transform .35s ease;
  will-change:transform;
}
.sy-v3-scroll{
  bottom:22px;
}
@media (max-height:780px) and (min-width:901px){
  .sy-v3-inner{
    padding-top:58px;
    padding-bottom:48px;
  }
  .sy-v3-hero h1{
    font-size:clamp(48px,5.5vw,78px);
  }
  .sy-v3-description{
    margin-top:20px;
  }
  .sy-v3-actions{
    margin-top:22px;
  }
  .sy-v3-proof{
    margin-top:28px;
  }
  .sy-v3-product{
    min-height:330px;
  }
  .sy-v3-card{
    width:min(330px,82vw);
  }
  .sy-v3-card-image{
    height:270px;
  }
}
@media (max-width:900px){
  .sy-v3-hero{
    min-height:calc(100svh - 64px);
  }
  .sy-v3-inner{
    padding:76px 0 72px;
  }
  .sy-v3-product{
    min-height:300px;
  }
}
@media (prefers-reduced-motion:reduce){
  .sy-v3-card,
  .sy-v3-orbit{
    transition:none !important;
    transform:none !important;
  }
}

/* Keep the V5 interaction layer quiet when the pointer is not on the hero. */
.sy-v5-pointer-active .sy-v3-card{
  box-shadow:0 42px 110px rgba(0,0,0,.52);
}
'@

if ($styles -notmatch 'SPICES OF YASH - V5 PRECISION POLISH') {
    $styles += $cssBlock
}

# ------------------------------------------------------------
# 3) Add mouse-follow 3D interaction once, before </body>.
# ------------------------------------------------------------
$jsBlock = @'
<script id="sy-v5-3d-interaction">
(function(){
  "use strict";
  function initSpicesV5(){
    var hero = document.querySelector(".sy-v3-hero");
    var card = document.querySelector(".sy-v3-card");
    var orbit = document.querySelector(".sy-v3-orbit");
    if(!hero || !card) return;

    var reduce = window.matchMedia &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if(reduce) return;

    var raf = 0;
    var tx = 0, ty = 0, cx = 0, cy = 0;

    function render(){
      raf = 0;
      cx += (tx - cx) * .12;
      cy += (ty - cy) * .12;

      var rx = (-cy * 6).toFixed(2);
      var ry = (cx * 8).toFixed(2);
      var sx = (cx * 8).toFixed(1);
      var sy = (cy * 5).toFixed(1);

      card.style.transform =
        "rotate(2deg) translate3d(" + sx + "px," + sy + "px,0) rotateX(" +
        rx + "deg) rotateY(" + ry + "deg)";

      if(orbit){
        orbit.style.transform =
          "translate3d(" + (cx * 10).toFixed(1) + "px," +
          (cy * 7).toFixed(1) + "px,0)";
      }

      if(Math.abs(tx-cx) > .002 || Math.abs(ty-cy) > .002){
        raf = requestAnimationFrame(render);
      }
    }

    function move(e){
      var r = hero.getBoundingClientRect();
      tx = ((e.clientX - r.left) / r.width - .5) * 2;
      ty = ((e.clientY - r.top) / r.height - .5) * 2;
      hero.classList.add("sy-v5-pointer-active");
      if(!raf) raf = requestAnimationFrame(render);
    }

    function leave(){
      tx = 0; ty = 0;
      hero.classList.remove("sy-v5-pointer-active");
      if(!raf) raf = requestAnimationFrame(render);
    }

    hero.addEventListener("pointermove", move, {passive:true});
    hero.addEventListener("pointerleave", leave, {passive:true});
  }

  if(document.readyState === "loading"){
    document.addEventListener("DOMContentLoaded", initSpicesV5);
  }else{
    initSpicesV5();
  }
})();
</script>
'@

if ($html -notmatch 'sy-v5-3d-interaction') {
    $html = $html -replace '(?i)</body>', ($jsBlock + "`r`n</body>")
}

try {
    Set-Content -Path $index -Value $html -Encoding UTF8
    Set-Content -Path $css -Value $styles -Encoding UTF8

    $check = Get-Content $index -Raw

    foreach ($marker in @('id="product-grid"','id="cart-open"','id="checkout-form"','id="home"','sy-v3-hero')) {
        if ($check.IndexOf($marker, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
            throw "Post-write validation failed: $marker missing."
        }
    }

    if ($check -notmatch 'sy-v5-3d-interaction') {
        throw "Post-write validation failed: V5 interaction missing."
    }

    Write-Host ""
    Write-Host "SUCCESS: Landing V5 precision polish applied." -ForegroundColor Green
    Write-Host "Backup: $backupDir" -ForegroundColor Cyan
    Write-Host "Changed only: public/index.html and public/styles.css" -ForegroundColor Yellow
    Write-Host "Backend/database/.env/app.js/admin/cart/checkout were NOT modified." -ForegroundColor Green
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Restoring backup..." -ForegroundColor Yellow
    Copy-Item (Join-Path $backupDir "index.html") $index -Force
    Copy-Item (Join-Path $backupDir "styles.css") $css -Force
    Write-Host "RESTORED. V5 changes were not kept." -ForegroundColor Green
    throw
}
