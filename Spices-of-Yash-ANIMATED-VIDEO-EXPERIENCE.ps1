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

foreach ($marker in @('id="product-grid"','id="cart-open"','id="checkout-form"')) {
  if (!$html.Contains($marker)) { throw "Required storefront marker missing: $marker. Nothing changed." }
}

if (!$html.Contains('class="hero-video-bg"')) {
  throw 'The current hero video was not found. This animation patch expects the existing video hero. Nothing changed.'
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = Join-Path $ProjectPath ("animated-video-backup-" + $stamp)
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $indexPath -Destination (Join-Path $backup "index.html") -Force
Copy-Item -LiteralPath $cssPath -Destination (Join-Path $backup "styles.css") -Force

# Add a lightweight animated layer around the EXISTING video.
# The video source itself is untouched.
$animationHtml = @'
  <div class="spice-orbit" aria-hidden="true">
    <span class="orbit-particle particle-a"></span>
    <span class="orbit-particle particle-b"></span>
    <span class="orbit-particle particle-c"></span>
    <span class="orbit-particle particle-d"></span>
    <span class="orbit-particle particle-e"></span>
    <span class="orbit-particle particle-f"></span>
  </div>
  <div class="spice-light-sweep" aria-hidden="true"></div>
  <div class="hero-scroll-pulse" aria-hidden="true"><span></span></div>
'@

if (!$html.Contains('class="spice-orbit"')) {
  $anchor = '<div class="hero-video-overlay" aria-hidden="true"></div>'
  if ($html.Contains($anchor)) {
    $html = $html.Replace($anchor, $anchor + "`r`n" + $animationHtml)
  } else {
    throw 'hero-video-overlay anchor not found. Nothing changed.'
  }
}

# Add animation classes without changing commerce logic.
$animatedCss = @'

/* =========================================================
   SPICES OF YASH — ANIMATED VIDEO EXPERIENCE
   The supplied hero video remains the hero.
   This layer makes the WEBSITE feel alive around it.
   Frontend only.
   ========================================================= */

.hero-video{
  --sy-motion-ease:cubic-bezier(.22,.61,.36,1);
  perspective:1200px;
}

/* Cinematic movement inside the existing video */
.hero-video-bg{
  transform:scale(1.035);
  animation:syVideoBreath 18s ease-in-out infinite alternate;
  will-change:transform;
}

/* Deep vignette slowly breathes with the video */
.hero-video-overlay{
  animation:syVignetteBreath 9s ease-in-out infinite alternate;
}

/* Hero content enters like an editorial motion sequence */
.hero-video-copy{
  animation:syHeroEnter 1.15s var(--sy-motion-ease) both;
}

.hero-video-copy .eyebrow{
  animation:syEyebrowIn .8s .15s var(--sy-motion-ease) both;
}

.hero-video-copy h1{
  animation:syHeadlineIn 1.15s .22s var(--sy-motion-ease) both;
}

.hero-video-copy .hero-description{
  animation:syFadeUp .9s .45s var(--sy-motion-ease) both;
}

.hero-video-copy .hero-ctas{
  animation:syFadeUp .9s .6s var(--sy-motion-ease) both;
}

.hero-video-copy .hero-trust{
  animation:syFadeUp .9s .78s var(--sy-motion-ease) both;
}

/* Animated warm light passing across the hero */
.spice-light-sweep{
  position:absolute;
  inset:-30% -45%;
  z-index:0;
  pointer-events:none;
  background:linear-gradient(
    105deg,
    transparent 42%,
    rgba(236,181,78,.035) 47%,
    rgba(255,230,163,.10) 50%,
    rgba(236,181,78,.035) 53%,
    transparent 58%
  );
  transform:translateX(-48%) rotate(2deg);
  animation:syLightSweep 11s 2s ease-in-out infinite;
  mix-blend-mode:screen;
}

/* Floating spice-like particles */
.spice-orbit{
  position:absolute;
  inset:0;
  z-index:1;
  pointer-events:none;
  overflow:hidden;
}

.orbit-particle{
  position:absolute;
  display:block;
  width:5px;
  height:5px;
  border-radius:50%;
  background:#e6b65d;
  opacity:0;
  box-shadow:0 0 12px rgba(230,182,93,.7);
}

.particle-a{left:18%;bottom:19%;animation:syParticleFloat 7s 0s ease-in-out infinite}
.particle-b{left:29%;bottom:31%;animation:syParticleFloat 9s 1.4s ease-in-out infinite}
.particle-c{left:65%;bottom:24%;animation:syParticleFloat 8s 2.2s ease-in-out infinite}
.particle-d{left:76%;bottom:38%;animation:syParticleFloat 10s 3s ease-in-out infinite}
.particle-e{left:86%;bottom:18%;animation:syParticleFloat 7.5s 1s ease-in-out infinite}
.particle-f{left:52%;bottom:15%;animation:syParticleFloat 11s 4s ease-in-out infinite}

/* Tiny parallax-like floating brand panel */
.hero-video .hero-note,
.hero-video .hero-trust{
  transform:translateZ(0);
}

.hero-video .hero-trust span{
  transition:transform .35s ease,color .35s ease;
}

.hero-video .hero-trust span:hover{
  transform:translateY(-3px);
  color:#efc46e;
}

/* Button feels physical */
.hero-video-copy .hero-primary{
  animation:syButtonGlow 4.5s 2s ease-in-out infinite;
}

.hero-video-copy .hero-primary:hover{
  transform:translateY(-3px) scale(1.035)!important;
}

/* Scroll indicator becomes a living cue */
.hero-scroll-pulse{
  position:absolute;
  right:42px;
  bottom:30px;
  z-index:3;
  width:24px;
  height:48px;
  border:1px solid rgba(255,248,234,.45);
  border-radius:20px;
  display:flex;
  justify-content:center;
  padding-top:8px;
  opacity:.85;
}

.hero-scroll-pulse span{
  width:4px;
  height:9px;
  border-radius:4px;
  background:#e8b85e;
  animation:syScrollDot 1.8s ease-in-out infinite;
}

/* If the existing right-side pantry card exists, gently float it */
.hero-video .hero-note{
  animation:syCardFloat 6s ease-in-out infinite;
  transform-origin:center;
}

/* Section reveal helper — no JS dependency */
#shop{
  animation:sySectionReveal .9s both;
}

/* Keyframes */
@keyframes syVideoBreath{
  from{transform:scale(1.035) translate3d(-.25%,0,0)}
  to{transform:scale(1.085) translate3d(.25%,-.35%,0)}
}

@keyframes syVignetteBreath{
  from{opacity:.88}
  to{opacity:1}
}

@keyframes syHeroEnter{
  from{opacity:0;transform:translate3d(0,28px,0) scale(.985)}
  to{opacity:1;transform:translate3d(0,0,0) scale(1)}
}

@keyframes syEyebrowIn{
  from{opacity:0;transform:translate3d(-18px,0,0);letter-spacing:.32em}
  to{opacity:1;transform:none;letter-spacing:normal}
}

@keyframes syHeadlineIn{
  from{opacity:0;transform:translate3d(0,45px,0);filter:blur(5px)}
  to{opacity:1;transform:none;filter:blur(0)}
}

@keyframes syFadeUp{
  from{opacity:0;transform:translate3d(0,22px,0)}
  to{opacity:1;transform:none}
}

@keyframes syLightSweep{
  0%,42%{transform:translateX(-55%) rotate(2deg);opacity:0}
  50%{opacity:1}
  66%,100%{transform:translateX(55%) rotate(2deg);opacity:0}
}

@keyframes syParticleFloat{
  0%{opacity:0;transform:translate3d(0,20px,0) scale(.6)}
  18%{opacity:.7}
  50%{opacity:.95;transform:translate3d(12px,-70px,0) scale(1)}
  82%{opacity:.35}
  100%{opacity:0;transform:translate3d(-12px,-135px,0) scale(.45)}
}

@keyframes syButtonGlow{
  0%,70%,100%{box-shadow:0 12px 32px rgba(0,0,0,.20)}
  78%{box-shadow:0 15px 38px rgba(226,174,76,.28)}
  85%{box-shadow:0 12px 32px rgba(0,0,0,.20)}
}

@keyframes syScrollDot{
  0%{opacity:.25;transform:translateY(0)}
  50%{opacity:1;transform:translateY(13px)}
  100%{opacity:.25;transform:translateY(0)}
}

@keyframes syCardFloat{
  0%,100%{transform:translateY(0) rotate(0)}
  50%{transform:translateY(-6px) rotate(.35deg)}
}

@keyframes sySectionReveal{
  from{opacity:.7;transform:translateY(12px)}
  to{opacity:1;transform:none}
}

@media(max-width:650px){
  .hero-video-bg{
    animation-duration:22s;
  }
  .spice-light-sweep{
    animation-duration:14s;
  }
  .hero-scroll-pulse{
    right:18px;
    bottom:18px;
    transform:scale(.8);
  }
  .orbit-particle{
    width:4px;
    height:4px;
  }
}

/* Respect accessibility and battery/performance preferences */
@media(prefers-reduced-motion:reduce){
  .hero-video-bg,
  .hero-video-overlay,
  .hero-video-copy,
  .hero-video-copy .eyebrow,
  .hero-video-copy h1,
  .hero-video-copy .hero-description,
  .hero-video-copy .hero-ctas,
  .hero-video-copy .hero-trust,
  .spice-light-sweep,
  .orbit-particle,
  .hero-scroll-pulse span,
  .hero-video .hero-note,
  .hero-video-copy .hero-primary{
    animation:none!important;
    transition:none!important;
  }
}
'@

if ($css -notmatch 'SPICES OF YASH — ANIMATED VIDEO EXPERIENCE') {
  $css += $animatedCss
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($indexPath,$html,$utf8)
[System.IO.File]::WriteAllText($cssPath,$css,$utf8)

Write-Host ""
Write-Host "SPICES OF YASH ANIMATED VIDEO EXPERIENCE APPLIED." -ForegroundColor Green
Write-Host "Existing hero video kept. Added cinematic motion, reveal animations, particles, light sweep, breathing zoom and animated scroll cue." -ForegroundColor Green
Write-Host "Frontend only: index.html and styles.css changed." -ForegroundColor Green
Write-Host "Backend, database, .env, payments and server.js were NOT changed." -ForegroundColor Green
Write-Host "Backup: $backup" -ForegroundColor Cyan
Write-Host "Now refresh localhost with Ctrl+F5." -ForegroundColor Yellow
