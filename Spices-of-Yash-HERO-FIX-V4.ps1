# Spices of Yash - HERO FIX V4
# Frontend only: public\index.html and public\styles.css
#
# What it does
#  1. Makes a backup of both files.
#  2. Reads and writes files as UTF-8 (fixes the garbage characters bug).
#  3. Repairs existing mojibake (single, double or triple encoded) in both files.
#  4. Replaces the hero background media (old sunset video) with a spice video/photo.
#     ALL hero text, buttons, cards and links are kept exactly as they are.
#  5. Adds warm brown overlay + Ken Burns zoom. Safe to run again (idempotent).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\Spices-of-Yash-HERO-FIX-V4.ps1 -ProjectPath "D:\path\spices-of-yash-store"
#   Optional: -HeroImage "my-spices.webp"   (file name inside public\images)
#             -HeroVideo "hero-spices.mp4"  (file name inside public\videos, must be under 5 MB)

param(
  [string]$ProjectPath = 'D:\Project\Spices-of-Yash-Complete-Local-Project (1)\spices-of-yash-store',
  [string]$HeroImage = '',
  [string]$HeroVideo = 'hero-spices.mp4'
)

$ErrorActionPreference = 'Stop'

$utf8   = New-Object System.Text.UTF8Encoding($false)
$strict = New-Object System.Text.UTF8Encoding($false, $true)

$pub       = Join-Path $ProjectPath 'public'
$indexPath = Join-Path $pub 'index.html'
$cssPath   = Join-Path $pub 'styles.css'
$imgDir    = Join-Path $pub 'images'
$vidDir    = Join-Path $pub 'videos'

if (!(Test-Path -LiteralPath $indexPath)) { throw 'public\index.html not found. Check -ProjectPath. Nothing changed.' }
if (!(Test-Path -LiteralPath $cssPath))   { throw 'public\styles.css not found. Check -ProjectPath. Nothing changed.' }

# ---------- read as UTF-8 (NOT the default ANSI) ----------
$html = [System.IO.File]::ReadAllText($indexPath, $utf8)
$css  = [System.IO.File]::ReadAllText($cssPath, $utf8)

foreach ($marker in @('id="product-grid"', 'id="cart-open"', 'id="checkout-form"')) {
  if (!$html.Contains($marker)) { throw "Required storefront marker missing: $marker. Nothing changed." }
}

$heroPat = '(?s)<section\s+class="hero[^"]*"[^>]*>.*?</section>'
$heroMatches = [regex]::Matches($html, $heroPat)
if ($heroMatches.Count -ne 1) { throw "Expected exactly one hero section. Found $($heroMatches.Count). Nothing changed." }

# ---------- backup ----------
$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $ProjectPath ('hero-fix-v4-backup-' + $stamp)
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $indexPath -Destination (Join-Path $backup 'index.html') -Force
Copy-Item -LiteralPath $cssPath   -Destination (Join-Path $backup 'styles.css') -Force

# ---------- mojibake repair ----------
# Windows-1252 special characters (0x80-0x9F range) -> original byte
$cp1252 = @{
  0x20AC = 0x80; 0x201A = 0x82; 0x0192 = 0x83; 0x201E = 0x84; 0x2026 = 0x85; 0x2020 = 0x86
  0x2021 = 0x87; 0x02C6 = 0x88; 0x2030 = 0x89; 0x0160 = 0x8A; 0x2039 = 0x8B; 0x0152 = 0x8C
  0x017D = 0x8E; 0x2018 = 0x91; 0x2019 = 0x92; 0x201C = 0x93; 0x201D = 0x94; 0x2022 = 0x95
  0x2013 = 0x96; 0x2014 = 0x97; 0x02DC = 0x98; 0x2122 = 0x99; 0x0161 = 0x9A; 0x203A = 0x9B
  0x0153 = 0x9C; 0x017E = 0x9E; 0x0178 = 0x9F
}
$script:fixedCount = 0

function Try-DecodeRun([string]$run) {
  $bytes = New-Object 'System.Collections.Generic.List[byte]'
  foreach ($ch in $run.ToCharArray()) {
    $code = [int]$ch
    if ($code -lt 256) { $bytes.Add([byte]$code) }
    elseif ($cp1252.ContainsKey($code)) { $bytes.Add([byte]$cp1252[$code]) }
    else { return $null }
  }
  try { return $strict.GetString($bytes.ToArray()) } catch { return $null }
}

function Convert-Run([string]$run) {
  # try the whole run, then shorter prefixes (in case real text touches the end)
  for ($len = $run.Length; $len -ge 2; $len--) {
    $decoded = Try-DecodeRun $run.Substring(0, $len)
    if ($decoded -ne $null) {
      $script:fixedCount++
      return $decoded + $run.Substring($len)
    }
  }
  return $run
}

$mojiPattern = '[\u00C2-\u00F4][\u0080-\u00FF\u0152\u0153\u0160\u0161\u0178\u017D\u017E\u0192\u02C6\u02DC\u2013\u2014\u2018\u2019\u201A\u201C\u201D\u201E\u2020\u2021\u2022\u2026\u2030\u2039\u203A\u20AC\u2122]+'

function Repair-Mojibake([string]$text) {
  for ($pass = 0; $pass -lt 4; $pass++) {
    $new = [regex]::Replace($text, $mojiPattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) Convert-Run $m.Value })
    if ($new -ceq $text) { break }
    $text = $new
  }
  return $text
}

$html = Repair-Mojibake $html
$css  = Repair-Mojibake $css

# ---------- UTF-8 meta tag ----------
if ($html -notmatch '(?i)<meta\s+charset\s*=') {
  $html = [regex]::Replace($html, '(?i)(<head[^>]*>)', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $m.Groups[1].Value + "`r`n  " + '<meta charset="UTF-8">' }, 1)
} else {
  $html = [regex]::Replace($html, '(?i)<meta\s+charset\s*=\s*["''][^"'']*["'']\s*/?>', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) '<meta charset="UTF-8">' }, 1)
}

# ---------- choose hero media ----------
$imgUrl = $null
if (Test-Path -LiteralPath $imgDir) {
  $imgFile = $null
  if ($HeroImage -ne '') {
    $candidate = Join-Path $imgDir $HeroImage
    if (Test-Path -LiteralPath $candidate) { $imgFile = Get-Item -LiteralPath $candidate } else { Write-Host "WARNING: -HeroImage '$HeroImage' not found in public\images" -ForegroundColor Yellow }
  }
  if ($imgFile -eq $null) {
    $images = @(Get-ChildItem -LiteralPath $imgDir -File | Where-Object { $_.Extension -match '^\.(webp|jpg|jpeg|png)$' })
    foreach ($pat in @('hero', 'spic', 'masala', 'story', 'banner')) {
      $imgFile = $images | Where-Object { $_.Name -match $pat } | Select-Object -First 1
      if ($imgFile -ne $null) { break }
    }
    if ($imgFile -eq $null -and $images.Count -gt 0) { $imgFile = $images[0] }
  }
  if ($imgFile -ne $null) { $imgUrl = '/images/' + [System.Uri]::EscapeDataString($imgFile.Name) }
}

$videoUrl = $null
$videoFile = Join-Path $vidDir $HeroVideo
if ((Test-Path -LiteralPath $videoFile) -and ((Get-Item -LiteralPath $videoFile).Length -lt 5MB)) {
  $videoUrl = '/videos/' + [System.Uri]::EscapeDataString($HeroVideo)
} elseif (Test-Path -LiteralPath $videoFile) {
  Write-Host 'WARNING: hero video is 5 MB or bigger, skipped. Compress it for faster loading.' -ForegroundColor Yellow
}

$bgStyle = ''
$posterAttr = ''
if ($imgUrl) {
  $bgStyle = ' style="background-image:url(' + "'" + $imgUrl + "'" + ')"'
  $posterAttr = ' poster="' + $imgUrl + '"'
}
$videoTag = ''
if ($videoUrl) {
  $videoTag = '<video autoplay loop muted playsinline preload="metadata"' + $posterAttr + ' aria-hidden="true"><source src="' + $videoUrl + '" type="video/mp4"></video>'
}
$mediaMarkup = '<div class="sy-hero-media" data-sy-media="1"' + $bgStyle + ' aria-hidden="true">' + $videoTag + '</div>'

# ---------- patch hero (media only, text untouched) ----------
# re-match AFTER the mojibake repair so the repaired hero text is used
$heroMatches = [regex]::Matches($html, $heroPat)
if ($heroMatches.Count -ne 1) { throw "Hero section lost after repair. Found $($heroMatches.Count). Nothing written." }
$hero = $heroMatches[0].Value
$hero = [regex]::Replace($hero, '(?s)<div[^>]*data-sy-media[^>]*>.*?</div>\s*', '')
$hero = [regex]::Replace($hero, '(?s)<video\b[^>]*>.*?</video>\s*', '')
if ($hero -notmatch 'sy-spice-hero') {
  $hero = [regex]::Replace($hero, '(<section\s+class="hero[^"]*)(")', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $m.Groups[1].Value + ' sy-spice-hero' + $m.Groups[2].Value }, 1)
}
$hero = [regex]::Replace($hero, '(<section\b[^>]*>)', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $m.Groups[1].Value + "`r`n  " + $mediaMarkup }, 1)

$html = [regex]::Replace($html, $heroPat, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $hero }, 1)

# ---------- CSS ----------
$cssPatch = @'
/* SY SPICE HERO FIX V4 START */
.sy-spice-hero{
  position:relative!important;
  isolation:isolate;
  overflow:hidden;
  background:#160d08!important;
}
.sy-hero-media{
  position:absolute;
  inset:0;
  z-index:-4;
  background-color:#160d08;
  background-position:center;
  background-size:cover;
  background-repeat:no-repeat;
  transform:scale(1.04);
  animation:syHeroKenBurnsV4 20s ease-in-out infinite alternate;
  will-change:transform;
}
.sy-hero-media video{
  position:absolute;
  inset:0;
  width:100%;
  height:100%;
  object-fit:cover;
  object-position:center;
}
.sy-hero-media:after{
  content:"";
  position:absolute;
  inset:0;
  background:
    linear-gradient(90deg,rgba(22,13,8,.82) 0%,rgba(22,13,8,.50) 46%,rgba(22,13,8,.34) 100%),
    linear-gradient(180deg,rgba(22,13,8,.14) 0%,rgba(22,13,8,.20) 40%,rgba(22,13,8,.78) 100%);
}
.sy-spice-hero h1,
.sy-spice-hero .hero-description{
  text-shadow:0 2px 24px rgba(0,0,0,.45);
}
@keyframes syHeroKenBurnsV4{
  0%{transform:scale(1.04) translate3d(-.2%,0,0)}
  100%{transform:scale(1.09) translate3d(.25%,-.3%,0)}
}
@media(max-width:650px){
  .sy-hero-media video{display:none}
}
@media(prefers-reduced-motion:reduce){
  .sy-hero-media{animation:none!important}
}
/* SY SPICE HERO FIX V4 END */
'@

$css = [regex]::Replace($css, '(?s)\s*/\* SY SPICE HERO FIX V4 START \*/.*?/\* SY SPICE HERO FIX V4 END \*/\s*', "`r`n")
$css = $css.TrimEnd() + "`r`n`r`n" + $cssPatch + "`r`n"

# ---------- write as UTF-8 (no BOM) ----------
[System.IO.File]::WriteAllText($indexPath, $html, $utf8)
[System.IO.File]::WriteAllText($cssPath, $css, $utf8)

# ---------- validation ----------
$h2 = [System.IO.File]::ReadAllText($indexPath, $utf8)
$c2 = [System.IO.File]::ReadAllText($cssPath, $utf8)
if ($h2 -notmatch '(?i)<meta\s+charset="UTF-8"') { throw 'Validation failed: UTF-8 meta tag missing. Restore from backup: ' + $backup }
if ($h2 -notmatch 'sy-spice-hero')               { throw 'Validation failed: hero class missing. Restore from backup: ' + $backup }
foreach ($marker in @('id="product-grid"', 'id="cart-open"', 'id="checkout-form"')) {
  if (!$h2.Contains($marker)) { throw "Validation failed: marker lost ($marker). Restore from backup: $backup" }
}
$leftover = [regex]::Matches($h2 + $c2, '[\u00C2\u00C3][\u0080-\u00BF]|\u00E2[\u0080-\u00BF\u20AC\u2020\u0153]').Count

Write-Host ''
Write-Host 'SPICES OF YASH HERO FIX V4 APPLIED.' -ForegroundColor Green
Write-Host ('Broken character groups repaired: ' + $script:fixedCount) -ForegroundColor Green
if ($leftover -gt 0) { Write-Host ('WARNING: ' + $leftover + ' suspicious characters may remain. Check the page text.') -ForegroundColor Yellow }
if ($videoUrl) { Write-Host ('Hero video : ' + $videoUrl) -ForegroundColor Cyan } else { Write-Host 'Hero video : none found (put a spice video at public\videos\hero-spices.mp4)' -ForegroundColor Yellow }
if ($imgUrl)   { Write-Host ('Hero image : ' + $imgUrl + '  (change with -HeroImage "file.webp")') -ForegroundColor Cyan } else { Write-Host 'Hero image : none found in public\images' -ForegroundColor Yellow }
Write-Host 'Changed    : public\index.html, public\styles.css (hero media + overlay only)' -ForegroundColor Green
Write-Host 'Not changed: backend, database, .env, payments, server.js, hero text' -ForegroundColor Green
Write-Host ('Backup     : ' + $backup) -ForegroundColor Cyan
Write-Host 'Now run npm start, open http://localhost:3000 and press Ctrl+F5.' -ForegroundColor Yellow
