param(
  [string]$ProjectPath = "D:\Project\Spices-of-Yash-Complete-Local-Project (1)\spices-of-yash-store"
)

$ErrorActionPreference = "Stop"

$public = Join-Path $ProjectPath "public"
$indexPath = Join-Path $public "index.html"
$cssPath = Join-Path $public "styles.css"

if (!(Test-Path -LiteralPath $indexPath) -or !(Test-Path -LiteralPath $cssPath)) {
  throw "public/index.html or public/styles.css not found. Nothing changed."
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = Join-Path $ProjectPath ("frontend-precision-polish-backup-" + $stamp)
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $indexPath -Destination (Join-Path $backup "index.html") -Force
Copy-Item -LiteralPath $cssPath -Destination (Join-Path $backup "styles.css") -Force

Write-Host ""
Write-Host "SPICES OF YASH - FRONTEND PRECISION POLISH" -ForegroundColor Cyan
Write-Host "Backup: $backup" -ForegroundColor Green

$utf8 = New-Object System.Text.UTF8Encoding($false)
$cp1252 = [System.Text.Encoding]::GetEncoding(1252)

$html = [System.IO.File]::ReadAllText($indexPath, $utf8)
$css  = [System.IO.File]::ReadAllText($cssPath, $utf8)

function Get-MojibakeScore([string]$s) {
  if ([string]::IsNullOrEmpty($s)) { return 0 }
  $score = 0
  foreach ($code in @(0x00C3,0x00C2,0x00E2,0x00F0,0xFFFD)) {
    $score += ([regex]::Matches($s, [regex]::Escape([char]$code))).Count
  }
  return $score
}

# Repair double-encoded UTF-8 without relying on literal mojibake in this script.
for ($pass = 0; $pass -lt 3; $pass++) {
  $beforeScore = Get-MojibakeScore $html
  if ($beforeScore -eq 0) { break }
  try {
    $candidate = [System.Text.Encoding]::UTF8.GetString($cp1252.GetBytes($html))
  } catch {
    break
  }
  $afterScore = Get-MojibakeScore $candidate
  if ($afterScore -lt $beforeScore) { $html = $candidate } else { break }
}

for ($pass = 0; $pass -lt 3; $pass++) {
  $beforeScore = Get-MojibakeScore $css
  if ($beforeScore -eq 0) { break }
  try {
    $candidate = [System.Text.Encoding]::UTF8.GetString($cp1252.GetBytes($css))
  } catch {
    break
  }
  $afterScore = Get-MojibakeScore $candidate
  if ($afterScore -lt $beforeScore) { $css = $candidate } else { break }
}

# Remove incomplete fragments left by previously truncated encoding.
# These patterns are expressed as Unicode escapes so this PowerShell file stays ASCII-safe.
$badPatterns = @(
  "\u00C3\u00A2\u00E2\u201A\u00AC\u00C2",
  "\u00C3\u00A2\u00E2\u201A\u00AC\u00C5",
  "\u00C3\u00A2\u00E2\u201A\u00AC",
  "\u00C3\u0192\u00C2",
  "\u00C2"
)
foreach ($pattern in $badPatterns) {
  $html = [regex]::Replace($html, $pattern, "")
  $css  = [regex]::Replace($css,  $pattern, "")
}

# Convert common decorative symbols to stable HTML entities.
$html = $html.Replace([string][char]0x2192, "&#8594;")
$html = $html.Replace([string][char]0x2197, "&#8599;")
$html = $html.Replace([string][char]0x2190, "&#8592;")
$html = $html.Replace([string][char]0x2022, "&#8226;")
$html = $html.Replace([string][char]0x00B7, "&#183;")
$html = $html.Replace([string][char]0x2713, "&#10003;")
$html = $html.Replace([string][char]0x2726, "&#10022;")
$html = $html.Replace([string][char]0x2733, "&#10035;")

# Guarantee explicit UTF-8 declaration.
if ($html -notmatch "(?i)<meta\s+charset\s*=") {
  $html = [regex]::Replace($html, "(?i)<head([^>]*)>", '<head$1>`r`n<meta charset="UTF-8">', 1)
} else {
  $html = [regex]::Replace($html, "(?i)<meta\s+charset\s*=\s*['""][^'""]*['""]\s*/?>", '<meta charset="UTF-8">', 1)
}

$polishMarker = "SPICES-OF-YASH-FRONTEND-PRECISION-POLISH-V1"

if ($css -notmatch $polishMarker) {
$polishCss = @'

/* SPICES-OF-YASH-FRONTEND-PRECISION-POLISH-V1 */
html { scroll-behavior: smooth; }
body { overflow-x: hidden; }

.hero-cinematic::after {
  pointer-events: none;
  background:
    radial-gradient(circle at 56% 42%, rgba(155,67,28,.12) 0%, rgba(35,16,8,.10) 38%, rgba(8,5,3,.42) 100%),
    linear-gradient(90deg, rgba(11,6,3,.72) 0%, rgba(17,8,4,.50) 48%, rgba(10,5,3,.62) 100%);
}
.hero-cinematic .hero-photo {
  filter: saturate(1.04) contrast(1.05) brightness(.90);
}

.site-header {
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
}
.site-header a,
.site-header button {
  -webkit-tap-highlight-color: transparent;
}
.site-header a:focus-visible,
.site-header button:focus-visible,
button:focus-visible,
a:focus-visible,
input:focus-visible,
select:focus-visible,
textarea:focus-visible {
  outline: 2px solid #e8b75a;
  outline-offset: 3px;
}

#product-grid > *,
.product-card,
.product-item {
  transition: transform .28s cubic-bezier(.2,.7,.2,1), box-shadow .28s ease, border-color .28s ease;
}
#product-grid > *:hover,
.product-card:hover,
.product-item:hover {
  transform: translateY(-4px);
}

#shop, #story, #promise, #contact, #wholesale {
  scroll-margin-top: 92px;
}

@media (max-width: 700px) {
  .hero-cinematic {
    min-height: calc(100svh - 70px);
  }
  .hero-cinematic h1 {
    text-wrap: balance;
  }
}

@media (prefers-reduced-motion: reduce) {
  html { scroll-behavior: auto; }
  *, *::before, *::after {
    animation-duration: .001ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: .001ms !important;
    scroll-behavior: auto !important;
  }
}
'@
  $css += $polishCss
}

$required = @('id="product-grid"','id="cart-open"','id="checkout-form"')
foreach ($marker in $required) {
  if ($html -notmatch [regex]::Escape($marker)) {
    Copy-Item -LiteralPath (Join-Path $backup "index.html") -Destination $indexPath -Force
    Copy-Item -LiteralPath (Join-Path $backup "styles.css") -Destination $cssPath -Force
    throw "Required storefront marker missing: $marker. Original frontend restored."
  }
}

[System.IO.File]::WriteAllText($indexPath, $html, $utf8)
[System.IO.File]::WriteAllText($cssPath, $css, $utf8)

$finalHtml = [System.IO.File]::ReadAllText($indexPath, $utf8)
$finalCss  = [System.IO.File]::ReadAllText($cssPath, $utf8)
$remaining = Get-MojibakeScore ($finalHtml + "`n" + $finalCss)

if ($remaining -gt 0) {
  Write-Host "WARNING: $remaining possible mojibake markers remain." -ForegroundColor Yellow
} else {
  Write-Host "Encoding cleanup: PASS" -ForegroundColor Green
}

Write-Host "UTF-8 meta charset: PASS" -ForegroundColor Green
Write-Host "Product grid marker: PASS" -ForegroundColor Green
Write-Host "Cart marker: PASS" -ForegroundColor Green
Write-Host "Checkout marker: PASS" -ForegroundColor Green
Write-Host ""
Write-Host "FRONTEND PRECISION POLISH APPLIED." -ForegroundColor Green
Write-Host "Changed ONLY: public/index.html and public/styles.css" -ForegroundColor Green
Write-Host "NOT changed: server.js, database, .env, package.json, app.js, APIs, auth, checkout logic." -ForegroundColor Green
Write-Host ""
Write-Host "Next: restart npm start if needed, then press Ctrl+F5 on http://localhost:3000" -ForegroundColor Yellow
