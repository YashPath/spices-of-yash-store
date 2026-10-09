$ErrorActionPreference="Stop"
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$index=Join-Path $root "public\index.html"
$css=Join-Path $root "public\styles.css"
if(!(Test-Path $index)){throw "public\index.html not found."}
if(!(Test-Path $css)){throw "public\styles.css not found."}
$html=Get-Content $index -Raw
$styles=Get-Content $css -Raw
foreach($m in @('id="product-grid"','id="cart-open"','id="checkout-form"','id="home"','sy-v3-hero','sy-v5-3d-interaction','sy-v7-ticker')){
 if($html.IndexOf($m,[StringComparison]::OrdinalIgnoreCase)-lt 0){throw "Safety check failed: $m"}
}
$stamp=Get-Date -Format "yyyyMMdd-HHmmss"
$backup=Join-Path $root "landing-v8-backup-$stamp"
New-Item -ItemType Directory -Path $backup -Force|Out-Null
Copy-Item $index (Join-Path $backup "index.html")
Copy-Item $css (Join-Path $backup "styles.css")

$e2=[string][char]0x00E2
$dag=[string][char]0x2020
$qlo=[string][char]0x201A
$emd=[string][char]0x2014
$sq=[string][char]0x2019
$b9=[string][char]0x00B9
$euro=[string][char]0x20AC
$c2=[string][char]0x00C2
$badR=$e2+$qlo+$b9
$badA1=$e2+$dag+$sq
$badA2=$e2+$dag+$emd
$badB=$e2+$euro+[string][char]0x00A2
$html=$html.Replace($badR,'&#8377;').Replace($badA1,'&rarr;').Replace($badA2,'&rarr;').Replace($badB,'&bull;')
$html=$html.Replace($c2+' ',' ').Replace($c2+'.','.').Replace($c2+':',':')

$pat='(?s)(<a[^>]*class="[^"]*sy-v3-primary[^"]*"[^>]*>).*?(</a>)'
if([regex]::Matches($html,$pat).Count -eq 1){$html=[regex]::Replace($html,$pat,'$1Shop the pantry <span aria-hidden="true">&rarr;</span>$2',1)}
$pat2='(?s)(<a[^>]*class="[^"]*sy-v3-story[^"]*"[^>]*>).*?(</a>)'
if([regex]::Matches($html,$pat2).Count -eq 1){$html=[regex]::Replace($html,$pat2,'$1Our story <span aria-hidden="true">&rarr;</span>$2',1)}

$price='(?s)(<[^>]*class="[^"]*(?:price|sy-v3-price)[^"]*"[^>]*>).*?(</[^>]+>)'
if([regex]::Matches($html,$price).Count -ge 1){$html=[regex]::Replace($html,$price,'$1&#8377;349$2',1)}
else{$html=$html.Replace($badR+'349','&#8377;349')}

$cssBlock=@'

/* SPICES OF YASH - V8 FINAL ENCODING + HERO POLISH */
.sy-v3-hero{isolation:isolate;}
.sy-v3-inner{padding-top:88px;}
.sy-v3-primary,.sy-v3-story{white-space:nowrap;}
.sy-v3-card{z-index:3;}
@media (max-height:780px) and (min-width:901px){.sy-v3-inner{padding-top:68px;}}
@media (max-width:900px){.sy-v3-inner{padding-top:72px;}}
'@
if($styles -notmatch 'V8 FINAL ENCODING'){$styles+=$cssBlock}

try{
 Set-Content $index $html -Encoding UTF8
 Set-Content $css $styles -Encoding UTF8
 $check=Get-Content $index -Raw
 foreach($m in @('id="product-grid"','id="cart-open"','id="checkout-form"','id="home"','sy-v3-hero','sy-v5-3d-interaction','sy-v7-ticker')){
  if($check.IndexOf($m,[StringComparison]::OrdinalIgnoreCase)-lt 0){throw "Post-write validation failed: $m"}
 }
 Write-Host "SUCCESS: Landing V8 final encoding cleanup applied." -ForegroundColor Green
 Write-Host "Backup: $backup" -ForegroundColor Cyan
 Write-Host "Changed only: public/index.html and public/styles.css" -ForegroundColor Yellow
}catch{
 Copy-Item (Join-Path $backup "index.html") $index -Force
 Copy-Item (Join-Path $backup "styles.css") $css -Force
 Write-Host "RESTORED: V8 changes were not kept." -ForegroundColor Green
 throw
}
