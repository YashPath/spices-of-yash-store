/* Spices of Yash — admin dashboard. */
(() => {
  "use strict";
  const $ = (s, el = document) => el.querySelector(s);
  const $$ = (s, el = document) => [...el.querySelectorAll(s)];
  const money = n => new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: Number.isInteger(+n) ? 0 : 2 }).format(+n || 0);
  const esc = v => String(v ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const STATUSES = ["New", "Confirmed", "Packed", "Shipped", "Delivered", "Cancelled"];
  const LOW = 10;
  const PLACEHOLDER = "/images/spice-placeholder.svg";

  let csrf = "";
  const state = { orders: [], products: [], me: null };

  /* ---------- api + toast ---------- */
  async function api(url, options = {}, retried = false) {
    const headers = { ...(options.body && !(options.body instanceof Blob) ? { "Content-Type": "application/json" } : {}), ...(options.headers || {}) };
    if (options.method && options.method !== "GET") headers["X-CSRF-Token"] = csrf;
    const r = await fetch(url, { ...options, headers, credentials: "same-origin" });
    const data = await r.json().catch(() => ({}));
    if (r.status === 401 && !url.includes("/login") && !url.includes("/me")) { location.reload(); throw new Error("Session expired."); }
    // Security token went stale (new tab, long idle): fetch a fresh one and retry once.
    if (r.status === 403 && !retried && options.method && options.method !== "GET") {
      csrf = (await fetch("/api/csrf", { credentials: "same-origin" }).then(x => x.json()).catch(() => ({}))).csrfToken || csrf;
      return api(url, options, true);
    }
    if (!r.ok) throw new Error(data.error || "Request failed.");
    return data;
  }
  let toastTimer;
  function toast(msg, isError = false) {
    const t = $("#toast");
    t.textContent = msg;
    t.style.background = isError ? "var(--danger)" : "";
    t.classList.add("is-visible");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.classList.remove("is-visible"), 3200);
  }
  const pill = (text, cls = text) => `<span class="pill pill--${esc(String(cls).split(" ")[0])}">${esc(text)}</span>`;
  const fmtDate = s => {
    const d = new Date(String(s).replace(" ", "T") + "Z");
    return isNaN(d) ? esc(s) : d.toLocaleString("en-IN", { day: "numeric", month: "short", hour: "numeric", minute: "2-digit" });
  };

  /* ---------- tabs ---------- */
  function showTab(name) {
    $$("[data-tab]").forEach(b => b.setAttribute("aria-selected", String(b.dataset.tab === name)));
    $$(".tab-panel").forEach(p => { p.hidden = p.id !== `panel-${name}`; });
    try { history.replaceState(null, "", `#${name}`); } catch { /* ignore */ }
  }
  $(".tabs").addEventListener("click", e => { const b = e.target.closest("[data-tab]"); if (b) showTab(b.dataset.tab); });
  document.addEventListener("click", e => { const g = e.target.closest("[data-goto]"); if (g) showTab(g.dataset.goto); });

  /* ---------- overview ---------- */
  async function loadSummary() {
    const s = await api("/api/admin/summary");
    $("#stat-products").textContent = s.products;
    $("#stat-orders").textContent = s.orders;
    $("#stat-revenue").textContent = money(s.revenue);
    $("#stat-pending").textContent = s.pending;
    $("#stat-pending").closest(".stat").classList.toggle("stat--alert", s.pending > 0);
    $("#stat-lowstock").innerHTML = s.lowStock ? `<span class="warn">${s.lowStock} low on stock</span>` : "All well stocked";
    $("#tab-orders-count").textContent = s.pending || "";
    $("#tab-products-count").textContent = s.lowStock || "";
  }
  function renderHealth() {
    const me = state.me || {};
    const items = [];
    items.push(me.database === "postgres"
      ? `<li><div><strong>Database: Postgres</strong><p>Orders are stored safely and survive redeploys.</p></div></li>`
      : `<li class="is-warn"><div><strong>Database: local SQLite file</strong><p>Fine on your computer. On Render, set <code>DATABASE_URL</code> to a Postgres database so orders aren’t wiped on redeploy.</p></div></li>`);
    items.push(me.alertsConfigured
      ? `<li><div><strong>Order alerts: Telegram on</strong><p>You get a message for every new order.</p><button class="btn btn--outline btn--sm" type="button" id="test-alert">Send test alert</button></div></li>`
      : `<li class="is-warn"><div><strong>Order alerts: off</strong><p>Add <code>TELEGRAM_BOT_TOKEN</code> and <code>TELEGRAM_CHAT_ID</code> to get a phone alert for every order. See the README.</p></div></li>`);
    const missingPhoto = state.products.filter(p => p.active && !p.image).length;
    items.push(missingPhoto
      ? `<li class="is-warn"><div><strong>${missingPhoto} product${missingPhoto > 1 ? "s" : ""} without a photo</strong><p>Upload one from the Products tab.</p></div></li>`
      : `<li><div><strong>Every active product has a photo</strong></div></li>`);
    $("#health-list").innerHTML = items.join("");
  }
  function renderOverview() {
    const recent = state.orders.slice(0, 6);
    $("#recent-orders").innerHTML = recent.length
      ? `<ul class="mini-list">${recent.map(o => `<li><span><strong>#${o.id}</strong> ${esc(o.customer_name)} <span class="muted">· ${fmtDate(o.created_at)}</span></span><span>${pill(o.status)} <strong>${money(o.total)}</strong></span></li>`).join("")}</ul>`
      : `<p class="muted">No orders yet. New orders appear here.</p>`;
    const low = state.products.filter(p => p.active && p.stock <= LOW).sort((a, b) => a.stock - b.stock);
    $("#low-stock-list").innerHTML = low.length
      ? low.map(p => `<li><span>${esc(p.name)}</span><strong class="${p.stock === 0 ? "warn" : ""}">${p.stock === 0 ? "Sold out" : `${p.stock} left`}</strong></li>`).join("")
      : `<li class="muted">All active products have more than ${LOW} units.</li>`;
    renderHealth();
  }

  /* ---------- orders ---------- */
  function filteredOrders() {
    const q = $("#order-search").value.trim().toLowerCase().replace(/^#/, "");
    const st = $("#order-status-filter").value;
    const pay = $("#order-pay-filter").value;
    return state.orders.filter(o =>
      (!st || o.status === st) &&
      (!pay || (o.payment_status || "Pending verification") === pay) &&
      (!q || String(o.id) === q || `${o.customer_name} ${o.phone} ${o.city} ${o.pincode} ${o.business_name}`.toLowerCase().includes(q)));
  }
  function orderCard(o) {
    const pay = o.payment_status || "Pending verification";
    const subtotal = o.items.reduce((s, i) => s + i.unit_price * i.quantity, 0);
    const wa = `https://wa.me/91${esc(o.phone)}?text=${encodeURIComponent(`Hi ${o.customer_name}, this is Spices of Yash about your order #${o.id}.`)}`;
    return `<article class="order">
      <div class="order__head">
        <div class="order__title"><strong>#${o.id} · ${esc(o.customer_name)}</strong><small>${fmtDate(o.created_at)}</small></div>
        <div class="order__pills">${o.order_type === "wholesale" ? pill("Wholesale", "type") : ""}${pill(o.status)}${pill(pay === "Pending verification" ? "Payment pending" : `Payment ${pay.toLowerCase()}`, pay === "Pending verification" ? "Pending" : pay)}<span class="order__total">${money(o.total)}</span></div>
      </div>
      <div class="order__body">
        <div class="order__info">
          <span><a href="tel:${esc(o.phone)}">${esc(o.phone)}</a> · <a href="${wa}" target="_blank" rel="noopener">WhatsApp</a>${o.email ? ` · ${esc(o.email)}` : ""}</span>
          <span>${esc(o.address)}, ${esc(o.city)} — ${esc(o.pincode)}</span>
          ${o.business_name ? `<span>Business: <strong>${esc(o.business_name)}</strong></span>` : ""}
          ${o.notes ? `<span>Note: “${esc(o.notes)}”</span>` : ""}
        </div>
        <table class="order__items"><tbody>
          ${o.items.map(i => `<tr><td>${esc(i.product_name)} × ${i.quantity}</td><td>${money(i.unit_price * i.quantity)}</td></tr>`).join("")}
          <tr class="sum"><td>Subtotal</td><td>${money(subtotal)}</td></tr>
          ${o.discount ? `<tr class="sum"><td>Coupon ${esc(o.coupon_code)}</td><td>− ${money(o.discount)}</td></tr>` : ""}
          <tr class="sum"><td>Delivery</td><td>${o.delivery_fee ? money(o.delivery_fee) : "Free"}</td></tr>
          <tr class="total"><td>Total</td><td>${money(o.total)}</td></tr>
        </tbody></table>
      </div>
      <div class="order__actions">
        <label class="sr-only" for="status-${o.id}">Order status</label>
        <select id="status-${o.id}" data-status="${o.id}">${STATUSES.map(s => `<option ${s === o.status ? "selected" : ""}>${s}</option>`).join("")}</select>
        <button class="btn btn--dark btn--sm" type="button" data-save-order="${o.id}">Update status</button>
        <span class="spacer"></span>
        ${pay !== "Paid" ? `<button class="btn btn--outline btn--sm" type="button" data-verify-payment="${o.id}">Mark UPI payment received</button>` : `<span class="muted">Payment verified</span>`}
      </div>
    </article>`;
  }
  function renderOrders() {
    const list = filteredOrders();
    $("#orders-count").textContent = `${list.length} of ${state.orders.length} orders`;
    $("#orders-list").innerHTML = list.length ? list.map(orderCard).join("")
      : `<div class="empty">${state.orders.length ? "No orders match these filters." : "No orders yet. New customer orders will appear here."}</div>`;
  }
  async function loadOrders() { state.orders = await api("/api/admin/orders"); renderOrders(); }
  ["#order-search", "#order-status-filter", "#order-pay-filter"].forEach(s => $(s).addEventListener("input", renderOrders));

  /* ---------- products ---------- */
  function invRow(p) {
    const img = p.image || PLACEHOLDER;
    return `<div class="inv-row${p.active ? "" : " is-inactive"}" data-row="${p.id}">
      <div class="inv-photo"><img src="${esc(img)}" alt="" width="64" height="80" loading="lazy"><label>Change<input type="file" accept="image/jpeg,image/png,image/webp" data-photo="${p.id}" aria-label="Change photo for ${esc(p.name)}"></label></div>
      <div class="inv-name"><strong>${esc(p.name)}</strong><span>${esc(p.category)} · ${esc(p.weight)}</span></div>
      <label class="field f-price">Retail ₹<input type="number" min="0.01" max="100000" step="0.01" value="${p.price}" data-price="${p.id}"></label>
      <label class="field f-stock">Stock<input type="number" min="0" max="100000" step="1" value="${p.stock}" data-stock="${p.id}" class="${p.stock <= LOW ? "is-low" : ""}"></label>
      <label class="field f-wholesale">Wholesale ₹<input type="number" min="0" max="100000" step="0.01" value="${p.wholesale_price}" data-wholesale="${p.id}"></label>
      <label class="field f-minqty">Min qty<input type="number" min="2" max="100000" step="1" value="${p.wholesale_min_qty}" data-minqty="${p.id}"></label>
      <div class="inv-toggles"><label><input type="checkbox" data-active="${p.id}" ${p.active ? "checked" : ""}> Active</label><label><input type="checkbox" data-featured="${p.id}" ${p.featured ? "checked" : ""}> Favourite</label></div>
      <button class="btn btn--dark btn--sm inv-save" type="button" data-save-product="${p.id}">Save</button>
    </div>`;
  }
  function renderInventory() {
    $("#inventory-list").innerHTML = state.products.length ? state.products.map(invRow).join("") : `<div class="empty">No products yet. Add your first one above.</div>`;
  }
  async function loadProducts() { state.products = await api("/api/admin/products"); renderInventory(); }

  async function uploadImage(file) {
    if (!file) throw new Error("Choose an image first.");
    if (!["image/jpeg", "image/png", "image/webp"].includes(file.type)) throw new Error("Use a JPG, PNG or WebP image.");
    if (file.size > 8 * 1024 * 1024) throw new Error("Image is larger than 8 MB.");
    return api("/api/admin/images", { method: "POST", headers: { "Content-Type": file.type }, body: file });
  }

  $("#np-file").addEventListener("change", async e => {
    const msg = $("#product-message");
    msg.className = "form-note"; msg.textContent = "Uploading photo…";
    try {
      const r = await uploadImage(e.target.files[0]);
      $("#np-image").value = r.url;
      $("#np-preview").src = r.url;
      msg.className = "form-note is-ok"; msg.textContent = `Photo uploaded (${Math.round(r.bytes / 1024)} KB).`;
    } catch (err) { msg.className = "form-note is-error"; msg.textContent = err.message; }
    e.target.value = "";
  });

  $("#product-form").addEventListener("submit", async e => {
    e.preventDefault();
    const form = e.currentTarget, btn = form.querySelector("button[type=submit]"), msg = $("#product-message");
    const f = new FormData(form);
    const payload = { name: f.get("name"), category: f.get("category"), description: f.get("description"), price: Number(f.get("price")), weight: f.get("weight"), image: f.get("image"), stock: Number(f.get("stock")), wholesale_price: Number(f.get("wholesale_price")), wholesale_min_qty: Number(f.get("wholesale_min_qty")), featured: f.get("featured") === "on" };
    btn.disabled = true;
    try {
      await api("/api/admin/products", { method: "POST", body: JSON.stringify(payload) });
      form.reset(); $("#np-stock").value = 25; $("#np-image").value = ""; $("#np-preview").src = PLACEHOLDER;
      msg.className = "form-note is-ok"; msg.textContent = "";
      toast(`${payload.name} added to the store`);
      $("#add-product").open = false;
      await refreshAll();
    } catch (err) { msg.className = "form-note is-error"; msg.textContent = err.message; }
    finally { btn.disabled = false; }
  });

  $("#inventory-list").addEventListener("change", async e => {
    const input = e.target.closest("[data-photo]");
    if (!input) return;
    const id = input.dataset.photo;
    try {
      toast("Uploading photo…");
      const r = await uploadImage(input.files[0]);
      await api(`/api/admin/products/${id}`, { method: "PATCH", body: JSON.stringify({ image: r.url }) });
      toast("Photo updated");
      await loadProducts(); renderHealth();
    } catch (err) { toast(err.message, true); }
  });

  /* ---------- actions ---------- */
  $("#dashboard").addEventListener("click", async e => {
    const order = e.target.closest("[data-save-order]");
    const product = e.target.closest("[data-save-product]");
    const payment = e.target.closest("[data-verify-payment]");
    const coupon = e.target.closest("[data-coupon-toggle]");
    const testAlert = e.target.closest("#test-alert");
    try {
      if (order) {
        const id = order.dataset.saveOrder;
        await api(`/api/admin/orders/${id}`, { method: "PATCH", body: JSON.stringify({ status: $(`[data-status="${id}"]`).value }) });
        toast(`Order #${id} updated`);
      } else if (product) {
        const id = product.dataset.saveProduct;
        const num = k => Number($(`[data-${k}="${id}"]`).value);
        const body = { price: num("price"), stock: num("stock"), wholesale_price: num("wholesale"), wholesale_min_qty: num("minqty"), active: $(`[data-active="${id}"]`).checked, featured: $(`[data-featured="${id}"]`).checked };
        if (!Number.isFinite(body.price) || body.price <= 0) throw new Error("Retail price must be greater than zero.");
        if (!Number.isInteger(body.stock) || body.stock < 0) throw new Error("Stock must be a whole number, 0 or more.");
        if (!Number.isFinite(body.wholesale_price) || body.wholesale_price < 0) throw new Error("Wholesale price cannot be negative.");
        if (!Number.isInteger(body.wholesale_min_qty) || body.wholesale_min_qty < 2) throw new Error("Wholesale minimum must be at least 2 units.");
        await api(`/api/admin/products/${id}`, { method: "PATCH", body: JSON.stringify(body) });
        toast("Product saved");
      } else if (payment) {
        if (!confirm("Only continue after you have checked this payment in your bank or UPI app. Mark it as received?")) return;
        await api(`/api/admin/orders/${payment.dataset.verifyPayment}/payment`, { method: "PATCH", body: JSON.stringify({ paymentStatus: "Paid" }) });
        toast(`Payment for order #${payment.dataset.verifyPayment} marked as received`);
      } else if (coupon) {
        await api(`/api/admin/coupons/${coupon.dataset.couponToggle}`, { method: "PATCH", body: JSON.stringify({ active: coupon.dataset.active === "1" }) });
        toast("Coupon updated");
        return loadCoupons();
      } else if (testAlert) {
        const r = await api("/api/admin/test-alert", { method: "POST", body: "{}" });
        return toast(r.message);
      } else return;
      await refreshAll();
    } catch (err) { toast(err.message, true); }
  });

  /* ---------- coupons ---------- */
  async function loadCoupons() {
    try {
      const items = await api("/api/admin/coupons");
      $("#coupons-list").innerHTML = items.map(c => `<div class="coupon">
        <div><code>${esc(c.code)}</code> ${pill(c.active ? "Active" : "Inactive", c.active ? "Paid" : "Refunded")}
          <p>${c.discount_type === "percent" ? `${c.discount_value}% off` : `${money(c.discount_value)} off`} · min order ${money(c.min_order)} · ${c.expires_at ? `expires ${esc(c.expires_at)}` : "no expiry"}</p></div>
        <button class="btn btn--outline btn--sm" type="button" data-coupon-toggle="${c.id}" data-active="${c.active ? 0 : 1}">${c.active ? "Turn off" : "Turn on"}</button>
      </div>`).join("") || `<div class="empty">No coupons yet.</div>`;
    } catch (e) { $("#coupons-list").textContent = e.message; }
  }
  $("#coupon-form").addEventListener("submit", async e => {
    e.preventDefault();
    const form = e.currentTarget, f = new FormData(form), m = $("#coupon-message");
    try {
      await api("/api/admin/coupons", { method: "POST", body: JSON.stringify({ code: f.get("code"), discountType: f.get("discountType"), discountValue: Number(f.get("discountValue")), minOrder: Number(f.get("minOrder")), expiresAt: f.get("expiresAt") }) });
      m.className = "form-note is-ok"; m.textContent = "Coupon created.";
      form.reset(); await loadCoupons();
    } catch (err) { m.className = "form-note is-error"; m.textContent = err.message; }
  });
  $("#refresh-coupons").addEventListener("click", loadCoupons);

  /* ---------- reports ---------- */
  async function loadReports() {
    try {
      const r = await api("/api/admin/reports");
      const maxUnits = Math.max(1, ...r.bestSellers.map(x => x.units));
      $("#reports-content").innerHTML = `
        <section class="panel panel--wide"><div class="panel__head"><h2>Monthly orders &amp; paid revenue</h2></div>
          <div class="data-table-wrap"><table class="data-table"><thead><tr><th>Month</th><th class="num">Orders</th><th class="num">Paid orders</th><th class="num">Paid revenue</th></tr></thead>
          <tbody>${r.monthly.map(x => `<tr><td>${esc(x.month)}</td><td class="num">${x.orders}</td><td class="num">${x.paidOrders}</td><td class="num"><strong>${money(x.revenue)}</strong></td></tr>`).join("") || `<tr><td colspan="4" class="muted">No orders yet.</td></tr>`}</tbody></table></div></section>
        <section class="panel"><div class="panel__head"><h2>Best sellers</h2></div>
          <div class="data-table-wrap"><table class="data-table"><thead><tr><th>Product</th><th>Units</th><th class="num">Gross</th></tr></thead>
          <tbody>${r.bestSellers.map(x => `<tr><td>${esc(x.name)}</td><td><div class="bar" title="${x.units} units"><span style="width:${(x.units / maxUnits) * 100}%"></span></div> ${x.units}</td><td class="num">${money(x.gross)}</td></tr>`).join("") || `<tr><td colspan="3" class="muted">No sales yet.</td></tr>`}</tbody></table></div></section>
        <section class="panel"><div class="panel__head"><h2>Payments</h2></div>
          <ul class="mini-list">${r.payments.map(x => `<li><span>${esc(x.status)}</span><strong>${x.count}</strong></li>`).join("") || `<li class="muted">No orders yet.</li>`}</ul></section>`;
    } catch (e) { $("#reports-content").textContent = e.message; }
  }

  /* ---------- boot ---------- */
  async function refreshAll() {
    await Promise.all([loadSummary(), loadOrders(), loadProducts()]);
    renderOverview();
    loadReports();
  }
  $("#refresh-orders").addEventListener("click", () => loadOrders().then(renderOverview).catch(err => toast(err.message, true)));
  $("#refresh-products").addEventListener("click", () => loadProducts().then(renderOverview).catch(err => toast(err.message, true)));

  async function showDashboard(me) {
    state.me = me;
    csrf = me.csrfToken;
    $("#login-panel").hidden = true;
    $("#dashboard").hidden = false;
    $("#admin-actions").hidden = false;
    $("#admin-user").textContent = `Signed in as ${me.username}`;
    const tab = (location.hash || "").slice(1);
    showTab(["overview", "orders", "products", "coupons", "reports"].includes(tab) ? tab : "overview");
    try { await refreshAll(); loadCoupons(); } catch (err) { toast(err.message, true); }
  }

  $("#login-form").addEventListener("submit", async e => {
    e.preventDefault();
    const btn = e.currentTarget.querySelector("button");
    btn.disabled = true; $("#login-error").textContent = "";
    try {
      const f = new FormData(e.currentTarget);
      if (!csrf) csrf = (await api("/api/csrf")).csrfToken; // signed in before the page finished loading
      await api("/api/admin/login", { method: "POST", body: JSON.stringify({ username: f.get("username"), password: f.get("password") }) });
      showDashboard(await api("/api/admin/me"));
    } catch (err) {
      $("#login-error").textContent = err.message;
      try { csrf = (await api("/api/csrf")).csrfToken; } catch { /* ignore */ }
    } finally { btn.disabled = false; }
  });
  $("#logout").addEventListener("click", async () => {
    try { await api("/api/admin/logout", { method: "POST", body: "{}" }); } catch { /* ignore */ }
    location.href = "/admin";
  });

  (async () => {
    try {
      const me = await api("/api/admin/me");
      if (me.loggedIn) showDashboard(me); else csrf = me.csrfToken;
    } catch { try { csrf = (await api("/api/csrf")).csrfToken; } catch { /* ignore */ } }
  })();
})();
