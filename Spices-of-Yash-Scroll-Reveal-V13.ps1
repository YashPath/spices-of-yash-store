# Spices of Yash — Premium Spice Scroll Reveal V13
# Run from the spices-of-yash-store project root.
$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$indexPath = Join-Path $root 'public\index.html'
$cssPath = Join-Path $root 'public\styles.css'
if (!(Test-Path $indexPath) -or !(Test-Path $cssPath)) { Write-Host 'ERROR: Run from spices-of-yash-store project root; public\index.html and public\styles.css must exist.' -ForegroundColor Red; exit 1 }
$html = Get-Content $indexPath -Raw
$css = Get-Content $cssPath -Raw
foreach ($marker in @('id="product-grid"','id="cart-open"','id="checkout-form"')) { if (!$html.Contains($marker)) { Write-Host "ERROR: Required marker missing: $marker. No changes made." -ForegroundColor Red; exit 1 } }
if ($html.Contains('id="spice-scroll-v13"')) { Write-Host 'V13 already exists; no duplicate inserted.' -ForegroundColor Yellow; exit 0 }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $root "spice-scroll-v13-backup-$stamp"
New-Item -ItemType Directory -Path $backup | Out-Null
Copy-Item $indexPath (Join-Path $backup 'index.html')
Copy-Item $cssPath (Join-Path $backup 'styles.css')
$section = @'
<section id="spice-scroll-v13" class="spice-scroll-v13" aria-label="Explore our spices">
  <div class="spice-v13-intro"><p class="spice-v13-kicker">THE PANTRY, ONE INGREDIENT AT A TIME</p><h2>Good food starts<br><em>with the little things.</em></h2><p class="spice-v13-intro-copy">Scroll through the ingredients that bring colour, warmth and character to everyday cooking.</p><span class="spice-v13-scroll-note">SCROLL TO EXPLORE <span aria-hidden="true">↓</span></span></div>
  <div class="spice-v13-stages">
    <article class="spice-v13-stage is-active" data-spice-stage><div class="spice-v13-photo spice-v13-cardamom" role="img" aria-label="Green cardamom pods"><span class="spice-v13-orbit"></span><span class="spice-v13-seed seed-a"></span><span class="spice-v13-seed seed-b"></span><span class="spice-v13-seed seed-c"></span><span class="spice-v13-photo-label">01 / WHOLE SPICE</span></div><div class="spice-v13-caption"><span class="spice-v13-number">01</span><div><p>FRESH · AROMATIC · BRIGHT</p><h3>Green Cardamom</h3><span>A fragrant lift for chai, sweets and slow Sunday recipes.</span></div></div></article>
    <article class="spice-v13-stage" data-spice-stage><div class="spice-v13-photo spice-v13-chilli" role="img" aria-label="Red chilli peppers"><span class="spice-v13-orbit"></span><span class="spice-v13-seed seed-a"></span><span class="spice-v13-seed seed-b"></span><span class="spice-v13-seed seed-c"></span><span class="spice-v13-photo-label">02 / BOLD HEAT</span></div><div class="spice-v13-caption"><span class="spice-v13-number">02</span><div><p>VIBRANT · WARM · EXPRESSIVE</p><h3>Red Chilli</h3><span>Deep colour and confident warmth for everyday favourites.</span></div></div></article>
    <article class="spice-v13-stage" data-spice-stage><div class="spice-v13-photo spice-v13-turmeric" role="img" aria-label="Golden turmeric"><span class="spice-v13-orbit"></span><span class="spice-v13-seed seed-a"></span><span class="spice-v13-seed seed-b"></span><span class="spice-v13-seed seed-c"></span><span class="spice-v13-photo-label">03 / GOLDEN ROOT</span></div><div class="spice-v13-caption"><span class="spice-v13-number">03</span><div><p>EARTHY · GOLDEN · ESSENTIAL</p><h3>Golden Turmeric</h3><span>A grounding pantry staple with a mellow, earthy character.</span></div></div></article>
    <article class="spice-v13-stage" data-spice-stage><div class="spice-v13-photo spice-v13-masala" role="img" aria-label="Garam masala spices"><span class="spice-v13-orbit"></span><span class="spice-v13-seed seed-a"></span><span class="spice-v13-seed seed-b"></span><span class="spice-v13-seed seed-c"></span><span class="spice-v13-photo-label">04 / HOUSE BLEND</span></div><div class="spice-v13-caption"><span class="spice-v13-number">04</span><div><p>TOASTED · LAYERED · COMFORTING</p><h3>Garam Masala</h3><span>A balanced blend that makes familiar dishes feel special.</span></div></div></article>
  </div>
</section>
'@
$gridPos = $html.IndexOf('id="product-grid"')
$sectionStart = $html.LastIndexOf('<section', $gridPos, [System.StringComparison]::OrdinalIgnoreCase)
if ($sectionStart -lt 0) { $sectionStart = $html.LastIndexOf('<div', $gridPos, [System.StringComparison]::OrdinalIgnoreCase) }
if ($sectionStart -lt 0) { Remove-Item $backup -Recurse -Force; Write-Host 'ERROR: Could not find product-grid container. No files changed.' -ForegroundColor Red; exit 1 }
$html = $html.Insert($sectionStart, $section + "`r`n")
$cssAddition = @'

/* ===== Spices of Yash V13: restrained editorial scroll reveal ===== */
.spice-scroll-v13{position:relative;display:grid;grid-template-columns:minmax(260px,.82fr) minmax(360px,1.18fr);gap:clamp(34px,7vw,120px);padding:clamp(76px,10vw,150px) clamp(24px,9.6vw,160px);background:#100a08;color:#f5eddf;overflow:clip;border-top:1px solid rgba(205,157,73,.2)}
.spice-v13-intro{position:sticky;top:18vh;align-self:start;padding:8vh 0 10vh;max-width:510px}.spice-v13-kicker,.spice-v13-caption p{font:700 10px/1.6 "DM Mono",monospace;letter-spacing:.2em;color:#d4a64e}
.spice-v13-intro h2{font-family:Georgia,"Times New Roman",serif;font-size:clamp(42px,5.4vw,78px);font-weight:400;line-height:.98;letter-spacing:-.055em;margin:25px 0}.spice-v13-intro h2 em{font-weight:400;color:#c99a43}.spice-v13-intro-copy{max-width:390px;color:#bcb1a5;line-height:1.85;font-size:15px}.spice-v13-scroll-note{display:inline-flex;gap:18px;align-items:center;margin-top:54px;font:700 9px "DM Mono",monospace;letter-spacing:.18em;color:#8f8173}.spice-v13-scroll-note span{color:#d4a64e;font-size:18px}
.spice-v13-stages{min-width:0}.spice-v13-stage{min-height:86vh;display:flex;flex-direction:column;justify-content:center;padding:32px 0;opacity:.48;transform:translateY(22px) scale(.985);transition:opacity .7s ease,transform .8s cubic-bezier(.2,.7,.2,1)}.spice-v13-stage.is-active{opacity:1;transform:translateY(0) scale(1)}
.spice-v13-photo{position:relative;isolation:isolate;min-height:clamp(300px,42vw,560px);overflow:hidden;border-radius:4px;background:#25140d;box-shadow:0 25px 90px rgba(0,0,0,.28);background-size:cover;background-position:center}.spice-v13-photo:before{content:"";position:absolute;inset:0;z-index:-1;background-size:cover;background-position:center;transform:scale(1.04);transition:transform 1.2s cubic-bezier(.2,.7,.2,1),filter 1s ease;filter:saturate(.86)}.spice-v13-stage.is-active .spice-v13-photo:before{transform:scale(1);filter:saturate(1.08)}
.spice-v13-cardamom:before{background-image:linear-gradient(0deg,rgba(12,7,4,.45),transparent 50%),url("https://images.unsplash.com/photo-1615485500704-8e990f9900f5?auto=format&fit=crop&w=1200&q=85")}.spice-v13-chilli:before{background-image:linear-gradient(0deg,rgba(12,7,4,.45),transparent 50%),url("https://images.unsplash.com/photo-1588252303782-cb80119abd6d?auto=format&fit=crop&w=1200&q=85")}.spice-v13-turmeric:before{background-image:linear-gradient(0deg,rgba(12,7,4,.45),transparent 50%),url("https://images.unsplash.com/photo-1615485290382-441e4d049cb5?auto=format&fit=crop&w=1200&q=85")}.spice-v13-masala:before{background-image:linear-gradient(0deg,rgba(12,7,4,.45),transparent 50%),url("https://images.unsplash.com/photo-1596040033229-a9821ebd058d?auto=format&fit=crop&w=1200&q=85")}
.spice-v13-photo-label{position:absolute;left:22px;bottom:20px;color:#fff8ed;font:700 9px "DM Mono",monospace;letter-spacing:.2em;text-shadow:0 2px 12px #000}.spice-v13-orbit{position:absolute;width:70%;aspect-ratio:1;left:15%;top:12%;border:1px solid rgba(232,188,100,.45);border-radius:50%;pointer-events:none;transition:transform 1.1s ease}.spice-v13-stage.is-active .spice-v13-orbit{transform:scale(1.08) rotate(-12deg)}
.spice-v13-seed{position:absolute;display:block;width:25px;height:54px;border-radius:70% 30% 70% 30%;background:linear-gradient(140deg,#d9b86a,#6d7936 65%,#253b22);box-shadow:0 12px 25px #0005;opacity:.78;transition:transform .9s ease}.spice-v13-cardamom .seed-a{top:27%;left:22%;transform:rotate(42deg)}.spice-v13-cardamom .seed-b{top:52%;left:72%;transform:rotate(-38deg)}.spice-v13-cardamom .seed-c{top:68%;left:34%;transform:rotate(68deg)}.spice-v13-chilli .spice-v13-seed{width:18px;height:105px;border-radius:90% 15% 90% 15%;background:linear-gradient(130deg,#fa6541,#a61912 70%,#4a130e)}.spice-v13-chilli .seed-a{top:23%;left:25%;transform:rotate(38deg)}.spice-v13-chilli .seed-b{top:44%;left:68%;transform:rotate(-44deg)}.spice-v13-chilli .seed-c{top:60%;left:43%;transform:rotate(70deg)}.spice-v13-turmeric .spice-v13-seed{width:46px;height:46px;border-radius:50%;background:radial-gradient(circle at 35% 30%,#ffd95b,#d78a13 70%,#7c3d0b)}.spice-v13-turmeric .seed-a{top:28%;left:28%}.spice-v13-turmeric .seed-b{top:55%;left:63%;transform:scale(1.5)}.spice-v13-turmeric .seed-c{top:67%;left:35%;transform:scale(.8)}.spice-v13-masala .spice-v13-seed{width:42px;height:42px;border-radius:50%;background:radial-gradient(circle at 35% 30%,#d3a05a,#7c3f22 70%,#30190e)}.spice-v13-masala .seed-a{top:25%;left:25%}.spice-v13-masala .seed-b{top:55%;left:68%;transform:scale(1.25)}.spice-v13-masala .seed-c{top:68%;left:38%;transform:scale(.75)}
.spice-v13-caption{display:flex;gap:22px;align-items:flex-start;padding:25px 0 0}.spice-v13-number{font:400 26px/1 Georgia,serif;color:#c99a43}.spice-v13-caption p{margin:0 0 10px;font-size:9px}.spice-v13-caption h3{font:400 clamp(28px,3vw,42px)/1.05 Georgia,"Times New Roman",serif;margin:0 0 10px;letter-spacing:-.035em}.spice-v13-caption span{color:#b8ada1;font-size:13px;line-height:1.7}
@media(max-width:800px){.spice-scroll-v13{grid-template-columns:1fr;gap:8px;padding:72px 22px}.spice-v13-intro{position:relative;top:auto;padding:0 0 28px}.spice-v13-intro h2{font-size:clamp(43px,11vw,68px)}.spice-v13-stage{min-height:auto;padding:22px 0 48px;opacity:1;transform:none}.spice-v13-photo{min-height:clamp(310px,92vw,480px)}.spice-v13-scroll-note{margin-top:24px}.spice-v13-caption{gap:14px}}
@media(prefers-reduced-motion:reduce){.spice-v13-stage,.spice-v13-photo:before,.spice-v13-orbit,.spice-v13-seed{transition:none!important;transform:none!important;scroll-behavior:auto!important}}
'@
$jsAddition = @'
<script id="spice-scroll-v13-js">
(function(){const root=document.getElementById('spice-scroll-v13');if(!root||!('IntersectionObserver'in window))return;const stages=Array.from(root.querySelectorAll('[data-spice-stage]'));const observer=new IntersectionObserver(entries=>{entries.forEach(entry=>{if(entry.isIntersecting)stages.forEach(stage=>stage.classList.toggle('is-active',stage===entry.target));});},{rootMargin:'-22% 0px -22% 0px',threshold:.12});stages.forEach(stage=>observer.observe(stage));})();
</script>
'@
$html += "`r`n$jsAddition`r`n"
$css += "`r`n$cssAddition`r`n"
try {
  Set-Content -Path $indexPath -Value $html -Encoding UTF8
  Set-Content -Path $cssPath -Value $css -Encoding UTF8
  if (!( (Get-Content $indexPath -Raw).Contains('id="spice-scroll-v13"')) -or !( (Get-Content $cssPath -Raw).Contains('Spices of Yash V13'))) { throw 'Post-write validation failed.' }
  Write-Host 'SUCCESS: V13 spice scroll reveal added.' -ForegroundColor Green
  Write-Host "Backup saved at: $backup" -ForegroundColor Cyan
  Write-Host 'Changed only public/index.html and public/styles.css. Backend, app.js, admin, cart and checkout untouched.' -ForegroundColor Yellow
  Write-Host 'Keep npm start running; open http://localhost:3000 and press Ctrl+Shift+R.' -ForegroundColor Green
} catch {
  Copy-Item (Join-Path $backup 'index.html') $indexPath -Force
  Copy-Item (Join-Path $backup 'styles.css') $cssPath -Force
  Write-Host "ERROR: Changes rolled back. $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
