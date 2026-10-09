param(
  [string]$ProjectPath = "D:\Project\Spices-of-Yash-Complete-Local-Project (1)\spices-of-yash-store"
)

$ErrorActionPreference = "Stop"

$indexPath = Join-Path $ProjectPath "public\index.html"
$cssPath   = Join-Path $ProjectPath "public\styles.css"
$appPath   = Join-Path $ProjectPath "public\app.js"

if (!(Test-Path $indexPath)) { throw "public\index.html was not found." }
if (!(Test-Path $cssPath))   { throw "public\styles.css was not found." }

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = Join-Path $ProjectPath "ui-polish-backup-$stamp"
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item $indexPath (Join-Path $backup "index.html")
Copy-Item $cssPath   (Join-Path $backup "styles.css")

Write-Host "Backup created: $backup" -ForegroundColor Green

$html = Get-Content -LiteralPath $indexPath -Raw
$css  = Get-Content -LiteralPath $cssPath -Raw

# Force UTF-8 declaration.
if ($html -notmatch '(?i)<meta\s+charset=') {
  $html = $html -replace '(?i)(<head[^>]*>)', '$1`r`n<meta charset="UTF-8">'
} else {
  $html = [regex]::Replace($html, '(?i)<meta\s+charset\s*=\s*["''][^"'']*["'']\s*/?>', '<meta charset="UTF-8">', 1)
}

# Replace common mojibake / broken symbol output with safe ASCII.
$replacements = @{
  'â†'' = '->'
  'â†’' = '->'
  'â†“' = 'v'
  'â†‘' = '^'
  'âœ“' = '[OK]'
  'âœ”' = '[OK]'
  'âœ•' = '*'
  'âœ³' = '*'
  'â€¢' = '*'
  'â€”' = '-'
  'â€“' = '-'
  'â€™' = "'"
  'â€œ' = '"'
  'â€' = '"'
  'â€¦' = '...'
  'Â·'  = '*'
  'Â©'  = '(c)'
  'Â®'  = '(R)'
}

foreach ($bad in $replacements.Keys) {
  $html = $html.Replace($bad, $replacements[$bad])
}

# Replace a few known visual arrow/star entities with safe ASCII text.
$html = $html.Replace('&#8594;', '->')
$html = $html.Replace('&#x2192;', '->')
$html = $html.Replace('&#10003;', '[OK]')
$html = $html.Replace('&#10022;', '*')

# Remove accidental replacement characters if any remain.
$html = $html.Replace([char]0xFFFD, '')

$polishCss = @'

/* Spices of Yash - final frontend polish */
html { scroll-behavior: smooth; }
body { overflow-x: hidden; }
img { max-width: 100%; }

.site-header {
  position: sticky;
  top: 0;
  z-index: 100;
  backdrop-filter: blur(14px);
  -webkit-backdrop-filter: blur(14px);
}

.hero-cinematic {
  min-height: calc(100svh - 80px);
  isolation: isolate;
}

.hero-cinematic .hero-copy {
  max-width: 860px;
  text-align: center;
}

.hero-cinematic h1 {
  text-wrap: balance;
}

.hero-cinematic .hero-description {
  text-wrap: balance;
}

.hero-cinematic .hero-ctas .btn,
.hero-cinematic .hero-story-link {
  min-height: 46px;
}

.hero-cinematic .hero-photo {
  filter: saturate(.92) contrast(1.03);
}

.hero-cinematic:after {
  content: "";
  position: absolute;
  inset: 0;
  pointer-events: none;
  z-index: -1;
  background:
    radial-gradient(circle at 50% 45%, transparent 0%, rgba(0,0,0,.08) 55%, rgba(0,0,0,.34) 100%);
}

#shop, #story, #promise {
  scroll-margin-top: 90px;
}

.product-card,
.product-item,
.card {
  transition: transform .25s ease, box-shadow .25s ease, border-color .25s ease;
}

.product-card:hover,
.product-item:hover,
.card:hover {
  transform: translateY(-5px);
}

button,
.btn,
a {
  -webkit-tap-highlight-color: transparent;
}

button:focus-visible,
a:focus-visible,
input:focus-visible,
select:focus-visible,
textarea:focus-visible {
  outline: 2px solid #d79b5f;
  outline-offset: 3px;
}

@media (max-width: 700px) {
  .hero-cinematic {
    min-height: calc(100svh - 70px);
  }

  .hero-cinematic h1 {
    font-size: clamp(38px, 11vw, 52px);
  }

  .hero-cinematic .hero-ctas {
    width: 100%;
  }

  .hero-cinematic .hero-ctas > * {
    width: min(100%, 320px);
    justify-content: center;
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

if ($css -notmatch 'final frontend polish') {
  Add-Content -LiteralPath $cssPath -Value $polishCss -Encoding UTF8
}

Set-Content -LiteralPath $indexPath -Value $html -Encoding UTF8

# Safe source check only; no backend tests.
if (Test-Path $appPath) {
  & node --check $appPath
  if ($LASTEXITCODE -ne 0) {
    Copy-Item (Join-Path $backup "index.html") $indexPath -Force
    Copy-Item (Join-Path $backup "styles.css") $cssPath -Force
    throw "Frontend app.js syntax check failed. Original frontend restored."
  }
}

Write-Host ""
Write-Host "Frontend polish applied successfully." -ForegroundColor Green
Write-Host "Encoding cleanup applied." -ForegroundColor Green
Write-Host "Hero, spacing, focus states, product hover and mobile polish applied." -ForegroundColor Green
Write-Host "Backend, database, .env and server.js were not changed." -ForegroundColor Green
Write-Host "Backup: $backup" -ForegroundColor Cyan
