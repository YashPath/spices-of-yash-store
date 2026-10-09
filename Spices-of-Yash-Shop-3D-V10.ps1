$ErrorActionPreference="Stop"
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$index=Join-Path $root "public\index.html"
$css=Join-Path $root "public\styles.css"
if(!(Test-Path $index)){throw "public\index.html not found."}
if(!(Test-Path $css)){throw "public\styles.css not found."}

$html=Get-Content $index -Raw
$styles=Get-Content $css -Raw

# Safety: preserve the existing commerce hooks.
foreach($m in @('id="product-grid"','id="cart-open"','id="checkout-form"','id="home"')){
  if($html.IndexOf($m,[StringComparison]::OrdinalIgnoreCase)-lt 0){
    throw "Safety check failed: $m"
  }
}

$stamp=Get-Date -Format "yyyyMMdd-HHmmss"
$backup=Join-Path $root "shop-3d-v10-backup-$stamp"
New-Item -ItemType Directory -Path $backup -Force|Out-Null
Copy-Item $index (Join-Path $backup "index.html")
Copy-Item $css (Join-Path $backup "styles.css")

$cssBlock=@'

/* =========================================================
   SPICES OF YASH — V10 PREMIUM PRODUCT SHOWCASE
   3D depth, pointer tilt, image lift, premium hover lighting.
   Commerce markup and app.js remain untouched.
   ========================================================= */

#product-grid{
  perspective:1400px;
  perspective-origin:50% 20%;
}

#product-grid > .sy-v10-card,
#product-grid .sy-v10-card{
  --rx:0deg;
  --ry:0deg;
  --mx:50%;
  --my:50%;
  --lift:0px;
  position:relative;
  transform-style:preserve-3d;
  transform:translate3d(0,var(--lift),0) rotateX(var(--rx)) rotateY(var(--ry));
  transition:transform .55s cubic-bezier(.2,.75,.2,1),box-shadow .55s ease,filter .4s ease;
  will-change:transform;
  isolation:isolate;
  overflow:hidden;
}

#product-grid .sy-v10-card::before{
  content:"";
  position:absolute;
  inset:0;
  z-index:20;
  pointer-events:none;
  opacity:0;
  background:
    radial-gradient(circle at var(--mx) var(--my),
      rgba(255,218,120,.24) 0,
      rgba(255,218,120,.08) 14%,
      transparent 42%);
  mix-blend-mode:screen;
  transition:opacity .35s ease;
}

#product-grid .sy-v10-card::after{
  content:"";
  position:absolute;
  left:8%;
  right:8%;
  bottom:-20px;
  height:34px;
  z-index:-1;
  pointer-events:none;
  border-radius:50%;
  background:rgba(0,0,0,.42);
  filter:blur(18px);
  opacity:.42;
  transform:translateZ(-30px) scale(.82);
  transition:transform .55s ease,opacity .55s ease;
}

#product-grid .sy-v10-card:hover{
  --lift:-8px;
  box-shadow:0 28px 70px rgba(0,0,0,.34);
}

#product-grid .sy-v10-card:hover::before{opacity:1}
#product-grid .sy-v10-card:hover::after{
  opacity:.7;
  transform:translateZ(-30px) scale(1);
}

#product-grid .sy-v10-card img{
  transform:translateZ(26px) scale(1.001);
  transform-origin:center;
  transition:transform .65s cubic-bezier(.2,.75,.2,1),filter .45s ease;
  will-change:transform;
}

#product-grid .sy-v10-card:hover img{
  transform:translateZ(42px) scale(1.045);
  filter:saturate(1.06) contrast(1.02);
}

#product-grid .sy-v10-card .btn,
#product-grid .sy-v10-card button,
#product-grid .sy-v10-card a{
  transform:translateZ(38px);
}

#product-grid .sy-v10-card .price,
#product-grid .sy-v10-card [class*="price"]{
  transform:translateZ(30px);
}

@media (max-width:900px){
  #product-grid{
    perspective:1000px;
  }
  #product-grid > .sy-v10-card,
  #product-grid .sy-v10-card{
    transform:translate3d(0,0,0) rotateX(0) rotateY(0);
  }
}

@media (prefers-reduced-motion:reduce){
  #product-grid .sy-v10-card,
  #product-grid .sy-v10-card img{
    transition:none!important;
    transform:none!important;
  }
  #product-grid .sy-v10-card::before,
  #product-grid .sy-v10-card::after{
    display:none!important;
  }
}
'@

if($styles -notmatch 'V10 PREMIUM PRODUCT SHOWCASE'){
  $styles += $cssBlock
}

$js=@'
<script id="sy-v10-product-depth">
(function(){
  "use strict";

  function initProductDepth(){
    var grid=document.getElementById("product-grid");
    if(!grid || grid.dataset.syV10Ready==="1") return;
    grid.dataset.syV10Ready="1";

    var reduced=window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    var coarse=window.matchMedia && window.matchMedia("(pointer: coarse)").matches;
    if(reduced || coarse) return;

    function wire(card){
      if(!card || card.nodeType!==1 || card.dataset.syV10Card==="1") return;
      if(card.classList.contains("loading-card")) return;

      card.dataset.syV10Card="1";
      card.classList.add("sy-v10-card");

      card.addEventListener("pointermove",function(e){
        var r=card.getBoundingClientRect();
        if(!r.width || !r.height) return;
        var x=(e.clientX-r.left)/r.width;
        var y=(e.clientY-r.top)/r.height;
        var ry=(x-.5)*8;
        var rx=(.5-y)*7;
        card.style.setProperty("--rx",rx.toFixed(2)+"deg");
        card.style.setProperty("--ry",ry.toFixed(2)+"deg");
        card.style.setProperty("--mx",(x*100).toFixed(1)+"%");
        card.style.setProperty("--my",(y*100).toFixed(1)+"%");
      });

      card.addEventListener("pointerleave",function(){
        card.style.setProperty("--rx","0deg");
        card.style.setProperty("--ry","0deg");
        card.style.setProperty("--mx","50%");
        card.style.setProperty("--my","50%");
      });
    }

    function scan(){
      Array.prototype.forEach.call(grid.children,wire);
      Array.prototype.forEach.call(grid.querySelectorAll(":scope > article, :scope > .product-card, :scope > .product-item, :scope > div"),function(el){
        if(el.parentElement===grid) wire(el);
      });
    }

    scan();
    var observer=new MutationObserver(function(){scan();});
    observer.observe(grid,{childList:true,subtree:true});
  }

  if(document.readyState==="loading"){
    document.addEventListener("DOMContentLoaded",initProductDepth,{once:true});
  }else{
    initProductDepth();
  }
})();
</script>
'@

if($html -notmatch 'id="sy-v10-product-depth"'){
  $close=$html.LastIndexOf("</body>",[StringComparison]::OrdinalIgnoreCase)
  if($close -lt 0){throw "Could not find </body> in public/index.html."}
  $html=$html.Insert($close,$js)
}

try{
  Set-Content $index $html -Encoding UTF8
  Set-Content $css $styles -Encoding UTF8

  $check=Get-Content $index -Raw
  foreach($m in @('id="product-grid"','id="cart-open"','id="checkout-form"','id="home"','id="sy-v10-product-depth"')){
    if($check.IndexOf($m,[StringComparison]::OrdinalIgnoreCase)-lt 0){
      throw "Post-write validation failed: $m"
    }
  }

  Write-Host ""
  Write-Host "SUCCESS: Product Showcase V10 applied." -ForegroundColor Green
  Write-Host "Backup: $backup" -ForegroundColor Cyan
  Write-Host "Changed only: public/index.html and public/styles.css" -ForegroundColor Yellow
  Write-Host "Backend/database/.env/app.js/admin/cart/checkout were NOT modified." -ForegroundColor Green
}
catch{
  Copy-Item (Join-Path $backup "index.html") $index -Force
  Copy-Item (Join-Path $backup "styles.css") $css -Force
  Write-Host "RESTORED: V10 changes were not kept." -ForegroundColor Green
  throw
}
