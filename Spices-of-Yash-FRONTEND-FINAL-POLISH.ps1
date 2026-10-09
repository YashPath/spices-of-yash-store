param(
  [string]$ProjectPath = "D:\Project\Spices-of-Yash-Complete-Local-Project (1)\spices-of-yash-store"
)
$ErrorActionPreference = 'Stop'
$public = Join-Path $ProjectPath 'public'
$indexPath = Join-Path $public 'index.html'
$cssPath = Join-Path $public 'styles.css'
$appPath = Join-Path $public 'app.js'
if (!(Test-Path $indexPath) -or !(Test-Path $cssPath) -or !(Test-Path $appPath)) { throw 'public/index.html, styles.css or app.js missing. Nothing changed.' }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $ProjectPath "frontend-final-polish-backup-$stamp"
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item $indexPath (Join-Path $backup 'index.html')
Copy-Item $cssPath (Join-Path $backup 'styles.css')
Copy-Item $appPath (Join-Path $backup 'app.js')
Write-Host "Backup created: $backup" -ForegroundColor Green

$html = Get-Content -LiteralPath $indexPath -Raw
$css = Get-Content -LiteralPath $cssPath -Raw

# Guarantee UTF-8 declaration before any other HTML changes.
if ($html -notmatch '(?i)<meta\s+charset\s*=') {
  $html = [regex]::Replace($html, '(?i)<head([^>]*)>', '<head$1>`r`n<meta charset="UTF-8">', 1)
} else {
  $html = [regex]::Replace($html, '(?i)<meta\s+charset\s*=\s*["''][^"'']*["'']\s*/?>', '<meta charset="UTF-8">', 1)
}

# Repair common UTF-8-as-Windows-1252 mojibake without relying on literal Unicode in the source file.
$replacements = @{
  'â†’'='&#8594;'; 'â†—'='&#8599;'; 'â†‘'='&#8593;'; 'â†“'='&#8595;';
  'âœ³'='&#10035;'; 'âœ¦'='&#10022;'; 'âœ“'='&#10003;'; 'âœ”'='&#10004;';
  'â€¢'='&#8226;'; 'â€“'='&#8211;'; 'â€”'='&#8212;'; 'â€œ'='&quot;'; 'â€'='&quot;';
  'â€™'='&#8217;'; 'â€˜'='&#8216;'; 'Â·'='&#183;'; 'Â©'='&copy;'; 'Â®'='&reg;';
  'Ã—'='&times;'; 'Ã©'='&eacute;'; 'Ã¨'='&egrave;'; 'Ã¼'='&uuml;';
}
foreach ($k in $replacements.Keys) { $html = $html.Replace($k, $replacements[$k]) }

# Remove accidental mojibake prefixes around the brand mark if present.
$html = $html -replace 'âœ³(?=\s*Spices of Yash)', '&#10035; '
$html = $html -replace 'âœ³', '&#10035;'

# Ensure the hero uses ASCII/HTML-entity controls rather than raw Unicode arrows.
$html = $html.Replace('Explore the pantry <span>↗</span>', 'Explore the pantry <span aria-hidden="true">&#8599;</span>')
$html = $html.Replace('Our story <span>→</span>', 'Our story <span aria-hidden="true">&#8594;</span>')
$html = $html.Replace('<span class="note-icon">✳</span>', '<span class="note-icon" aria-hidden="true">&#10035;</span>')

# Premium final frontend layer. Backend, database and payment code are untouched.
$polish = @'

/* SPICES OF YASH — FINAL FRONTEND POLISH */
:root{--syo-ink:#182014;--syo-deep:#10160d;--syo-cream:#f7f1e5;--syo-paper:#fffdf8;--syo-gold:#d9a05e;--syo-rust:#bd6845;--syo-muted:#6f7569}
html{scroll-behavior:smooth}
body{background:var(--syo-paper);color:var(--syo-ink);overflow-x:hidden}
button,a{ -webkit-tap-highlight-color:transparent }

/* Cleaner header */
.site-header{position:relative;z-index:50;backdrop-filter:blur(10px);-webkit-backdrop-filter:blur(10px);transition:background .25s ease,border-color .25s ease}
.site-header .brand{transition:transform .2s ease}.site-header .brand:hover{transform:translateY(-1px)}
.site-header .main-nav a{position:relative}.site-header .main-nav a:after{content:"";position:absolute;left:0;right:0;bottom:-7px;height:1px;background:#e8b77e;transform:scaleX(0);transform-origin:center;transition:transform .2s ease}.site-header .main-nav a:hover:after{transform:scaleX(1)}
.site-header .cart-btn{transition:all .2s ease}.site-header .cart-btn:hover{background:#fff;color:#182014;transform:translateY(-1px)}

/* Hero */
.hero-cinematic{min-height:calc(100svh - 122px);padding:76px 6%;background:var(--syo-deep);box-shadow:inset 0 -80px 120px rgba(0,0,0,.18)}
.hero-cinematic .hero-photo{filter:saturate(.9) contrast(1.05);will-change:transform}
.hero-cinematic:after{content:"";position:absolute;inset:0;pointer-events:none;z-index:0;background:radial-gradient(circle at 50% 42%,transparent 0 28%,rgba(5,8,4,.18) 72%,rgba(5,8,4,.45) 100%)}
.hero-cinematic .hero-copy{max-width:900px}
.hero-cinematic h1{text-wrap:balance;text-shadow:0 3px 28px rgba(0,0,0,.25)}
.hero-cinematic .hero-description{text-wrap:balance}
.hero-cinematic .hero-ctas .btn-light{border:1px solid rgba(255,255,255,.55)}
.hero-cinematic .hero-story-link{display:inline-flex;align-items:center;gap:8px}
.hero-cinematic .hero-story-link span,.hero-cinematic .btn-light span{font-size:1.1em;line-height:1}
.hero-cinematic .hero-note{gap:11px}
.hero-cinematic .note-icon{display:grid;place-items:center;width:28px;height:28px;border:1px solid rgba(240,194,142,.45);border-radius:50%;font-size:12px}

/* Trust strip */
.trust-strip,.promise-strip{border-top:1px solid #18201414;border-bottom:1px solid #18201410;background:#fffdf8}
.trust-strip>*{transition:transform .2s ease}.trust-strip>*:hover{transform:translateY(-2px)}

/* Product area */
#shop{scroll-margin-top:30px}
#product-grid{align-items:stretch}
#product-grid>*{transition:transform .28s ease,box-shadow .28s ease,border-color .28s ease}
#product-grid>*:hover{transform:translateY(-6px);box-shadow:0 18px 45px rgba(24,32,20,.10)}

/* Generic buttons / forms */
.btn,.button,.primary-btn{transition:transform .2s ease,box-shadow .2s ease,background .2s ease,border-color .2s ease}
.btn:active,.button:active,.primary-btn:active{transform:translateY(1px) scale(.99)}
input,select,textarea{outline:none;transition:border-color .2s ease,box-shadow .2s ease}
input:focus,select:focus,textarea:focus{border-color:#c98b54!important;box-shadow:0 0 0 3px rgba(201,139,84,.13)}

/* Cart drawer */
.cart-drawer,.cart-panel{box-shadow:-24px 0 70px rgba(0,0,0,.20)}

/* Mobile */
@media(max-width:850px){
 .hero-cinematic{min-height:calc(100svh - 104px);padding:56px 6% 48px}
 .hero-cinematic .hero-photo{background-position:center center}
 .hero-cinematic h1{font-size:clamp(38px,10vw,50px)}
 .hero-cinematic .hero-description{max-width:560px}
}
@media(max-width:650px){
 .hero-cinematic{padding:48px 7% 42px}
 .hero-cinematic .hero-ctas{display:flex;flex-direction:column;align-items:center}
 .hero-cinematic .hero-ctas .btn-light{width:min(100%,310px);justify-content:center}
 .hero-cinematic .hero-story-link{padding:9px 0}
 .hero-cinematic .hero-note{margin-top:24px}
 .hero-cinematic:after{background:radial-gradient(circle at 50% 42%,transparent 0 22%,rgba(5,8,4,.25) 70%,rgba(5,8,4,.52) 100%)}
}
@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}.site-header,.site-header .brand,.site-header .cart-btn,.site-header .main-nav a:after,#product-grid>*{transition:none!important}.hero-cinematic .hero-photo{animation:none!important}}
'@
if ($css -notmatch 'FINAL FRONTEND POLISH') { $css += $polish }

# Save explicitly as UTF-8 (without depending on console encoding).
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($indexPath,$html,$utf8)
[System.IO.File]::WriteAllText($cssPath,$css,$utf8)

# Validate frontend JS syntax only; no backend tests are run in this phase.
& node --check $appPath
if ($LASTEXITCODE -ne 0) {
  Copy-Item (Join-Path $backup 'index.html') $indexPath -Force
  Copy-Item (Join-Path $backup 'styles.css') $cssPath -Force
  Copy-Item (Join-Path $backup 'app.js') $appPath -Force
  throw 'Frontend JS syntax check failed. Original frontend restored.'
}
Write-Host ''
Write-Host 'FINAL FRONTEND POLISH APPLIED SUCCESSFULLY.' -ForegroundColor Green
Write-Host 'Fixed: UTF-8/garbled characters, hero controls, header polish, CTA polish, product hover, forms, cart visual polish, mobile layout.' -ForegroundColor Green
Write-Host 'Backend, database, .env, payments and server.js were not changed.' -ForegroundColor Green
Write-Host "Rollback backup: $backup" -ForegroundColor Cyan
Write-Host 'Now refresh localhost with Ctrl+F5 and test the storefront.' -ForegroundColor Yellow
