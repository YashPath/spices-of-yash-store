# Spices of Yash — Landing V3 Safe Hero Patch
# Frontend-only. Replaces ONLY <section id="home">...</section>.
# Does not touch server.js, database, .env, app.js, admin, cart, or checkout.

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$index = Join-Path $root "public\index.html"
$css   = Join-Path $root "public\styles.css"

if (!(Test-Path $index)) { throw "public\index.html not found." }
if (!(Test-Path $css))   { throw "public\styles.css not found." }

$html = Get-Content $index -Raw
$styles = Get-Content $css -Raw

# Safety gates: these must exist before anything is changed.
foreach ($marker in @(
  'id="product-grid"',
  'id="cart-open"',
  'id="checkout-form"',
  'id="home"'
)) {
  if ($html.IndexOf($marker, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
    throw "Safety check failed: $marker not found. Nothing changed."
  }
}

# Match the actual hero used by the current project.
$pattern = '(?s)<section\s+aria-label="Spices of Yash"\s+class="hero\s+sy-final-hero"\s+id="home">.*?</section>'
$matches = [regex]::Matches($html, $pattern)

if ($matches.Count -ne 1) {
  throw "Expected exactly one current Spices of Yash hero. Found $($matches.Count). Nothing changed."
}

# Backup both files before modifying them.
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = Join-Path $root "landing-v3-backup-$stamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Copy-Item $index (Join-Path $backupDir "index.html")
Copy-Item $css   (Join-Path $backupDir "styles.css")

$hero = @'
<section aria-label="Spices of Yash" class="hero sy-final-hero sy-v3-hero" id="home">
  <div class="sy-v3-media" aria-hidden="true">
    <video class="sy-v3-video" autoplay muted loop playsinline preload="metadata"
      poster="/images/story-spices.webp">
      <source src="https://cdn.sceneai.art/Hero%20Section%20Video/01d1f8de-fec0-4bf5-8b48-9fc2dbc8c6b0.mp4" type="video/mp4">
    </video>
    <div class="sy-v3-overlay"></div>
    <div class="sy-v3-grain"></div>
  </div>

  <div class="sy-v3-inner">
    <div class="sy-v3-copy">
      <p class="sy-v3-kicker">SMALL-BATCH · SINGLE ORIGIN · INDIA</p>

      <h1>Make every meal<br><em>worth remembering.</em></h1>

      <p class="sy-v3-description">
        Carefully packed Indian spices, slow-ground masalas and pantry essentials —
        made for everyday kitchens, family recipes and serious flavour.
      </p>

      <div class="sy-v3-actions">
        <a class="btn sy-v3-primary" href="#shop">Shop the pantry <span>↗</span></a>
        <a class="sy-v3-story" href="#story">Our story <span>→</span></a>
      </div>

      <div class="sy-v3-proof" aria-label="Brand highlights">
        <span>100% FLAVOUR-FIRST</span>
        <span>INDIA DELIVERY</span>
        <span>RETAIL + WHOLESALE</span>
      </div>
    </div>

    <div class="sy-v3-product" aria-label="Featured product">
      <div class="sy-v3-orbit" aria-hidden="true"></div>
      <div class="sy-v3-card">
        <div class="sy-v3-card-image">
          <img src="/images/green-cardamom.jpg" alt="Green Cardamom" onerror="this.style.display='none';this.parentElement.classList.add('is-fallback');">
          <span class="sy-v3-fallback">CARDAMOM</span>
        </div>
        <div class="sy-v3-card-meta">
          <div>
            <small>FEATURED PANTRY</small>
            <strong>Green Cardamom</strong>
          </div>
          <b>₹349</b>
        </div>
        <div class="sy-v3-card-foot">
          <span>100g · FARM-TRACEABLE</span>
          <span>SMALL BATCH</span>
        </div>
      </div>
    </div>
  </div>

  <div class="sy-v3-scroll" aria-hidden="true">
    <span>SCROLL TO EXPLORE</span><i></i>
  </div>
</section>
'@

$newHtml = [regex]::Replace($html, $pattern, $hero, 1)

$cssBlock = @'

/* =========================================================
   SPICES OF YASH — LANDING V3
   Safe hero polish. Existing commerce styles remain intact.
   ========================================================= */
.sy-v3-hero{
  position:relative;
  isolation:isolate;
  min-height:clamp(680px,92vh,900px);
  overflow:hidden;
  display:flex;
  align-items:stretch;
  background:#090806;
  color:#f7f0e6;
}
.sy-v3-media,
.sy-v3-video,
.sy-v3-overlay,
.sy-v3-grain{
  position:absolute;
  inset:0;
}
.sy-v3-media{z-index:-3;background:#090806;}
.sy-v3-video{
  width:100%;
  height:100%;
  object-fit:cover;
  object-position:center;
  filter:saturate(.9) contrast(1.08);
}
.sy-v3-overlay{
  z-index:1;
  background:
    linear-gradient(90deg,rgba(7,6,4,.94) 0%,rgba(7,6,4,.78) 36%,rgba(7,6,4,.34) 68%,rgba(7,6,4,.66) 100%),
    linear-gradient(180deg,rgba(7,6,4,.24),rgba(7,6,4,.18) 52%,rgba(7,6,4,.82));
}
.sy-v3-grain{
  z-index:2;
  opacity:.075;
  pointer-events:none;
  background-image:url("data:image/svg+xml,%3Csvg viewBox='0 0 180 180' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.9' numOctaves='3' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='.7'/%3E%3C/svg%3E");
  mix-blend-mode:soft-light;
}
.sy-v3-inner{
  position:relative;
  z-index:4;
  width:min(1240px,calc(100% - 72px));
  margin:auto;
  display:grid;
  grid-template-columns:minmax(0,1.05fr) minmax(360px,.75fr);
  align-items:center;
  gap:70px;
  padding:120px 0 90px;
}
.sy-v3-copy{max-width:760px;}
.sy-v3-kicker{
  margin:0 0 22px;
  font:600 11px/1.2 "DM Mono",monospace;
  letter-spacing:.2em;
  text-transform:uppercase;
  opacity:.82;
}
.sy-v3-hero h1{
  margin:0;
  max-width:820px;
  font-size:clamp(56px,7vw,104px);
  line-height:.91;
  letter-spacing:-.055em;
  font-weight:650;
}
.sy-v3-hero h1 em{
  font-style:normal;
  font-weight:400;
  opacity:.82;
}
.sy-v3-description{
  max-width:590px;
  margin:30px 0 0;
  font-size:17px;
  line-height:1.65;
  color:rgba(247,240,230,.74);
}
.sy-v3-actions{
  display:flex;
  align-items:center;
  gap:24px;
  margin-top:34px;
}
.sy-v3-primary{
  display:inline-flex;
  align-items:center;
  gap:14px;
  padding:15px 21px;
  border-radius:999px;
  text-decoration:none;
  background:#d9ff4f;
  color:#101208;
  font-weight:800;
  box-shadow:0 12px 45px rgba(217,255,79,.14);
}
.sy-v3-primary span{font-size:18px;}
.sy-v3-story{
  color:#f7f0e6;
  text-decoration:none;
  font-size:14px;
  border-bottom:1px solid rgba(247,240,230,.35);
  padding-bottom:5px;
}
.sy-v3-story span{margin-left:8px;}
.sy-v3-proof{
  display:flex;
  flex-wrap:wrap;
  gap:10px 24px;
  margin-top:58px;
  color:rgba(247,240,230,.55);
  font:600 10px/1.4 "DM Mono",monospace;
  letter-spacing:.13em;
}
.sy-v3-proof span+span{position:relative;}
.sy-v3-proof span+span:before{
  content:"";
  position:absolute;
  width:3px;height:3px;border-radius:50%;
  left:-14px;top:50%;
  background:currentColor;
}
.sy-v3-product{
  position:relative;
  display:flex;
  justify-content:center;
  align-items:center;
  min-height:430px;
}
.sy-v3-orbit{
  position:absolute;
  width:min(460px,42vw);
  aspect-ratio:1;
  border:1px solid rgba(217,255,79,.17);
  border-radius:50%;
  box-shadow:0 0 100px rgba(217,155,70,.1),inset 0 0 80px rgba(217,155,70,.06);
}
.sy-v3-orbit:after{
  content:"";
  position:absolute;
  inset:12%;
  border:1px solid rgba(255,255,255,.08);
  border-radius:50%;
}
.sy-v3-card{
  position:relative;
  width:min(360px,82vw);
  padding:14px;
  border:1px solid rgba(255,255,255,.16);
  border-radius:28px;
  background:rgba(18,15,11,.58);
  backdrop-filter:blur(18px);
  box-shadow:0 35px 100px rgba(0,0,0,.42);
  transform:rotate(2deg);
}
.sy-v3-card-image{
  position:relative;
  height:310px;
  overflow:hidden;
  border-radius:20px;
  background:radial-gradient(circle at 50% 38%,#a77a3d 0,#533c20 34%,#17120c 72%);
  display:grid;
  place-items:center;
}
.sy-v3-card-image img{
  width:100%;height:100%;
  object-fit:cover;
  display:block;
}
.sy-v3-fallback{
  display:none;
  font:700 25px/1 "DM Mono",monospace;
  letter-spacing:.08em;
  color:rgba(255,240,205,.75);
}
.sy-v3-card-image.is-fallback .sy-v3-fallback{display:block;}
.sy-v3-card-meta{
  display:flex;
  justify-content:space-between;
  gap:15px;
  padding:20px 8px 12px;
}
.sy-v3-card-meta small,
.sy-v3-card-foot{
  font:600 9px/1.3 "DM Mono",monospace;
  letter-spacing:.12em;
  color:rgba(247,240,230,.48);
}
.sy-v3-card-meta strong{
  display:block;
  margin-top:7px;
  font-size:20px;
  text-transform:uppercase;
  letter-spacing:-.02em;
}
.sy-v3-card-meta b{
  align-self:end;
  font-size:18px;
  white-space:nowrap;
}
.sy-v3-card-foot{
  display:flex;
  justify-content:space-between;
  gap:12px;
  padding:0 8px 8px;
}
.sy-v3-scroll{
  position:absolute;
  z-index:5;
  left:36px;
  bottom:30px;
  display:flex;
  align-items:center;
  gap:13px;
  color:rgba(247,240,230,.5);
  font:600 9px/1 "DM Mono",monospace;
  letter-spacing:.16em;
}
.sy-v3-scroll i{
  display:block;
  width:52px;height:1px;
  background:rgba(247,240,230,.3);
}
@media (max-width:900px){
  .sy-v3-inner{
    width:min(100% - 38px,720px);
    grid-template-columns:1fr;
    gap:35px;
    padding:100px 0 80px;
  }
  .sy-v3-hero h1{font-size:clamp(50px,12vw,78px);}
  .sy-v3-description{font-size:15px;}
  .sy-v3-product{min-height:330px;}
  .sy-v3-orbit{width:330px;}
  .sy-v3-card{width:min(310px,78vw);}
  .sy-v3-card-image{height:245px;}
  .sy-v3-scroll{left:20px;bottom:18px;}
}
@media (prefers-reduced-motion:reduce){
  .sy-v3-video{display:none;}
}
'@

if ($styles -notmatch 'SPICES OF YASH — LANDING V3') {
  $styles = $styles + $cssBlock
}

try {
  Set-Content -Path $index -Value $newHtml -Encoding UTF8
  Set-Content -Path $css -Value $styles -Encoding UTF8

  # Validate the important markers after writing.
  $check = Get-Content $index -Raw
  foreach ($marker in @('id="product-grid"','id="cart-open"','id="checkout-form"','id="home"')) {
    if ($check.IndexOf($marker, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
      throw "Post-write validation failed: $marker missing."
    }
  }

  if ($check -notmatch 'sy-v3-hero') {
    throw "Post-write validation failed: V3 hero not found."
  }

  Write-Host ""
  Write-Host "SUCCESS: Landing V3 applied." -ForegroundColor Green
  Write-Host "Backup: $backupDir" -ForegroundColor Cyan
  Write-Host "Changed only: public\index.html and public\styles.css" -ForegroundColor Yellow
  Write-Host "Backend/database/.env/app.js/admin/cart/checkout were not modified." -ForegroundColor Green
}
catch {
  Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "Restoring backup..." -ForegroundColor Yellow
  Copy-Item (Join-Path $backupDir "index.html") $index -Force
  Copy-Item (Join-Path $backupDir "styles.css") $css -Force
  Write-Host "RESTORED. Nothing from this patch remains applied." -ForegroundColor Green
  throw
}
