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
  // Always use bundled, high-quality local product photography first.
  // This avoids broken/blocked remote URLs and the old illustrated SVGs.
  const key = String(slug || "");
  if (LOCAL_SPICE_IMAGES.has(key)) return `/images/${key}.webp`;
  return "/images/spice-placeholder.svg";
}
function attachImageFallbacks(container) {
  container.querySelectorAll("img[data-slug]").forEach(img => {
    img.addEventListener("error", function onImageError() {
      if (!img.dataset.fallback) {
        img.dataset.fallback = "1";
        const slug = img.dataset.slug;
        img.src = LOCAL_SPICE_IMAGES.has(slug) ? `/images/${slug}.svg` : "/images/spice-placeholder.svg";
      } else {
        img.removeEventListener("error", onImageError);
        img.src = "/images/spice-placeholder.svg";
      }
    });
  });
}
function renderProducts() {
  const priority = new Map([["garam-masala",0],["golden-turmeric",1],["green-cardamom",2],["kashmiri-red-chilli",3],["black-peppercorns",4],["cumin-seeds",5]]);
  const products = state.products.filter(p => (state.category === "All" || p.category === state.category) && `${p.name} ${p.category} ${p.description}`.toLowerCase().includes(state.query.toLowerCase())).sort((a,b) => (priority.get(a.slug) ?? 99) - (priority.get(b.slug) ?? 99));
  const grid = $("#product-grid");
  if (!products.length) { grid.innerHTML = '<div class="empty-state">No spices found. Try another search.</div>'; return; }
  grid.innerHTML = products.map(p => `<article class="product-card"><div class="product-image-wrap"><img class="product-image" src="${safeImage(p.image, p.slug)}" data-slug="${escapeHtml(p.slug)}" alt="${escapeHtml(p.name)}" loading="lazy"><span class="product-tag">${p.featured ? "PANTRY FAVOURITE" : escapeHtml(p.category)}</span><button class="add-btn" data-add="${p.id}" aria-label="Add ${escapeHtml(p.name)} to bag" ${p.stock < 1 ? "disabled" : ""}>${p.stock < 1 ? "×" : "+"}<span class="add-label">${p.stock < 1 ? "Sold out" : "Add to bag"}</span></button></div><div class="product-meta"><div><h3>${escapeHtml(p.name)}</h3><p>${escapeHtml(p.weight)} · ${p.stock > 0 ? "In stock" : "Sold out"}</p></div><span class="product-price">${money(p.price)}</span></div><p class="wholesale-hint">Bulk: ${p.wholesale_price > 0 ? money(p.wholesale_price) + " / unit from " + p.wholesale_min_qty : "Ask us for a quote"}</p><p class="product-desc">${escapeHtml(p.description)}</p></article>`).join("");
  attachImageFallbacks(grid);
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
  $("#cart-items").innerHTML = items.length ? items.map(x => `<div class="cart-line"><img src="${safeImage(x.product.image, x.product.slug)}" data-slug="${escapeHtml(x.product.slug)}" alt=""><div><h3>${escapeHtml(x.product.name)}</h3><small>${escapeHtml(x.product.weight)} · ${money(x.product.price)}</small><div class="qty-control"><button data-qty="${x.id}" data-delta="-1" aria-label="Decrease quantity">−</button><span>${x.qty}</span><button data-qty="${x.id}" data-delta="1" aria-label="Increase quantity" ${x.qty >= Math.min(x.product.stock, 20) ? "disabled" : ""}>+</button></div></div><span class="cart-line-price">${money(x.product.price * x.qty)}<br><button data-remove="${x.id}" class="remove-link" style="border:0;background:none;color:#888;font-size:10px;margin-top:8px">Remove</button></span></div>`).join("") : '<div class="cart-empty">Your bag is waiting for a little flavour. ✳</div>';
  attachImageFallbacks($("#cart-items"));
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
    const rpOption = $("#razorpay-option"); if (rpOption) rpOption.hidden = !config.razorpayEnabled;
    const paymentHelp = $("#payment-help"); if (paymentHelp && config.razorpayEnabled) paymentHelp.textContent = "Secure checkout opens with Razorpay. Payment is confirmed only after server-side signature verification.";
    document.title = `${config.storeName} — Authentic spices for every kitchen`;
    $$(".brand span:nth-child(2)").forEach(el => { el.innerHTML = `${escapeHtml(config.storeName.replace(/Root$/,""))}<span class="brand-light">${config.storeName.endsWith("Root") ? "Root" : ""}</span><small>THE SPICE PANTRY</small>`; });
    $("#year").textContent = new Date().getFullYear();
    renderProducts(); renderCart(); $("#product-grid").setAttribute("aria-busy", "false");
  } catch (err) { $("#product-grid").setAttribute("aria-busy", "false"); $("#product-grid").innerHTML = '<div class="empty-state">We couldn’t load the pantry. Please refresh in a moment.</div>'; }
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
  const form = e.currentTarget;
  const btn = $("#place-order"); const message = $("#checkout-message");
  if (!state.cart.length) { message.textContent = "Your cart is empty."; return; }
  btn.disabled = true; btn.textContent = "Placing order…"; message.textContent = "";
  const f = new FormData(form); const payload = Object.fromEntries(f.entries());
  payload.items = state.cart.map(x => ({ productId: x.id, quantity: x.qty }));
  payload.orderType = String(payload.orderType || "retail"); payload.paymentMethod = String(payload.paymentMethod || "UPI"); payload.couponCode = String(payload.couponCode || "").trim().toUpperCase();
  try {
    if (payload.paymentMethod === "Razorpay" && typeof window.Razorpay !== "function") throw new Error("Online checkout did not load. Refresh or choose manual UPI; no order has been placed.");
    const result = await api("/api/orders", { method: "POST", body: JSON.stringify(payload) });
    if (result.paymentMethod === "Razorpay") {
      if (!state.config.razorpayEnabled) throw new Error("Online payments are not configured. Your order may be pending; contact the store before retrying.");
      const gateway = await api("/api/payments/razorpay/order", { method: "POST", body: JSON.stringify({ orderId: result.orderId, paymentToken: result.paymentToken }) });
      if (typeof window.Razorpay !== "function") throw new Error("Payment checkout could not load. Your order is saved as pending; contact the store before retrying.");
      const checkout = new window.Razorpay({
        key: gateway.keyId, order_id: gateway.gatewayOrderId, amount: gateway.amount, currency: gateway.currency,
        name: state.config.storeName || "Spices of Yash", description: `Order #${result.orderId}`, image: "/images/hero-spices.webp",
        prefill: { name: payload.name, email: payload.email, contact: payload.phone },
        notes: { store_order_id: String(result.orderId) },
        theme: { color: "#303923" },
        handler: async function (response) {
          try {
            const verified = await api("/api/payments/razorpay/verify", { method: "POST", body: JSON.stringify({ orderId: result.orderId, paymentToken: result.paymentToken, ...response }) });
            message.style.color = "#425936"; message.textContent = `Payment verified. Order #${verified.orderId} is confirmed as paid. Keep this order reference for support.`;
            state.cart = []; saveCart(); form.reset(); toast(`Payment successful for order #${verified.orderId}.`);
            setTimeout(closeCheckout, 4500);
            const products = await api("/api/products"); state.products = products; renderProducts();
          } catch (err) { message.style.color = ""; message.textContent = `Payment may have completed, but verification did not finish: ${err.message} Keep order #${result.orderId} and contact the store. Do not pay again until checked.`; }
        },
        modal: { ondismiss: () => { message.textContent = `Payment window closed. Order #${result.orderId} remains pending. You can contact the store before retrying.`; } }
      });
      checkout.open();
      return;
    }
    message.style.color = "#425936"; message.textContent = `${result.message} Order reference: #${result.orderId}. Subtotal ${money(result.subtotal)}, discount ${money(result.discount)}, total ${money(result.total)}.${result.upiId ? " Pay using UPI ID: " + result.upiId + " and mention order #" + result.orderId + "." : " Add your merchant UPI ID in .env to show payment instructions."}`;
    state.cart = []; saveCart(); await api("/api/csrf").then(x => state.csrf = x.csrfToken);
    form.reset(); toast(`Order #${result.orderId} received.`);
    setTimeout(closeCheckout, 4200);
    const products = await api("/api/products"); state.products = products; renderProducts();
  } catch (err) { message.style.color = ""; message.textContent = err.message; }
  finally { btn.disabled = false; btn.innerHTML = 'Place order <span>→</span>'; }
});
$("#menu-toggle").addEventListener("click", () => $(".main-nav").classList.toggle("open"));
$$(".main-nav a").forEach(a => a.addEventListener("click", () => $(".main-nav").classList.remove("open")));
document.addEventListener("keydown", e => { if (e.key === "Escape") { closeCart(); closeCheckout(); } });
init();


// Subtle 3D depth and scroll reveals; reduced-motion preferences are respected in CSS.
(function addMotion() {
  const reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (reduce) return;
  document.documentElement.classList.add("motion-ready");
  const targets = [".trust-strip > div", ".section-heading", ".product-card", ".story-image", ".story-copy", ".promise-grid article", ".newsletter"].flatMap(sel => [...document.querySelectorAll(sel)]);
  targets.forEach((el, i) => { el.classList.add("reveal-on-scroll"); el.style.setProperty("--reveal-delay", `${(i % 4) * 65}ms`); });
  if ("IntersectionObserver" in window) {
    const observer = new IntersectionObserver(entries => entries.forEach(entry => { if (entry.isIntersecting) { entry.target.classList.add("is-visible"); observer.unobserve(entry.target); } }), { threshold: 0.12 });
    targets.forEach(el => observer.observe(el));
  } else targets.forEach(el => el.classList.add("is-visible"));
  const art = document.querySelector(".hero-art");
  if (art && window.matchMedia("(pointer:fine)").matches) {
    art.addEventListener("pointermove", e => { const r = art.getBoundingClientRect(); const x = (e.clientX-r.left)/r.width-.5; const y = (e.clientY-r.top)/r.height-.5; art.style.setProperty("--tilt-x", `${-y*3}deg`); art.style.setProperty("--tilt-y", `${x*4}deg`); });
    art.addEventListener("pointerleave", () => { art.style.setProperty("--tilt-x", "0deg"); art.style.setProperty("--tilt-y", "0deg"); });
  }
})();
