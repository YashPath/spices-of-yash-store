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

# Backup first.
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = Join-Path $ProjectPath ("animated-video-v2-backup-" + $stamp)
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $indexPath -Destination (Join-Path $backup "index.html") -Force
Copy-Item -LiteralPath $cssPath -Destination (Join-Path $backup "styles.css") -Force

# Find the existing hero. Do NOT require a previous video class.
$heroPattern = '(?s)<section\s+class="hero[^"]*"[^>]*>.*?</section>'
$heroMatches = [regex]::Matches($html, $heroPattern)
if ($heroMatches.Count -ne 1) {
  throw "Expected exactly one hero section. Found $($heroMatches.Count). Nothing changed."
}

$hero = $heroMatches[0].Value

# Remove an old generated animation layer if it exists, so reruns stay clean.
$hero = [regex]::Replace($hero, '(?s)\s*<div class="spice-orbit".*?</div>\s*<div class="spice-light-sweep".*?</div>\s*<div class="hero-scroll-pulse".*?</div>', '', 1)

# Ensure the requested video is actually the hero background.
$videoUrl = 'https://cdn.sceneai.art/Hero%20Section%20Video/01d1f8de-fec0-4bf5-8b48-9fc2dbc8c6b0.mp4'

if ($hero -match '(?s)<video[^>]*class="[^"]*hero-video-bg[^"]*"[^>]*>.*?</video>') {
  $hero = [regex]::Replace(
    $hero,
    '(?s)<video[^>]*class="[^"]*hero-video-bg[^"]*"[^>]*>.*?</video>',
    '<video class="hero-video-bg" autoplay loop muted playsinline preload="metadata" poster="/images/story-spices.webp" aria-hidden="true"><source src="' + $videoUrl + '" type="video/mp4"></video>',
    1
  )
} elseif ($hero -match '(?s)<video[^>]*>.*?</video>') {
  $hero = [regex]::Replace(
    $hero,
    '(?s)<video[^>]*>.*?</video>',
    '<video class="hero-video-bg" autoplay loop muted playsinline preload="metadata" poster="/images/story-spices.webp" aria-hidden="true"><source src="' + $videoUrl + '" type="video/mp4"></video>',
    1
  )
} else {
  # Put video immediately inside the hero, before its content.
  $hero = [regex]::Replace(
    $hero,
    '(<section\s+class="hero[^"]*"[^>]*>)',
    '$1' + "`r`n" + '<video class="hero-video-bg" autoplay loop muted playsinline preload="metadata" poster="/images/story-spices.webp" aria-hidden="true"><source src="' + $videoUrl + '" type="video/mp4"></video>',
    1
  )
}

# Remove old background-image hero rules that could visually cover the video.
$hero = $hero.Replace('style="background-image:', 'data-old-background-image="')

# Add animated layers directly after the video.
$animationLayers = @'
  <div class="spice-video-vignette" aria-hidden="true"></div>
  <div class="spice-light-sweep" aria-hidden="true"></div>
  <div class="spice-particles" aria-hidden="true">
    <i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i>
  </div>
  <div class="hero-scroll-pulse" aria-hidden="true"><span></span></div>
'@

if (!$hero.Contains('class="spice-video-vignette"')) {
  $hero = $hero.Replace('</video>', "</video>`r`n$animationLayers", 1)
}

$html = [regex]::Replace($html, $heroPattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $hero }, 1)

$cssPatch = @'

/* =========================================================
   SPICES OF YASH — VIDEO MOTION V2
   Uses the supplied spice video as the actual hero background.
   Frontend only.
   ========================================================= */

.hero-video,
.hero-cinematic{
  position:relative!important;
  isolation:isolate;
  overflow:hidden;
  background:#160d08!important;
}

.hero-video-bg{
  position:absolute!important;
  inset:0!important;
  z-index:-4!important;
  width:100%!important;
  height:100%!important;
  max-width:none!important;
  object-fit:cover!important;
  object-position:center!important;
  display:block!important;
  background:#160d08!important;
  transform:scale(1.04);
  animation:syVideoCinematicZoom 18s ease-in-out infinite alternate;
  will-change:transform;
}

.spice-video-vignette{
  position:absolute;
  inset:0;
  z-index:-3;
  pointer-events:none;
  background:
    linear-gradient(90deg,rgba(8,4,2,.68) 0%,rgba(8,4,2,.24) 48%,rgba(8,4,2,.34) 100%),
    linear-gradient(180deg,rgba(0,0,0,.10) 0%,rgba(0,0,0,.14) 38%,rgba(0,0,0,.58) 100%);
  animation:syVignettePulse 8s ease-in-out infinite alternate;
}

.spice-video-vignette:after{
  content:"";
  position:absolute;
  inset:-10%;
  background:radial-gradient(circle at 52% 46%,transparent 0 26%,rgba(0,0,0,.13) 56%,rgba(0,0,0,.45) 100%);
}

.spice-light-sweep{
  position:absolute;
  inset:-35% -50%;
  z-index:-2;
  pointer-events:none;
  background:linear-gradient(105deg,transparent 43%,rgba(236,181,78,.03) 47%,rgba(255,226,157,.13) 50%,rgba(236,181,78,.03) 53%,transparent 57%);
  transform:translateX(-52%) rotate(3deg);
  animation:syLightSweepV2 12s 1.5s ease-in-out infinite;
  mix-blend-mode:screen;
}

.spice-particles{
  position:absolute;
  inset:0;
  z-index:1;
  pointer-events:none;
  overflow:hidden;
}

.spice-particles i{
  position:absolute;
  left:var(--x);
  bottom:-12px;
  width:var(--s);
  height:var(--s);
  border-radius:50%;
  background:#e8b75a;
  box-shadow:0 0 12px rgba(232,183,90,.6);
  opacity:0;
  animation:sySpiceParticle 8s var(--d) ease-in-out infinite;
}

.spice-particles i:nth-child(1){--x:11%;--s:4px;--d:0s}
.spice-particles i:nth-child(2){--x:24%;--s:3px;--d:1.7s}
.spice-particles i:nth-child(3){--x:39%;--s:5px;--d:3.2s}
.spice-particles i:nth-child(4){--x:58%;--s:3px;--d:.8s}
.spice-particles i:nth-child(5){--x:69%;--s:4px;--d:2.5s}
.spice-particles i:nth-child(6){--x:78%;--s:3px;--d:4s}
.spice-particles i:nth-child(7){--x:88%;--s:5px;--d:1s}
.spice-particles i:nth-child(8){--x:52%;--s:3px;--d:5s}

.hero-video-copy{
  position:relative;
  z-index:4;
  animation:syHeroCinematicEnter 1.15s cubic-bezier(.22,.61,.36,1) both;
}

.hero-video-copy .eyebrow{
  animation:syEyebrowReveal .8s .12s cubic-bezier(.22,.61,.36,1) both;
}

.hero-video-copy h1{
  animation:syHeadlineReveal 1.1s .22s cubic-bezier(.22,.61,.36,1) both;
}

.hero-video-copy .hero-description{
  animation:syFadeReveal .9s .45s cubic-bezier(.22,.61,.36,1) both;
}

.hero-video-copy .hero-ctas{
  animation:syFadeReveal .9s .62s cubic-bezier(.22,.61,.36,1) both;
}

.hero-video-copy .hero-trust{
  animation:syFadeReveal .9s .8s cubic-bezier(.22,.61,.36,1) both;
}

.hero-video-copy .hero-primary{
  animation:syButtonBreath 4.8s 2s ease-in-out infinite;
  transition:transform .25s ease,box-shadow .25s ease!important;
}

.hero-video-copy .hero-primary:hover{
  transform:translateY(-4px) scale(1.04)!important;
  box-shadow:0 18px 45px rgba(226,174,76,.24)!important;
}

.hero-scroll-pulse{
  position:absolute;
  right:40px;
  bottom:28px;
  z-index:5;
  width:23px;
  height:46px;
  border:1px solid rgba(255,248,234,.5);
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
  animation:syScrollPulse 1.8s ease-in-out infinite;
}

@keyframes syVideoCinematicZoom{
  0%{transform:scale(1.04) translate3d(-.2%,0,0)}
  50%{transform:scale(1.065) translate3d(.1%,-.15%,0)}
  100%{transform:scale(1.09) translate3d(.25%,-.35%,0)}
}

@keyframes syVignettePulse{
  from{opacity:.88}
  to{opacity:1}
}

@keyframes syLightSweepV2{
  0%,38%{transform:translateX(-55%) rotate(3deg);opacity:0}
  50%{opacity:1}
  67%,100%{transform:translateX(55%) rotate(3deg);opacity:0}
}

@keyframes sySpiceParticle{
  0%{opacity:0;transform:translate3d(0,25px,0) scale(.5)}
  15%{opacity:.55}
  52%{opacity:.9;transform:translate3d(12px,-120px,0) scale(1)}
  82%{opacity:.25}
  100%{opacity:0;transform:translate3d(-15px,-210px,0) scale(.35)}
}

@keyframes syHeroCinematicEnter{
  from{opacity:0;transform:translate3d(0,32px,0) scale(.985);filter:blur(3px)}
  to{opacity:1;transform:none;filter:blur(0)}
}

@keyframes syEyebrowReveal{
  from{opacity:0;transform:translate3d(-18px,0,0);letter-spacing:.34em}
  to{opacity:1;transform:none}
}

@keyframes syHeadlineReveal{
  from{opacity:0;transform:translate3d(0,48px,0);filter:blur(5px)}
  to{opacity:1;transform:none;filter:blur(0)}
}

@keyframes syFadeReveal{
  from{opacity:0;transform:translate3d(0,20px,0)}
  to{opacity:1;transform:none}
}

@keyframes syButtonBreath{
  0%,72%,100%{box-shadow:0 12px 32px rgba(0,0,0,.2)}
  78%{box-shadow:0 17px 40px rgba(232,183,90,.25)}
}

@keyframes syScrollPulse{
  0%{opacity:.25;transform:translateY(0)}
  50%{opacity:1;transform:translateY(13px)}
  100%{opacity:.25;transform:translateY(0)}
}

@media(max-width:650px){
  .hero-video-bg{animation-duration:23s}
  .spice-light-sweep{animation-duration:15s}
  .hero-scroll-pulse{right:16px;bottom:16px;transform:scale(.8)}
}

@media(prefers-reduced-motion:reduce){
  .hero-video-bg,
  .spice-video-vignette,
  .spice-light-sweep,
  .spice-particles i,
  .hero-video-copy,
  .hero-video-copy .eyebrow,
  .hero-video-copy h1,
  .hero-video-copy .hero-description,
  .hero-video-copy .hero-ctas,
  .hero-video-copy .hero-trust,
  .hero-video-copy .hero-primary,
  .hero-scroll-pulse span{
    animation:none!important;
    transition:none!important;
  }
}
'@

if ($css -notmatch 'SPICES OF YASH — VIDEO MOTION V2') {
  $css += $cssPatch
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($indexPath,$html,$utf8)
[System.IO.File]::WriteAllText($cssPath,$css,$utf8)

Write-Host ""
Write-Host "SPICES OF YASH VIDEO MOTION V2 APPLIED SUCCESSFULLY." -ForegroundColor Green
Write-Host "The supplied SceneAI spice video is now forced as the hero background." -ForegroundColor Green
Write-Host "Added cinematic zoom, text choreography, particles, warm light sweep and scroll animation." -ForegroundColor Green
Write-Host "Frontend only: index.html and styles.css changed." -ForegroundColor Green
Write-Host "Backend, database, .env, payments and server.js were NOT changed." -ForegroundColor Green
Write-Host "Backup: $backup" -ForegroundColor Cyan
Write-Host "Now refresh localhost with Ctrl+F5." -ForegroundColor Yellow
