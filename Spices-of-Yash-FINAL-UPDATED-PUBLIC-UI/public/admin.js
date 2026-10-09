let csrf = "";
const $ = s => document.querySelector(s);
const money = n => new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(n);
function esc(v) { return String(v ?? "").replace(/[&<>"']/g, c => ({ "&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;" }[c])); }
async function api(url, options={}) {
  const headers = { ...(options.body ? { "Content-Type":"application/json" } : {}), ...(options.headers || {}) };
  if (options.method && options.method !== "GET") headers["X-CSRF-Token"] = csrf;
  const r = await fetch(url,{...options,headers,credentials:"same-origin"});
  const data = await r.json().catch(()=>({}));
  if(!r.ok) throw new Error(data.error || "Request failed.");
  return data;
}
function showDashboard(username) { $("#login-panel").hidden = true; $("#dashboard").hidden = false; $("#admin-user").textContent = username; loadDashboard(); }
async function loadDashboard() {
  try {
    const [summary, orders, products] = await Promise.all([api("/api/admin/summary"),api("/api/admin/orders"),api("/api/admin/products")]);
    $("#stat-products").textContent=summary.products; $("#stat-orders").textContent=summary.orders; $("#stat-revenue").textContent=money(summary.revenue); $("#stat-pending").textContent=summary.pending;
    renderOrders(orders); renderInventory(products);
  } catch(e) { if(e.message.includes("login")) location.reload(); else alert(e.message); }
}
function renderOrders(orders) {
  const el=$("#orders-list");
  if(!orders.length){el.innerHTML='<p class="muted">No orders yet. New customer orders will appear here.</p>';return;}
  el.innerHTML=orders.map(o=>`<article class="order-card"><div class="order-top"><div><strong>Order #${o.id} · ${esc(o.customer_name)}</strong><br><small>${esc(o.created_at)} · ${esc(o.phone)} · ${esc((o.order_type||"retail").toUpperCase())}</small></div><strong>${money(o.total)}</strong></div><p>${esc(o.address)}, ${esc(o.city)} — ${esc(o.pincode)}${o.email?`<br>${esc(o.email)}`:""}${o.business_name?`<br>Business: ${esc(o.business_name)}`:""}${o.coupon_code?`<br>Coupon: ${esc(o.coupon_code)} · discount ${money(o.discount)}`:""}${o.notes?`<br>Note: ${esc(o.notes)}`:""}</p><div class="order-items">${o.items.map(i=>`${esc(i.product_name)} × ${i.quantity} — ${money(i.unit_price*i.quantity)}`).join("<br>")}</div><div class="order-actions"><label>Status <select data-status="${o.id}">${["New","Confirmed","Packed","Shipped","Delivered","Cancelled"].map(s=>`<option ${s===o.status?"selected":""}>${s}</option>`).join("")}</select></label><button class="secondary-btn" data-save-order="${o.id}">Update status</button><span class="muted">UPI: ${esc(o.payment_status||"Pending verification")}</span>${o.payment_status!=="Paid"?`<button class="secondary-btn" data-verify-payment="${o.id}">Mark UPI verified</button>`:""}</div></article>`).join("");
}
function renderInventory(products) {
  const el=$("#inventory-list");
  el.innerHTML=products.map(p=>`<div class="inventory-row inventory-edit-row"><div class="inventory-product-name"><strong>${esc(p.name)}</strong><br><span class="muted">${esc(p.category)} · ${esc(p.weight)}</span></div><label>Retail ₹<input type="number" min="0.01" max="100000" step="0.01" value="${p.price}" data-price="${p.id}"></label><label>Stock<input type="number" min="0" max="100000" step="1" value="${p.stock}" data-stock="${p.id}"></label><label>Wholesale ₹<input type="number" min="0" max="100000" step="0.01" value="${p.wholesale_price}" data-wholesale="${p.id}"></label><label>Min qty<input type="number" min="2" max="100000" step="1" value="${p.wholesale_min_qty}" data-minqty="${p.id}"></label><label class="inventory-active">Active<input type="checkbox" data-active="${p.id}" ${p.active?"checked":""}></label><button class="secondary-btn" data-save-product="${p.id}">Save changes</button></div>`).join("") || '<p class="muted">No products found.</p>';
}
$("#login-form").addEventListener("submit",async e=>{
  e.preventDefault(); const b=e.currentTarget.querySelector("button"); b.disabled=true; $("#login-error").textContent="";
  try { const f=new FormData(e.currentTarget); const result=await api("/api/admin/login",{method:"POST",body:JSON.stringify({username:f.get("username"),password:f.get("password")})}); csrf=result.csrfToken; showDashboard(result.username); }
  catch(err){$("#login-error").textContent=err.message;try{csrf=(await api("/api/csrf")).csrfToken;}catch{}}
  finally{b.disabled=false;}
});
$("#dashboard").addEventListener("click",async e=>{
  const order=e.target.closest("[data-save-order]"); const product=e.target.closest("[data-save-product]"); const payment=e.target.closest("[data-verify-payment]");
  try {
    if(order){const id=order.dataset.saveOrder;const status=$(`[data-status="${id}"]`).value;await api(`/api/admin/orders/${id}`,{method:"PATCH",body:JSON.stringify({status})});}
    if(product){const id=product.dataset.saveProduct;const price=Number($(`[data-price="${id}"]`).value);const stock=Number($(`[data-stock="${id}"]`).value);const wholesale_price=Number($(`[data-wholesale="${id}"]`).value);const wholesale_min_qty=Number($(`[data-minqty="${id}"]`).value);const active=$(`[data-active="${id}"]`).checked;if(!Number.isFinite(price)||price<=0)throw new Error("Retail price must be greater than zero.");if(!Number.isInteger(stock)||stock<0)throw new Error("Stock must be a non-negative whole number.");if(!Number.isFinite(wholesale_price)||wholesale_price<0)throw new Error("Wholesale price cannot be negative.");if(!Number.isInteger(wholesale_min_qty)||wholesale_min_qty<2)throw new Error("Wholesale minimum must be at least 2 units.");await api(`/api/admin/products/${id}`,{method:"PATCH",body:JSON.stringify({price,stock,wholesale_price,wholesale_min_qty,active})});}
    if(payment){if(!confirm("Only continue after checking the payment in your bank/UPI app. Mark this order as paid?"))return;await api(`/api/admin/orders/${payment.dataset.verifyPayment}/payment`,{method:"PATCH",body:JSON.stringify({paymentStatus:"Paid"})});}
    if(order||product||payment){await loadDashboard();await loadReports();}
  }catch(err){alert(err.message);}
});
$("#product-form").addEventListener("submit",async e=>{
  e.preventDefault();const b=e.currentTarget.querySelector("button");b.disabled=true;$("#product-message").textContent="";
  const f=new FormData(e.currentTarget);const payload={name:f.get("name"),category:f.get("category"),description:f.get("description"),price:Number(f.get("price")),weight:f.get("weight"),image:f.get("image"),stock:Number(f.get("stock")),wholesale_price:Number(f.get("wholesale_price")),wholesale_min_qty:Number(f.get("wholesale_min_qty")),featured:f.get("featured")==="on"};
  try{await api("/api/admin/products",{method:"POST",body:JSON.stringify(payload)});$("#product-message").textContent="Product added.";e.currentTarget.reset();e.currentTarget.stock.value=25;await loadDashboard();}
  catch(err){$("#product-message").textContent=err.message;}
  finally{b.disabled=false;}
});
$("#logout").addEventListener("click",async()=>{try{await api("/api/admin/logout",{method:"POST",body:JSON.stringify({})});location.reload();}catch(e){alert(e.message);}});
$("#refresh-orders").addEventListener("click",loadDashboard);$("#refresh-products").addEventListener("click",loadDashboard);
(async()=>{try{const me=await api("/api/admin/me");csrf=me.csrfToken;showDashboard(me.username);}catch{try{csrf=(await api("/api/csrf")).csrfToken;}catch{}}})();

async function loadCoupons(){
 try{const items=await api('/api/admin/coupons');$('#coupons-list').innerHTML=items.map(c=>`<article class="order-card"><div class="order-top"><strong>${esc(c.code)} · ${c.discount_type==='percent'?`${c.discount_value}%`:`${money(c.discount_value)}`}</strong><span class="muted">${c.active?'Active':'Inactive'} · min ${money(c.min_order)}</span></div><p>Expires: ${esc(c.expires_at||'Never')}</p><button class="secondary-btn" data-coupon-toggle="${c.id}" data-active="${c.active?0:1}">${c.active?'Deactivate':'Activate'}</button></article>`).join('')||'<p class="muted">No coupons created yet.</p>';}catch(e){$('#coupons-list').textContent=e.message;}
}
async function loadReports(){
 try{const r=await api('/api/admin/reports');$('#reports-content').innerHTML=`<h3>Monthly paid revenue</h3>${r.monthly.map(x=>`<p>${esc(x.month)} · ${x.paidOrders} paid / ${x.orders} total orders · <strong>${money(x.revenue)}</strong></p>`).join('')||'<p class="muted">No orders yet.</p>'}<h3>Top ordered products</h3>${r.bestSellers.map(x=>`<p>${esc(x.name)} · ${x.units} units · ${money(x.gross)}</p>`).join('')||'<p class="muted">No paid orders yet.</p>'}<h3>Low stock (10 units or fewer)</h3>${r.lowStock.map(x=>`<p>${esc(x.name)} · ${x.stock} left</p>`).join('')||'<p>All active products are above the low-stock threshold.</p>'}<h3>Payment status</h3>${r.payments.map(x=>`<p>${esc(x.status)} · ${x.count}</p>`).join('')}`;}catch(e){$('#reports-content').textContent=e.message;}
}
const originalShowDashboard=showDashboard;
showDashboard=function(username){originalShowDashboard(username);loadCoupons();loadReports();};
$('#coupon-form')?.addEventListener('submit',async e=>{e.preventDefault();const f=new FormData(e.currentTarget);const m=$('#coupon-message');try{await api('/api/admin/coupons',{method:'POST',body:JSON.stringify({code:f.get('code'),discountType:f.get('discountType'),discountValue:Number(f.get('discountValue')),minOrder:Number(f.get('minOrder')),expiresAt:f.get('expiresAt')})});m.textContent='Coupon created.';e.currentTarget.reset();await loadCoupons();}catch(err){m.textContent=err.message;}});
$('#coupons-list')?.addEventListener('click',async e=>{const b=e.target.closest('[data-coupon-toggle]');if(!b)return;try{await api(`/api/admin/coupons/${b.dataset.couponToggle}`,{method:'PATCH',body:JSON.stringify({active:b.dataset.active==='1'})});await loadCoupons();}catch(err){alert(err.message);}});
$('#refresh-coupons')?.addEventListener('click',loadCoupons);$('#download-report')?.addEventListener('click',()=>{window.location.href='/api/admin/reports.csv';});
