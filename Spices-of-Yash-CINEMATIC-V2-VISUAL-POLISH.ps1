param([string]$ProjectPath='D:\Project\Spices-of-Yash-Complete-Local-Project (1)\spices-of-yash-store')
$ErrorActionPreference='Stop'
$public=Join-Path $ProjectPath 'public'; $index=Join-Path $public 'index.html'; $css=Join-Path $public 'styles.css'
if(!(Test-Path $index) -or !(Test-Path $css)){throw 'public/index.html or public/styles.css not found.'}
$html=[IO.File]::ReadAllText($index); $style=[IO.File]::ReadAllText($css)
foreach($m in @('id="product-grid"','id="checkout-form"','id="cart-open"')){if($html -notmatch [regex]::Escape($m)){throw "Safety check failed: $m not found."}}
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'; $backup=Join-Path $ProjectPath "frontend-v2-backup-$stamp"; New-Item $backup -ItemType Directory -Force|Out-Null
Copy-Item $index (Join-Path $backup 'index.html'); Copy-Item $css (Join-Path $backup 'styles.css')
if($html -notmatch '(?i)<meta\s+charset\s*='){ $html=[regex]::Replace($html,'(?i)<head([^>]*)>','<head$1>`r`n<meta charset="UTF-8">',1) }
$html=$html.Replace([string][char]0xFFFD,'')
if($html -notmatch 'sy-v2-particles'){
 $layer='<div class="sy-v2-particles" aria-hidden="true"><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i></div><div class="sy-v2-light-sweep" aria-hidden="true"></div><div class="sy-v2-hero-edge" aria-hidden="true"></div>'
 $html=[regex]::Replace($html,'(?s)(<section\s+class="[^\"]*hero[^\"]*"[^>]*>)','$1'+$layer,1)
}
if($html -notmatch 'sy-v2-hero-card'){
 $card='<div class="sy-v2-hero-card" aria-hidden="true"><span>01</span><strong>Ground with care</strong><small>Whole spices / Ground spices / Signature blends</small><b></b></div>'
 $html=[regex]::Replace($html,'(?s)(</section>)',$card+'$1',1)
}
if($html -notmatch 'sy-v2-pantry-intro'){
 $intro='<section class="sy-v2-pantry-intro" aria-label="The Spice Pantry"><div class="sy-v2-kicker"><span></span> FROM THE SPICE PANTRY <span></span></div><h2>Colour, aroma,<br><em>character.</em></h2><p>Every spice has a place at the table. Explore everyday essentials selected for rich flavour, honest quality and Indian kitchens.</p></section><div class="sy-v2-marquee" aria-hidden="true"><span>WHOLE SPICES</span><b>*</b><span>GROUND WITH CARE</span><b>*</b><span>INDIAN FLAVOUR</span><b>*</b><span>PACKED FRESH</span></div>'
 $html=$html.Replace('<div id="product-grid"',$intro+"`r`n<div id="product-grid"")
}
$patch=@'

/* SPICES OF YASH - CINEMATIC V2 VISUAL POLISH */
:root{--sy-ink:#160d08;--sy-cream:#fff8ea;--sy-gold:#e8b75a;--sy-red:#b3361f}
html{scroll-behavior:smooth}body{overflow-x:hidden}
.hero-cinematic{background:var(--sy-ink)!important;overflow:hidden!important;min-height:calc(100svh - 80px)!important}
.hero-cinematic .hero-photo{filter:saturate(1.1) contrast(1.08) brightness(.8)!important;transform:scale(1.04)!important;animation:syKen 18s ease-in-out infinite alternate!important}
@keyframes syKen{from{transform:scale(1.04) translate(-.4%,0)}to{transform:scale(1.11) translate(.8%,-.8%)}}
.hero-cinematic:before{content:"";position:absolute;inset:0;z-index:0;pointer-events:none;background:linear-gradient(90deg,rgba(22,13,8,.92),rgba(22,13,8,.62) 38%,rgba(22,13,8,.25) 72%,rgba(22,13,8,.64)),linear-gradient(180deg,rgba(10,5,2,.45),transparent 34%,rgba(10,5,2,.68)}
.hero-cinematic .hero-copy{position:relative;z-index:4;max-width:900px!important;text-align:left!important}
.hero-cinematic h1{letter-spacing:-.045em!important;text-shadow:0 5px 28px rgba(0,0,0,.3)}
.hero-cinematic .hero-description{max-width:650px!important;color:rgba(255,248,234,.86)!important}
.hero-cinematic .btn-light{box-shadow:0 14px 42px rgba(0,0,0,.24);transition:transform .35s ease,box-shadow .35s ease!important}
.hero-cinematic .btn-light:hover{transform:translateY(-3px);box-shadow:0 20px 55px rgba(0,0,0,.34)}
.sy-v2-particles{position:absolute;inset:0;z-index:3;pointer-events:none;overflow:hidden}.sy-v2-particles i{position:absolute;width:3px;height:3px;border-radius:50%;background:rgba(232,183,90,.75);box-shadow:0 0 12px rgba(232,183,90,.5);animation:syDust 7s ease-in-out infinite}.sy-v2-particles i:nth-child(1){left:9%;top:72%;animation-delay:-1s}.sy-v2-particles i:nth-child(2){left:19%;top:34%;animation-delay:-4s}.sy-v2-particles i:nth-child(3){left:31%;top:79%;animation-delay:-2s}.sy-v2-particles i:nth-child(4){left:47%;top:25%;animation-delay:-5s}.sy-v2-particles i:nth-child(5){left:58%;top:68%;animation-delay:-3s}.sy-v2-particles i:nth-child(6){left:69%;top:39%;animation-delay:-6s}.sy-v2-particles i:nth-child(7){left:78%;top:76%;animation-delay:-2s}.sy-v2-particles i:nth-child(8){left:86%;top:28%;animation-delay:-4s}.sy-v2-particles i:nth-child(9){left:92%;top:63%;animation-delay:-2s}.sy-v2-particles i:nth-child(10){left:38%;top:53%;animation-delay:-5s}
@keyframes syDust{0%,100%{opacity:.12;transform:translate(0,10px) scale(.7)}50%{opacity:.9;transform:translate(18px,-26px) scale(1.15)}}
.sy-v2-light-sweep{position:absolute;inset:-20%;z-index:2;pointer-events:none;background:linear-gradient(108deg,transparent 36%,rgba(232,183,90,.06) 47%,rgba(255,248,234,.1) 50%,transparent 61%);transform:translateX(-55%);animation:sySweep 10s ease-in-out infinite}@keyframes sySweep{0%,25%{transform:translateX(-55%);opacity:0}38%,62%{opacity:1}78%,100%{transform:translateX(55%);opacity:0}}
.sy-v2-hero-edge{position:absolute;inset:0;z-index:2;pointer-events:none;border:1px solid rgba(232,183,90,.1);box-shadow:inset 0 0 150px rgba(0,0,0,.4)}
.sy-v2-hero-card{position:absolute;right:7%;bottom:14%;z-index:5;width:235px;padding:24px 22px 20px;color:var(--sy-cream);background:rgba(22,13,8,.56);border:1px solid rgba(232,183,90,.28);backdrop-filter:blur(12px);box-shadow:0 24px 70px rgba(0,0,0,.3);animation:syCard 1.1s .7s both}.sy-v2-hero-card span{display:block;color:var(--sy-gold);font-size:11px;letter-spacing:.24em;margin-bottom:18px}.sy-v2-hero-card strong{display:block;font:500 27px/1 Georgia,serif}.sy-v2-hero-card small{display:block;margin-top:15px;color:rgba(255,248,234,.68);font-size:11px;line-height:1.55}.sy-v2-hero-card b{display:block;width:38px;height:1px;margin-top:20px;background:var(--sy-gold)}@keyframes syCard{from{opacity:0;transform:translateY(24px)}to{opacity:1;transform:none}}
.sy-v2-pantry-intro{padding:120px 8% 48px;text-align:center;background:radial-gradient(circle at 50% 0,rgba(232,183,90,.13),transparent 34%),var(--sy-cream)}.sy-v2-kicker{display:flex;align-items:center;justify-content:center;gap:14px;color:#9b542f;font-size:11px;font-weight:700;letter-spacing:.25em}.sy-v2-kicker span{width:38px;height:1px;background:#c88755}.sy-v2-pantry-intro h2{margin:20px auto 18px;max-width:850px;color:#241b14;font:400 clamp(52px,7vw,94px)/.94 Georgia,serif;letter-spacing:-.055em}.sy-v2-pantry-intro h2 em{color:#ad592e}.sy-v2-pantry-intro p{max-width:590px;margin:auto;color:#776858;font-size:16px;line-height:1.75}.sy-v2-marquee{display:flex;justify-content:center;align-items:center;gap:20px;padding:18px 5%;overflow:hidden;background:#21130c;color:#f1d39a;font-size:10px;font-weight:700;letter-spacing:.24em}.sy-v2-marquee b{color:var(--sy-red)}
#product-grid> *{transition:transform .38s cubic-bezier(.2,.7,.2,1),box-shadow .38s ease!important}#product-grid> *:hover{transform:translateY(-8px)!important;box-shadow:0 22px 48px rgba(74,42,22,.13)!important}#product-grid img{transition:transform .7s cubic-bezier(.2,.7,.2,1),filter .5s ease!important}#product-grid> *:hover img{transform:scale(1.045);filter:saturate(1.06)}
@media(max-width:700px){.hero-cinematic{min-height:calc(100svh - 68px)!important;padding:78px 7% 110px!important;align-items:flex-end!important}.hero-cinematic .hero-copy{text-align:left!important}.hero-cinematic h1{font-size:clamp(43px,12vw,64px)!important}.sy-v2-hero-card{display:none}.sy-v2-pantry-intro{padding:84px 7% 36px}.sy-v2-pantry-intro h2{font-size:clamp(48px,15vw,68px)}.sy-v2-marquee{gap:12px;white-space:nowrap;font-size:8px}}
@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}.sy-v2-light-sweep,.sy-v2-particles i,.sy-v2-hero-card,.hero-cinematic .hero-photo{animation:none!important}#product-grid> *,#product-grid img{transition:none!important}}
'@
if($style -notmatch 'CINEMATIC V2 VISUAL POLISH'){$style+=$patch}
$utf8=New-Object System.Text.UTF8Encoding($false); [IO.File]::WriteAllText($index,$html,$utf8); [IO.File]::WriteAllText($css,$style,$utf8)
Write-Host '';Write-Host 'SPICES OF YASH CINEMATIC V2 APPLIED SUCCESSFULLY.' -ForegroundColor Green;Write-Host 'Visible V2 changes: hero depth, spice dust, light sweep, floating editorial card, pantry transition, marquee and product hover polish.' -ForegroundColor Green;Write-Host 'Only public/index.html and public/styles.css were changed.' -ForegroundColor Green;Write-Host ('Backup: '+$backup) -ForegroundColor Cyan;Write-Host 'Hard refresh localhost with Ctrl+F5.' -ForegroundColor Yellow
