$ErrorActionPreference="Stop"
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$index=Join-Path $root "public\index.html"
$css=Join-Path $root "public\styles.css"
if(!(Test-Path $index)){throw "public\index.html not found."}
if(!(Test-Path $css)){throw "public\styles.css not found."}

$html=Get-Content $index -Raw
$styles=Get-Content $css -Raw

foreach($m in @('id="product-grid"','id="cart-open"','id="checkout-form"','id="home"')){
  if($html.IndexOf($m,[StringComparison]::OrdinalIgnoreCase)-lt 0){throw "Safety check failed: $m"}
}

$stamp=Get-Date -Format "yyyyMMdd-HHmmss"
$backup=Join-Path $root "cinematic-spice-v12-backup-$stamp"
New-Item -ItemType Directory -Path $backup -Force|Out-Null
Copy-Item $index (Join-Path $backup "index.html")
Copy-Item $css (Join-Path $backup "styles.css")

# Remove an accidentally installed V11 block if present, using its unique IDs.
$html=[regex]::Replace($html,'(?s)<section[^>]*id="spice-journey"[^>]*>.*?</section>\s*','',1)
$html=[regex]::Replace($html,'(?s)<script[^>]*id="sy-v11-spice-journey"[^>]*>.*?</script>\s*','',1)

$section=@'
<section class="sy-v12-reveal" id="spice-reveal" aria-label="Spices of Yash ingredient reveal">
  <div class="sy-v12-frame">
    <div class="sy-v12-copy">
      <span class="sy-v12-kicker">FROM OUR PANTRY</span>
      <h2>Meet the<br><em>ingredients.</em></h2>
      <p class="sy-v12-name" aria-live="polite">Green Cardamom</p>
      <p class="sy-v12-meta">Whole spice · 100g</p>
    </div>
    <div class="sy-v12-visual" aria-hidden="true">
      <div class="sy-v12-halo"></div>
      <div class="sy-v12-orbit"></div>
      <img src="/images/green-cardamom.jpg" alt="" />
    </div>
    <div class="sy-v12-caption">SCROLL TO DISCOVER <span></span></div>
    <div class="sy-v12-index"><strong>01</strong><i></i><span>04</span></div>
  </div>
</section>
'@

# Insert immediately before the real shop/product section, not inside it.
$shopPattern='(?s)(<[^>]*id="shop"[^>]*>)'
if([regex]::Matches($html,$shopPattern).Count -eq 1){
  $html=[regex]::Replace($html,$shopPattern,$section+'$1',1)
}else{
  throw 'Could not locate #shop section.'
}

$cssBlock=@'

/* =========================================================
   SPICES OF YASH — V12 CINEMATIC SPICE REVEAL
   One visual / one camera / sequential ingredient reveal.
   Short, integrated section — not a giant product carousel.
   ========================================================= */

.sy-v12-reveal{
  position:relative;
  height:185vh;
  background:
    radial-gradient(circle at 70% 50%,rgba(193,135,47,.11),transparent 25%),
    linear-gradient(180deg,#0c0806 0%,#120b08 50%,#0b0806 100%);
  color:#f8f1e6;
  overflow:clip;
  border-top:1px solid rgba(214,164,72,.16);
  border-bottom:1px solid rgba(214,164,72,.12);
}

.sy-v12-frame{
  position:sticky;
  top:0;
  height:100vh;
  min-height:620px;
  max-width:1450px;
  margin:auto;
  display:grid;
  grid-template-columns:38% 62%;
  align-items:center;
  padding:70px 7vw;
  box-sizing:border-box;
}

.sy-v12-copy{
  position:relative;
  z-index:3;
  transform:translateY(5vh);
}
.sy-v12-kicker{
  display:block;
  margin-bottom:18px;
  color:#d8aa51;
  font:700 10px/1.2 ui-monospace,SFMono-Regular,Menlo,monospace;
  letter-spacing:.24em;
}
.sy-v12-copy h2{
  margin:0;
  font:500 clamp(54px,6vw,94px)/.88 Georgia,"Times New Roman",serif;
  letter-spacing:-.055em;
}
.sy-v12-copy h2 em{
  color:#c89542;
  font-style:normal;
}
.sy-v12-name{
  margin:38px 0 5px;
  font:500 clamp(25px,2.2vw,36px)/1 Georgia,"Times New Roman",serif;
  transition:opacity .25s ease,transform .35s ease;
}
.sy-v12-meta{
  margin:0;
  color:rgba(248,241,230,.48);
  font-size:12px;
  letter-spacing:.05em;
}

.sy-v12-visual{
  position:relative;
  width:min(53vw,720px);
  aspect-ratio:1;
  justify-self:center;
  display:grid;
  place-items:center;
  perspective:1000px;
}
.sy-v12-halo{
  position:absolute;
  width:58%;
  aspect-ratio:1;
  border-radius:50%;
  background:radial-gradient(circle,rgba(219,161,57,.24),rgba(133,69,24,.08) 40%,transparent 70%);
  filter:blur(20px);
  transform:scale(.9);
}
.sy-v12-orbit{
  position:absolute;
  width:76%;
  height:28%;
  border:1px solid rgba(219,166,76,.22);
  border-radius:50%;
  transform:rotateX(68deg) rotateZ(-15deg);
}
.sy-v12-visual img{
  position:relative;
  z-index:2;
  width:68%;
  height:68%;
  object-fit:contain;
  filter:drop-shadow(0 45px 38px rgba(0,0,0,.58));
  transform:translate3d(0,20px,60px) scale(.88) rotate(-3deg);
  opacity:0;
  transition:opacity .45s ease,transform .8s cubic-bezier(.2,.8,.2,1),filter .5s ease;
}
.sy-v12-visual img.sy-v12-show{
  opacity:1;
  transform:translate3d(0,0,60px) scale(1) rotate(0deg);
}
.sy-v12-visual img.sy-v12-leave{
  opacity:0;
  transform:translate3d(0,-22px,10px) scale(.9) rotate(5deg);
}

.sy-v12-caption{
  position:absolute;
  bottom:42px;
  left:7vw;
  color:rgba(255,255,255,.38);
  font:700 9px ui-monospace,SFMono-Regular,Menlo,monospace;
  letter-spacing:.2em;
}
.sy-v12-caption span{
  display:inline-block;
  width:48px;height:1px;
  margin-left:12px;
  vertical-align:middle;
  background:#c99745;
}
.sy-v12-index{
  position:absolute;
  right:7vw;
  bottom:42px;
  display:flex;
  align-items:center;
  gap:10px;
  color:rgba(255,255,255,.35);
  font:700 10px ui-monospace,SFMono-Regular,Menlo,monospace;
}
.sy-v12-index strong{color:#d9a84d;font-size:17px}
.sy-v12-index i{width:44px;height:1px;background:rgba(255,255,255,.18)}

@media(max-width:900px){
  .sy-v12-reveal{height:175vh}
  .sy-v12-frame{
    grid-template-columns:1fr;
    grid-template-rows:auto 1fr;
    padding:95px 24px 55px;
  }
  .sy-v12-copy{text-align:center;transform:none}
  .sy-v12-copy h2{font-size:clamp(50px,14vw,78px)}
  .sy-v12-name{margin-top:20px}
  .sy-v12-visual{
    width:min(88vw,560px);
    align-self:center;
  }
  .sy-v12-visual img{width:74%;height:74%}
  .sy-v12-caption{left:24px;bottom:24px}
  .sy-v12-index{right:24px;bottom:24px}
}

@media(prefers-reduced-motion:reduce){
  .sy-v12-reveal{height:auto;padding:100px 20px}
  .sy-v12-frame{position:relative;height:auto;display:block;padding:0}
  .sy-v12-copy{text-align:center}
  .sy-v12-visual{margin:50px auto 30px}
  .sy-v12-caption,.sy-v12-index{display:none}
  .sy-v12-visual img{opacity:1!important;transform:none!important}
}
'@
if($styles -notmatch 'V12 CINEMATIC SPICE REVEAL'){$styles+=$cssBlock}

$js=@'
<script id="sy-v12-spice-reveal">
(function(){
  "use strict";
  var root=document.getElementById("spice-reveal");
  if(!root || root.dataset.ready==="1") return;
  root.dataset.ready="1";

  var image=root.querySelector(".sy-v12-visual img");
  var name=root.querySelector(".sy-v12-name");
  var meta=root.querySelector(".sy-v12-meta");
  var current=-1;
  var products=[];

  function imagePath(v){
    v=v==null?"":String(v);
    if(!v) return "/images/story-spices.webp";
    if(/^https?:\/\//i.test(v) || v.charAt(0)==="/") return v;
    return "/"+v.replace(/^\.?\//,"");
  }

  function render(i){
    if(!products.length) return;
    i=Math.max(0,Math.min(products.length-1,i));
    if(i===current) return;
    var p=products[i]||{};
    current=i;

    image.classList.remove("sy-v12-show");
    image.classList.add("sy-v12-leave");
    name.style.opacity="0";
    name.style.transform="translateY(8px)";

    setTimeout(function(){
      image.src=imagePath(p.image);
      image.alt=p.name||"Spice";
      name.textContent=p.name||"Signature Spice";
      meta.textContent=[p.category,p.weight].filter(Boolean).join(" · ")||"Small-batch pantry essential";
      image.classList.remove("sy-v12-leave");
      image.classList.add("sy-v12-show");
      name.style.opacity="1";
      name.style.transform="translateY(0)";
      root.querySelector(".sy-v12-index strong").textContent=String(i+1).padStart(2,"0");
    },220);
  }

  function update(){
    var r=root.getBoundingClientRect();
    var range=Math.max(1,root.offsetHeight-window.innerHeight);
    var progress=Math.max(0,Math.min(1,-r.top/range));
    var i=Math.min(products.length-1,Math.floor(progress*products.length));
    render(i);
  }

  function start(){
    if(!products.length) return;
    render(0);
    update();
    window.addEventListener("scroll",update,{passive:true});
    window.addEventListener("resize",update,{passive:true});
  }

  fetch("/api/products",{headers:{"Accept":"application/json"}})
    .then(function(r){if(!r.ok)throw new Error();return r.json();})
    .then(function(items){
      products=(Array.isArray(items)?items:[]).slice(0,4);
      if(!products.length)throw new Error();
      start();
    })
    .catch(function(){
      products=[
        {name:"Green Cardamom",category:"Whole Spice",weight:"100g",image:"/images/green-cardamom.jpg"},
        {name:"Golden Turmeric",category:"Ground Spice",weight:"100g",image:"/images/golden-turmeric.jpg"},
        {name:"Kashmiri Chilli",category:"Ground Spice",weight:"100g",image:"/images/kashmiri-chilli.jpg"},
        {name:"Garam Masala",category:"Signature Blend",weight:"100g",image:"/images/garam-masala.jpg"}
      ];
      start();
    });
})();
</script>
'@

if($html -notmatch 'id="sy-v12-spice-reveal"'){
  $close=$html.LastIndexOf("</body>",[StringComparison]::OrdinalIgnoreCase)
  if($close -lt 0){throw "Could not find </body>."}
  $html=$html.Insert($close,$js)
}

try{
  Set-Content $index $html -Encoding UTF8
  Set-Content $css $styles -Encoding UTF8
  $check=Get-Content $index -Raw
  foreach($m in @('id="product-grid"','id="cart-open"','id="checkout-form"','id="home"','id="spice-reveal"','id="sy-v12-spice-reveal"')){
    if($check.IndexOf($m,[StringComparison]::OrdinalIgnoreCase)-lt 0){throw "Post-write validation failed: $m"}
  }
  Write-Host ""
  Write-Host "SUCCESS: V12 cinematic spice reveal applied." -ForegroundColor Green
  Write-Host "Backup: $backup" -ForegroundColor Cyan
  Write-Host "Changed only: public/index.html and public/styles.css" -ForegroundColor Yellow
  Write-Host "Backend/database/.env/app.js/admin/cart/checkout were NOT modified." -ForegroundColor Green
}catch{
  Copy-Item (Join-Path $backup "index.html") $index -Force
  Copy-Item (Join-Path $backup "styles.css") $css -Force
  Write-Host "RESTORED: V12 changes were not kept." -ForegroundColor Green
  throw
}
