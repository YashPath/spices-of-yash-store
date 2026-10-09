const state = { products: [], category: "All", query: "", cart: loadCart(), csrf: "", config: {} };
const $ = (s) => document.querySelector(s);
const $$ = (s) => [...document.querySelectorAll(s)];
const money = (n) => new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(n);
function loadCart() { try { const v = JSON.parse(localStorage.getItem("spiceroot-cart") || "[]"); return Array.isArray(v) ? v.filter(x => Number.isInteger(x.id) && Number.isInteger(x.qty) && x.qty > 0) : []; } catch { return []; } }
function saveCart() { localStorage.setItem("spiceroot-cart", JSON.stringify(state.cart)); renderCart(); }
async function api(url, options = {}) {
  const headers = { ...(options.body ? { "Content-Type": "application/json" } : {}), ...(options.headers || {}) };
  if (options.method && !["GET", "HEAD"].includes(options.method.toUpperCase())) headers["X-CSRF-Token"] = state.csrf;
  const response = await fetch(url, { ...options, headers, credentials: "same-origin" });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || "Something went wrong.");
  return data;
}
function toast(message) { const el = $("#toast"); el.textContent = message; el.classList.add("show"); clearTimeout(toast.timer); toast.timer = setTimeout(() => el.classList.remove("show"), 2600); }
const LOCAL_SPICE_IMAGES = new Set([
  "kashmiri-red-chilli", "golden-turmeric", "green-cardamom",
  "cumin-seeds", "black-peppercorns", "garam-masala"
]);
function safeImage(url, slug) {
  // Bundled local images keep the demo catalogue working even when third-party image URLs fail.
  if (LOCAL_SPICE_IMAGES.has(String(slug || ""))) return `/images/${slug}.jpg`;
  try {
    const parsed = new URL(String(url || ""));
    if (parsed.protocol === "https:" && parsed.hostname && !parsed.username && !parsed.password) return escapeHtml(parsed.href);
  } catch {}
  return "/images/spice-placeholder.svg";
}
function renderProducts() {
  const products = state.products.filter(p => (state.category === "All" || p.category === state.category) && `${p.name} ${p.category} ${p.description}`.toLowerCase().includes(state.query.toLowerCase()));
  const grid = $("#product-grid");
  if (!products.length) { grid.innerHTML = '<div class="empty-state">No spices found. Try another search.</div>'; return; }
  grid.innerHTML = products.map(p => `<article class="product-card"><div class="product-image-wrap"><img class="product-image" src="${safeImage(p.image, p.slug)}" onerror="this.onerror=null;this.src='/images/spice-placeholder.svg'" alt="${escapeHtml(p.name)}" loading="lazy"><span class="product-tag">${p.featured ? "PANTRY FAVOURITE" : escapeHtml(p.category)}</span><button class="add-btn" data-add="${p.id}" aria-label="Add ${escapeHtml(p.name)} to bag" ${p.stock < 1 ? "disabled" : ""}>${p.stock < 1 ? "×" : "+"}</button></div><div class="product-meta"><div><h3>${escapeHtml(p.name)}</h3><p>${escapeHtml(p.weight)} · ${p.stock > 0 ? "In stock" : "Sold out"}</p></div><span class="product-price">${money(p.price)}</span></div><p class="wholesale-hint">Bulk: ${p.wholesale_price > 0 ? money(p.wholesale_price) + " / unit from " + p.wholesale_min_qty : "Ask us for a quote"}</p><p class="product-desc">${escapeHtml(p.description)}</p></article>`).join("");
}
function escapeHtml(v) { return String(v ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])); }
function addToCart(id) {
  const p = state.products.find(p => p.id === id);
  if (!p || p.stock < 1) return toast("This product is currently unavailable.");
  const item = state.cart.find(x => x.id === id);
  if (item && item.qty >= Math.min(p.stock, 20)) return toast("Maximum available quantity reached.");
  if (item) item.qty++; else state.cart.push({ id, qty: 1 });
  saveCart(); toast(`${p.name} added to your bag.`);
}
function renderCart() {
  const valid = state.cart.filter(item => state.products.some(p => p.id === item.id));
  if (valid.length !== state.cart.length) state.cart = valid;
  const count = state.cart.reduce((sum, x) => sum + x.qty, 0);
  $("#cart-count").textContent = count; $("#drawer-count").textContent = `(${count})`;
  const items = state.cart.map(item => ({ ...item, product: state.products.find(p => p.id === item.id) })).filter(x => x.product);
  $("#cart-items").innerHTML = items.length ? items.map(x => `<div class="cart-line"><img src="${safeImage(x.product.image, x.product.slug)}" onerror="this.onerror=null;this.src='/images/spice-placeholder.svg'" alt=""><div><h3>${escapeHtml(x.product.name)}</h3><small>${escapeHtml(x.product.weight)} · ${money(x.product.price)}</small><div class="qty-control"><button data-qty="${x.id}" data-delta="-1" aria-label="Decrease quantity">−</button><span>${x.qty}</span><button data-qty="${x.id}" data-delta="1" aria-label="Increase quantity" ${x.qty >= Math.min(x.product.stock, 20) ? "disabled" : ""}>+</button></div></div><span class="cart-line-price">${money(x.product.price * x.qty)}<br><button data-remove="${x.id}" class="remove-link" style="border:0;background:none;color:#888;font-size:10px;margin-top:8px">Remove</button></span></div>`).join("") : '<div class="cart-empty">Your bag is waiting for a little flavour. ✳</div>';
  const total = items.reduce((sum, x) => sum + x.product.price * x.qty, 0);
  $("#cart-total").textContent = money(total);
  localStorage.setItem("spiceroot-cart", JSON.stringify(state.cart));
}
function openCart() { $("#cart-drawer").classList.add("open"); $("#cart-drawer").setAttribute("aria-hidden", "false"); $("#drawer-backdrop").classList.add("show"); document.body.classList.add("no-scroll"); }
function closeCart() { $("#cart-drawer").classList.remove("open"); $("#cart-drawer").setAttribute("aria-hidden", "true"); $("#drawer-backdrop").classList.remove("show"); document.body.classList.remove("no-scroll"); }
async function init() {
  try {
    const [config, products] = await Promise.all([api("/api/config"), api("/api/products")]);
    state.csrf = config.csrfToken; state.config = config; state.products = products;
    document.title = `${config.storeName} — Authentic spices for every kitchen`;
    $$(".brand span:nth-child(2)").forEach(el => { el.innerHTML = `${escapeHtml(config.storeName.replace(/Root$/,""))}<span class="brand-light">${config.storeName.endsWith("Root") ? "Root" : ""}</span><small>THE SPICE PANTRY</small>`; });
    $("#year").textContent = new Date().getFullYear();
    renderProducts(); renderCart();
  } catch (err) { $("#product-grid").innerHTML = '<div class="empty-state">We couldn’t load the pantry. Please refresh in a moment.</div>'; }
}
$("#product-grid").addEventListener("click", e => { const b = e.target.closest("[data-add]"); if (b) addToCart(Number(b.dataset.add)); });
$("#category-filters").addEventListener("click", e => { const b = e.target.closest("[data-category]"); if (!b) return; state.category = b.dataset.category; $$(".filter").forEach(x => x.classList.toggle("active", x === b)); renderProducts(); });
$("#search-toggle").addEventListener("click", () => { $("#search-box").classList.toggle("search-open"); $("#search-input").focus(); $("#shop").scrollIntoView({ behavior: "smooth" }); });
$("#search-input").addEventListener("input", e => { state.query = e.target.value.slice(0, 100); renderProducts(); });
$("#cart-open").addEventListener("click", openCart); $("#cart-close").addEventListener("click", closeCart); $("#drawer-backdrop").addEventListener("click", closeCart);
$("#cart-items").addEventListener("click", e => {
  const q = e.target.closest("[data-qty]"); const r = e.target.closest("[data-remove]");
  if (q) {
    const item = state.cart.find(x => x.id === Number(q.dataset.qty)); const p = state.products.find(x => x.id === Number(q.dataset.qty));
    if (!item || !p) return;
    item.qty += Number(q.dataset.delta);
    if (item.qty < 1) state.cart = state.cart.filter(x => x.id !== item.id);
    if (item.qty > Math.min(p.stock, 20)) item.qty = Math.min(p.stock, 20);
    saveCart();
  }
  if (r) { state.cart = state.cart.filter(x => x.id !== Number(r.dataset.remove)); saveCart(); }
});
$("#checkout-open").addEventListener("click", () => {
  if (!state.cart.length) return toast("Add a spice to your bag first.");
  $("#checkout-modal").classList.add("show"); $("#checkout-message").textContent = ""; closeCart(); document.body.classList.add("no-scroll");
});
function closeCheckout() { $("#checkout-modal").classList.remove("show"); document.body.classList.remove("no-scroll"); }
$("#checkout-close").addEventListener("click", closeCheckout);
$("#checkout-modal").addEventListener("click", e => { if (e.target === $("#checkout-modal")) closeCheckout(); });
$("#checkout-form").addEventListener("submit", async e => {
  e.preventDefault();
  const btn = $("#place-order"); const message = $("#checkout-message");
  if (!state.cart.length) { message.textContent = "Your cart is empty."; return; }
  btn.disabled = true; btn.textContent = "Placing order…"; message.textContent = "";
  const f = new FormData(e.currentTarget); const payload = Object.fromEntries(f.entries());
  payload.items = state.cart.map(x => ({ productId: x.id, quantity: x.qty }));
  payload.orderType = String(payload.orderType || "retail"); payload.paymentMethod = "UPI"; payload.couponCode = String(payload.couponCode || "").trim().toUpperCase();
  try {
    const result = await api("/api/orders", { method: "POST", body: JSON.stringify(payload) });
    message.style.color = "#425936"; message.textContent = `${result.message} Order reference: #${result.orderId}. Subtotal ${money(result.subtotal)}, discount ${money(result.discount)}, total ${money(result.total)}.${result.upiId ? " Pay using UPI ID: " + result.upiId + " and mention order #" + result.orderId + "." : " Add your merchant UPI ID in .env to show payment instructions."}`;
    state.cart = []; saveCart(); await api("/api/csrf").then(x => state.csrf = x.csrfToken);
    e.currentTarget.reset(); toast(`Order #${result.orderId} received.`);
    setTimeout(closeCheckout, 3200);
    const products = await api("/api/products"); state.products = products; renderProducts();
  } catch (err) { message.style.color = ""; message.textContent = err.message; }
  finally { btn.disabled = false; btn.innerHTML = 'Place order <span>→</span>'; }
});
$("#menu-toggle").addEventListener("click", () => $(".main-nav").classList.toggle("open"));
$$(".main-nav a").forEach(a => a.addEventListener("click", () => $(".main-nav").classList.remove("open")));
document.addEventListener("keydown", e => { if (e.key === "Escape") { closeCart(); closeCheckout(); } });
init();
