$ErrorActionPreference="Stop"
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$index=Join-Path $root "public\index.html"
$css=Join-Path $root "public\styles.css"
if(!(Test-Path $index)){throw "public\index.html not found."}
if(!(Test-Path $css)){throw "public\styles.css not found."}
$html=Get-Content $index -Raw
$styles=Get-Content $css -Raw

foreach($m in @('id="product-grid"','id="cart-open"','id="checkout-form"','id="home"','sy-v3-hero','sy-v5-3d-interaction')){
 if($html.IndexOf($m,[StringComparison]::OrdinalIgnoreCase)-lt 0){throw "Safety check failed: $m"}
}

$stamp=Get-Date -Format "yyyyMMdd-HHmmss"
$backup=Join-Path $root "landing-v9-backup-$stamp"
New-Item -ItemType Directory -Path $backup -Force|Out-Null
Copy-Item $index (Join-Path $backup "index.html")
Copy-Item $css (Join-Path $backup "styles.css")

# Replace only the visible contents of the search button.
$searchPattern='(?s)(<button[^>]*id="search-toggle"[^>]*>).*?(</button>)'
if([regex]::Matches($html,$searchPattern).Count -eq 1){
  $html=[regex]::Replace($html,$searchPattern,'$1<span class="sy-v9-search-glyph" aria-hidden="true"></span>$2',1)
}

$cssBlock=@'

/* =========================================================
   SPICES OF YASH - V9 FINAL HEADER ICON
   ========================================================= */

/* Draw the search icon with CSS so it cannot suffer from
   character-encoding/mojibake problems. The original button
   and its JavaScript id remain unchanged. */
#search-toggle{
  position:relative;
  width:42px;
  height:42px;
  min-width:42px;
  display:inline-grid !important;
  place-items:center;
  font-size:0 !important;
  line-height:0;
}
#search-toggle .sy-v9-search-glyph{
  position:relative;
  width:15px;
  height:15px;
  display:block;
  border:1.7px solid currentColor;
  border-radius:50%;
  opacity:.92;
}
#search-toggle .sy-v9-search-glyph:after{
  content:"";
  position:absolute;
  width:7px;
  height:1.7px;
  background:currentColor;
  border-radius:2px;
  right:-5px;
  bottom:-3px;
  transform:rotate(45deg);
  transform-origin:left center;
}
#search-toggle:hover .sy-v9-search-glyph{
  transform:scale(1.06);
}
@media (prefers-reduced-motion:reduce){
  #search-toggle .sy-v9-search-glyph{transition:none;}
}
'@

if($styles -notmatch 'V9 FINAL HEADER ICON'){$styles+=$cssBlock}

try{
 Set-Content $index $html -Encoding UTF8
 Set-Content $css $styles -Encoding UTF8
 $check=Get-Content $index -Raw
 foreach($m in @('id="product-grid"','id="cart-open"','id="checkout-form"','id="home"','sy-v3-hero')){
  if($check.IndexOf($m,[StringComparison]::OrdinalIgnoreCase)-lt 0){throw "Post-write validation failed: $m"}
 }
 if($check -notmatch 'sy-v9-search-glyph'){throw "Search icon patch was not written."}
 Write-Host ""
 Write-Host "SUCCESS: Landing V9 header icon cleanup applied." -ForegroundColor Green
 Write-Host "Backup: $backup" -ForegroundColor Cyan
 Write-Host "Changed only: public/index.html and public/styles.css" -ForegroundColor Yellow
 Write-Host "Backend/database/.env/app.js/admin/cart/checkout were NOT modified." -ForegroundColor Green
}catch{
 Copy-Item (Join-Path $backup "index.html") $index -Force
 Copy-Item (Join-Path $backup "styles.css") $css -Force
 Write-Host "RESTORED: V9 changes were not kept." -ForegroundColor Green
 throw
}
