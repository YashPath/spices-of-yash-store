param(
  [string]$ProjectPath = "D:\Project\Spices-of-Yash-Complete-Local-Project (1)\spices-of-yash-store"
)

$ErrorActionPreference = "Stop"

$indexPath = Join-Path $ProjectPath "public\index.html"
$cssPath = Join-Path $ProjectPath "public\styles.css"

if (!(Test-Path -LiteralPath $indexPath)) { throw "public\index.html not found." }
if (!(Test-Path -LiteralPath $cssPath)) { throw "public\styles.css not found." }

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = Join-Path $ProjectPath ("ui-encoding-fix-backup-" + $stamp)
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $indexPath -Destination (Join-Path $backup "index.html") -Force
Copy-Item -LiteralPath $cssPath -Destination (Join-Path $backup "styles.css") -Force

$html = Get-Content -LiteralPath $indexPath -Raw
$css = Get-Content -LiteralPath $cssPath -Raw

# Ensure UTF-8 meta declaration.
if ($html -notmatch '(?i)<meta\s+charset=') {
  $html = $html -replace '(?i)(<head[^>]*>)', '$1`r`n<meta charset="UTF-8">'
} else {
  $html = [regex]::Replace($html, '(?i)<meta\s+charset\s*=\s*["''][^"'']*["'']\s*/?>', '<meta charset="UTF-8">', 1)
}

# Remove common UTF-8 mojibake sequences without putting non-ASCII
# characters inside this PowerShell source file.
$patterns = @(
  '\u00E2[\u0080-\u00BF]+',
  '\u00C3[\u0080-\u00BF]+',
  '\u00C2[\u0080-\u00BF]+',
  '\u00EF\u00BF\u00BD'
)

foreach ($pattern in $patterns) {
  $html = [regex]::Replace($html, $pattern, '')
}

# Replace common numeric entities with safe ASCII.
$html = $html.Replace('&#8594;', '->')
$html = $html.Replace('&#8592;', '<-')
$html = $html.Replace('&#10003;', '[OK]')
$html = $html.Replace('&#10022;', '*')
$html = $html.Replace('&#8226;', '*')
$html = $html.Replace('&#8211;', '-')
$html = $html.Replace('&#8212;', '-')
$html = $html.Replace('&#8230;', '...')

# Final polish, deliberately ASCII-only.
$cssPatch = @'
/* Spices of Yash - frontend encoding and polish patch */
html { scroll-behavior: smooth; }
body { overflow-x: hidden; }
img { max-width: 100%; }

.hero-cinematic {
  min-height: calc(100svh - 80px);
  isolation: isolate;
}

.hero-cinematic .hero-copy {
  max-width: 860px;
  text-align: center;
}

.hero-cinematic h1,
.hero-cinematic .hero-description {
  text-wrap: balance;
}

.hero-cinematic .hero-photo {
  filter: saturate(.92) contrast(1.04);
}

.hero-cinematic:after {
  content: "";
  position: absolute;
  inset: 0;
  pointer-events: none;
  z-index: -1;
  background: radial-gradient(circle at 50% 45%, transparent 0%, rgba(0,0,0,.08) 55%, rgba(0,0,0,.34) 100%);
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
}

@media (prefers-reduced-motion: reduce) {
  html { scroll-behavior: auto; }
  *, *::before, *::after {
    animation-duration: .001ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: .001ms !important;
  }
}
'@

if ($css -notmatch 'frontend encoding and polish patch') {
  Add-Content -LiteralPath $cssPath -Value $cssPatch -Encoding UTF8
}

Set-Content -LiteralPath $indexPath -Value $html -Encoding UTF8

Write-Host ""
Write-Host "Frontend encoding fix and polish applied successfully." -ForegroundColor Green
Write-Host "Backup created: $backup" -ForegroundColor Cyan
Write-Host "Backend, database, .env and server.js were not changed." -ForegroundColor Green
