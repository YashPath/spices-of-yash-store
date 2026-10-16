/* Spices of Yash — storefront logic (catalogue, cart, quick view, checkout). */
(() => {
  "use strict";

  const $ = (s, el = document) => el.querySelector(s);
  const $$ = (s, el = document) => [...el.querySelectorAll(s)];
  const money = n => new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: Number.isInteger(+n) ? 0 : 2 }).format(+n || 0);
  const esc = v => String(v ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const icon = id => `<svg aria-hidden="true"><use href="#i-${id}"/></svg>`;
  const MAX_QTY = 20; // server limit per line
  const CART_KEY = "soy-cart-v2";
  const PLACEHOLDER = "/images/spice-placeholder.svg";

  const state = {
    products: [],
    bySlug: new Map(),
    byId: new Map(),
    cart: new Map(), // id -> qty
    category: "all",
    query: "",
    config: { freeDeliveryMin: 799, deliveryFee: 49, whatsapp: "", social: {} },
    csrf: "",
    quickId: null
  };

  /* ---------- storage (best effort) ---------- */
  function loadCart() {
    try {
      const raw = JSON.parse(localStorage.getItem(CART_KEY) || "[]");
      if (Array.isArray(raw)) raw.forEach(([id, q]) => { if (Number.isInteger(id) && q > 0) state.cart.set(id, Math.min(q, MAX_QTY)); });
    } catch { /* storage unavailable */ }
  }
  function saveCart() {
    try { localStorage.setItem(CART_KEY, JSON.stringify([...state.cart])); } catch { /* ignore */ }
  }

  /* ---------- api ---------- */
  async function getJSON(url) {
    const r = await fetch(url, { credentials: "same-origin" });
    if (!r.ok) throw new Error("Request failed");
    return r.json();
  }
  async function refreshCsrf() {
    const d = await getJSON("/api/csrf");
    state.csrf = d.csrfToken || "";
  }
  async function postOrder(payload, retry = true) {
    const r = await fetch("/api/orders", {
      method: "POST", credentials: "same-origin",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": state.csrf },
      body: JSON.stringify(payload)
    });
    const data = await r.json().catch(() => ({}));
    if (r.status === 403 && retry) { await refreshCsrf(); return postOrder(payload, false); }
    if (!r.ok) throw new Error(data.error || "Could not place your order. Please try again.");
    return data;
  }

  /* ---------- toast ---------- */
  let toastTimer;
  function toast(msg) {
    const t = $("#toast");
    t.textContent = msg;
    t.classList.add("is-visible");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.classList.remove("is-visible"), 2600);
  }

  /* ---------- dialogs ---------- */
  function openDialog(d) {
    if (!d.open) d.showModal();
    document.body.classList.add("has-dialog");
  }
  function closeDialog(d) { if (d.open) d.close(); }
  $$("dialog").forEach(d => {
    d.addEventListener("close", () => { if (!$$("dialog").some(x => x.open)) document.body.classList.remove("has-dialog"); });
    d.addEventListener("click", e => {
      if (e.target === d) closeDialog(d); // backdrop click
      if (e.target.closest("[data-close]")) closeDialog(d);
    });
  });

  /* ---------- catalogue ---------- */
  const imgOf = p => p.image || PLACEHOLDER;
  // Bundled photos have a 600px copy (name-600.webp) for product cards.
  const srcsetOf = src => (/^\/images\/[a-z0-9-]+\.webp$/.test(src) ? ` srcset="${src.replace(".webp", "-600.webp")} 600w, ${src} 836w" sizes="(max-width: 600px) 50vw, (max-width: 900px) 45vw, 380px"` : "");
  const stockLabel = p => p.stock <= 0 ? "Sold out" : p.stock <= 10 ? `Only ${p.stock} left` : "In stock";
  const maxFor = p => Math.max(0, Math.min(MAX_QTY, p.stock));

  function renderChips() {
    const cats = [...new Set(state.products.map(p => p.category))];
    const wrap = $("#category-chips");
    wrap.innerHTML = [["all", "All spices"], ...cats.map(c => [c, c])]
      .map(([v, label]) => `<button class="chip${v === state.category ? " is-active" : ""}" type="button" data-category="${esc(v)}" aria-pressed="${v === state.category}">${esc(label)}</button>`).join("");
  }

  function filtered() {
    const q = state.query.trim().toLowerCase();
    return state.products.filter(p =>
      (state.category === "all" || p.category === state.category) &&
      (!q || `${p.name} ${p.category} ${p.description}`.toLowerCase().includes(q)));
  }

  function productCard(p, i) {
    const sold = p.stock <= 0;
    const bulk = p.wholesale_price > 0 ? `<span class="product-card__bulk">Bulk ${money(p.wholesale_price)} · ${p.wholesale_min_qty}+ units</span>` : "<span></span>";
    return `<article class="product-card" style="--i:${i}">
      <button class="product-card__media" type="button" data-quick="${p.id}" aria-label="Quick view ${esc(p.name)}">
        <img src="${esc(imgOf(p))}"${srcsetOf(imgOf(p))} alt="${esc(p.name)}" width="836" height="1045" loading="lazy" decoding="async">
        <span class="product-card__badge${p.featured ? " product-card__badge--fav" : ""}">${p.featured ? "Pantry favourite" : esc(p.category)}</span>
        <span class="product-card__view">Quick view</span>
      </button>
      <div class="product-card__body">
        <div class="product-card__top"><h3 class="product-card__name">${esc(p.name)}</h3><span class="product-card__price">${money(p.price)}</span></div>
        <p class="product-card__meta"><span>${esc(p.weight)}</span><span class="${p.stock <= 10 ? "low" : ""}">${stockLabel(p)}</span></p>
        <p class="product-card__desc">${esc(p.description)}</p>
        <div class="product-card__foot">${bulk}
          <button class="btn btn--dark btn--sm" type="button" data-add="${p.id}" ${sold ? "disabled" : ""}>${sold ? "Sold out" : `Add ${icon("plus")}`}</button>
        </div>
      </div>
    </article>`;
  }

  function renderProducts() {
    const list = filtered();
    const grid = $("#product-grid");
    grid.setAttribute("aria-busy", "false");
    grid.innerHTML = list.map(productCard).join("");
    $("#empty-state").hidden = list.length > 0;
    grid.hidden = list.length === 0;
    const total = state.products.length;
    $("#shop-count").textContent = list.length === total ? `${total} spices` : `Showing ${list.length} of ${total} spices`;
    $$("#category-chips .chip").forEach(c => {
      const on = c.dataset.category === state.category;
      c.classList.toggle("is-active", on);
      c.setAttribute("aria-pressed", String(on));
    });
  }

  function renderFeature() {
    const p = state.products.find(x => x.featured && x.stock > 0) || state.products[0];
    if (!p) return;
    $("#feature-img").src = imgOf(p);
    $("#feature-img").alt = p.name;
    $("#feature-name").textContent = p.name;
    $("#feature-weight").textContent = p.weight;
    $("#feature-price").textContent = money(p.price);
    const card = $("#feature-card");
    card.dataset.quick = p.id;
    card.setAttribute("aria-label", `Quick view ${p.name}, ${money(p.price)}`);
    card.hidden = false;
    $("#hero-count").textContent = state.products.length;
  }

  function renderPriceTable() {
    const rows = state.products.filter(p => p.wholesale_price > 0);
    $("#price-table-body").innerHTML = rows.length
      ? rows.map(p => `<tr><td>${esc(p.name)} <span class="muted">(${esc(p.weight)})</span></td><td>${money(p.price)}</td><td>${money(p.wholesale_price)}</td><td>${p.wholesale_min_qty}</td></tr>`).join("")
      : `<tr><td colspan="4">Bulk prices available on request.</td></tr>`;
  }

  /* ---------- quick view ---------- */
  function openQuick(id) {
    const p = state.byId.get(+id);
    if (!p) return;
    state.quickId = p.id;
    $("#qv-img").src = imgOf(p);
    $("#qv-img").alt = p.name;
    $("#qv-category").textContent = p.category;
    $("#qv-name").textContent = p.name;
    $("#qv-price").textContent = money(p.price);
    $("#qv-weight").textContent = `/ ${p.weight}`;
    $("#qv-desc").textContent = p.description;
    $("#qv-pack").textContent = p.weight;
    $("#qv-bulk").textContent = p.wholesale_price > 0 ? `${money(p.wholesale_price)} (${p.wholesale_min_qty}+)` : "On request";
    $("#qv-stock").textContent = stockLabel(p);
    const qty = $("#qv-qty");
    qty.max = String(Math.max(1, maxFor(p)));
    qty.value = "1";
    const add = $("#qv-add");
    add.disabled = p.stock <= 0;
    add.innerHTML = p.stock <= 0 ? "Sold out" : `Add to bag ${icon("bag")}`;
    openDialog($("#quickview"));
  }
  function stepQuick(delta) {
    const qty = $("#qv-qty");
    const max = +qty.max || 1;
    qty.value = String(Math.min(max, Math.max(1, (parseInt(qty.value, 10) || 1) + delta)));
  }

  /* ---------- cart ---------- */
  function addToCart(id, qty = 1, { silent = false } = {}) {
    const p = state.byId.get(+id);
    if (!p || p.stock <= 0) return false;
    const current = state.cart.get(p.id) || 0;
    const next = Math.min(maxFor(p), current + qty);
    if (next === current) { if (!silent) toast(`Maximum ${maxFor(p)} of ${p.name} per order`); return false; }
    state.cart.set(p.id, next);
    saveCart();
    renderCart();
    const count = $("#cart-count");
    count.classList.remove("is-bump"); void count.offsetWidth; count.classList.add("is-bump");
    if (!silent) toast(`${p.name} added to your bag`);
    return true;
  }
  function setQty(id, qty) {
    const p = state.byId.get(+id);
    if (!p) return;
    if (qty <= 0) state.cart.delete(p.id);
    else state.cart.set(p.id, Math.min(maxFor(p), qty));
    saveCart();
    renderCart();
  }
  function cartLines() {
    return [...state.cart].map(([id, qty]) => ({ p: state.byId.get(id), qty })).filter(l => l.p);
  }
  const deliveryFor = subtotal => (subtotal >= (state.config.freeDeliveryMin || 799) ? 0 : Number(state.config.deliveryFee ?? 49));
  const retailSubtotal = () => cartLines().reduce((s, l) => s + l.p.price * l.qty, 0);
  const itemCount = () => cartLines().reduce((s, l) => s + l.qty, 0);

  function renderCart() {
    const lines = cartLines();
    const count = itemCount();
    const subtotal = retailSubtotal();
    $("#cart-count").textContent = count;
    $("#drawer-count").textContent = `(${count})`;
    $("#cart-total").textContent = money(subtotal);
    const fee = lines.length ? deliveryFor(subtotal) : 0;
    $("#cart-delivery").textContent = !lines.length ? "—" : fee ? money(fee) : "Free";
    $("#cart-grand").textContent = money(subtotal + fee);
    $("#cart-open").setAttribute("aria-label", `Open bag, ${count} item${count === 1 ? "" : "s"}`);
    $("#checkout-open").disabled = lines.length === 0;

    const box = $("#cart-items");
    box.innerHTML = lines.length ? lines.map(({ p, qty }) => `
      <div class="cart-item">
        <img src="${esc(imgOf(p))}" alt="" width="72" height="80" loading="lazy">
        <div>
          <h3>${esc(p.name)}</h3>
          <small>${esc(p.weight)} · ${money(p.price)} each</small>
          <div class="stepper" role="group" aria-label="Quantity for ${esc(p.name)}">
            <button type="button" data-dec="${p.id}" aria-label="Decrease">${icon("minus")}</button>
            <output aria-live="polite">${qty}</output>
            <button type="button" data-inc="${p.id}" aria-label="Increase" ${qty >= maxFor(p) ? "disabled" : ""}>${icon("plus")}</button>
          </div>
        </div>
        <div class="cart-item__price">${money(p.price * qty)}<button class="cart-item__remove" type="button" data-remove="${p.id}">Remove</button></div>
      </div>`).join("")
      : `<div class="cart-empty">${icon("bag")}<h3>Your bag is empty</h3><p>Start with a pantry favourite — turmeric, cumin or garam masala.</p><button class="btn btn--dark" type="button" data-close data-goto-shop>Browse spices</button></div>`;

    // free-delivery meter
    const min = state.config.freeDeliveryMin || 799;
    const left = Math.max(0, min - subtotal);
    const meter = $("#ship-meter");
    meter.hidden = lines.length === 0;
    meter.classList.toggle("is-free", left === 0);
    $("#ship-meter-text").innerHTML = left === 0 ? "You’ve unlocked <strong>free delivery</strong>" : `Add <strong>${money(left)}</strong> more for free delivery`;
    $("#ship-meter-fill").style.width = `${Math.min(100, (subtotal / min) * 100)}%`;

    // mobile bag bar
    const bar = $("#bag-bar");
    bar.hidden = count === 0;
    document.body.classList.toggle("has-bag", count > 0);
    $("#bag-bar-count").textContent = `${count} item${count === 1 ? "" : "s"}`;
    $("#bag-bar-total").textContent = money(subtotal);

    if ($("#checkout-modal").open && !$("#checkout-step").hidden) renderSummary();
  }

  /* ---------- checkout ---------- */
  function isWholesale() { return $("#order-type").value === "wholesale"; }
  function renderSummary() {
    const lines = cartLines();
    const wholesale = isWholesale();
    let subtotal = 0;
    let short = 0;
    $("#summary-items").innerHTML = lines.map(({ p, qty }) => {
      const okBulk = p.wholesale_price > 0 && qty >= p.wholesale_min_qty;
      const unit = wholesale && okBulk ? p.wholesale_price : p.price;
      if (wholesale && !okBulk) short++;
      subtotal += unit * qty;
      const warn = wholesale && !okBulk ? `<span class="warn">Needs ${p.wholesale_min_qty}+ units for bulk</span>` : "";
      return `<li><span>${esc(p.name)} × ${qty}${warn}</span><strong>${money(unit * qty)}</strong></li>`;
    }).join("");
    $("#summary-subtotal").textContent = money(subtotal);
    const fee = deliveryFor(subtotal);
    $("#summary-delivery").textContent = fee ? money(fee) : "Free";
    $("#summary-total").textContent = money(subtotal + fee);
    $("#summary-note").textContent = wholesale
      ? (short ? `Increase the highlighted item${short > 1 ? "s" : ""} to their minimum, or switch to Retail.` : "Bulk pricing applied. Coupon discounts are confirmed after you place the order.")
      : "Coupon discounts (if any) are validated when you place the order.";
    $("#business-field").hidden = !wholesale;
    return { subtotal, short };
  }
  function openCheckout() {
    if (!cartLines().length) { toast("Your bag is empty"); return; }
    closeDialog($("#cart-drawer"));
    $("#checkout-step").hidden = false;
    $("#confirm-step").hidden = true;
    $("#checkout-message").textContent = "";
    renderSummary();
    openDialog($("#checkout-modal")); // the name field has autofocus, so focus lands there synchronously
  }

  function validate(form) {
    let first = null;
    $$("input, textarea, select", form).forEach(el => {
      const ok = el.checkValidity();
      el.classList.toggle("is-invalid", !ok);
      el.setAttribute("aria-invalid", String(!ok));
      if (!ok && !first) first = el;
    });
    if (first) { first.focus(); return "Please check the highlighted fields."; }
    return "";
  }

  async function submitOrder(e) {
    e.preventDefault();
    const form = e.currentTarget;
    const msg = $("#checkout-message");
    msg.textContent = "";
    const problem = validate(form);
    if (problem) { msg.textContent = problem; return; }
    const { short } = renderSummary();
    if (isWholesale() && short) { msg.textContent = "Some items are below the wholesale minimum."; return; }

    const fd = new FormData(form);
    const payload = Object.fromEntries([...fd].map(([k, v]) => [k, String(v).trim()]));
    payload.couponCode = (payload.couponCode || "").toUpperCase();
    payload.paymentMethod = "UPI";
    payload.items = cartLines().map(({ p, qty }) => ({ productId: p.id, quantity: qty }));
    if (payload.orderType !== "wholesale") payload.businessName = "";

    const btn = $("#place-order");
    btn.disabled = true;
    btn.textContent = "Placing order…";
    try {
      const res = await postOrder(payload);
      showConfirmation(res, payload);
      state.cart.clear();
      saveCart();
      renderCart();
      form.reset();
      loadProducts(); // refresh stock
    } catch (err) {
      msg.textContent = err.message;
    } finally {
      btn.disabled = false;
      btn.innerHTML = `Place order ${icon("arrow")}`;
    }
  }

  function showConfirmation(res, payload) {
    $("#checkout-step").hidden = true;
    $("#confirm-step").hidden = false;
    $("#confirm-name").textContent = payload.name.split(" ")[0];
    $("#confirm-id").textContent = `#${res.orderId}`;
    const items = res.items || [];
    $("#confirm-items").innerHTML = items.map(i => `<li><span>${esc(i.name)} × ${i.quantity}</span><span>${money(i.price * i.quantity)}</span></li>`).join("");
    $("#confirm-totals").innerHTML = `
      <div><span>Subtotal</span><span>${money(res.subtotal)}</span></div>
      ${res.discount ? `<div><span>Coupon discount</span><span>− ${money(res.discount)}</span></div>` : ""}
      <div><span>Delivery</span><span>${res.deliveryFee ? money(res.deliveryFee) : "Free"}</span></div>
      <div class="total"><span>Total to pay</span><span>${money(res.total)}</span></div>`;

    const pay = $("#confirm-pay");
    if (res.upiId) {
      pay.innerHTML = `<h3>Pay ${money(res.total)} by UPI</h3>
        <div class="confirm__pay-grid">
          ${res.upiQr ? `<img src="${res.upiQr}" alt="UPI QR code to pay ${money(res.total)}" width="150" height="150">` : ""}
          <div class="confirm__pay-info">
            <p>Scan the QR with any UPI app, or pay to:</p>
            <span class="upi-id"><span id="upi-value">${esc(res.upiId)}</span><button type="button" id="copy-upi">${icon("copy")} Copy</button></span>
            ${res.upiLink ? `<a class="btn btn--dark btn--sm" href="${esc(res.upiLink)}">Open UPI app ${icon("arrow")}</a>` : ""}
            <p>Add <strong>Order #${res.orderId}</strong> in the payment note. We’ll confirm once your payment is verified.</p>
          </div>
        </div>`;
    } else {
      pay.innerHTML = `<h3>Payment</h3><p>We’ll call you on <strong>${esc(payload.phone)}</strong> to share UPI payment details for <strong>Order #${res.orderId}</strong>. Your order is confirmed once payment is verified.</p>`;
    }

    const wa = $("#confirm-wa");
    if (state.config.whatsapp) {
      const text = [`Hi Spices of Yash! I just placed Order #${res.orderId}.`, ...items.map(i => `• ${i.name} × ${i.quantity}`), `Total: ${money(res.total)}`, `Name: ${payload.name}`].join("\n");
      wa.href = `https://wa.me/${state.config.whatsapp}?text=${encodeURIComponent(text)}`;
      wa.hidden = false;
    } else wa.hidden = true;
    $("#checkout-modal").scrollTop = 0;
  }

  /* ---------- config-driven bits ---------- */
  function applyConfig(c) {
    state.config = { ...state.config, ...c };
    state.csrf = c.csrfToken || state.csrf;
    $("#year").textContent = new Date().getFullYear();
    if (c.freeDeliveryMin) $$("[data-free-min]").forEach(el => { el.textContent = money(c.freeDeliveryMin); });
    if (c.deliveryFee != null) $$("[data-delivery-fee]").forEach(el => { el.textContent = money(c.deliveryFee); });
    if (c.fssai) $("#fssai").textContent = `FSSAI Lic. No. ${c.fssai}`;

    const contact = [];
    if (c.contactPhone) contact.push(`<li>${icon("phone")}<a href="tel:${esc(c.contactPhone.replace(/\s/g, ""))}">${esc(c.contactPhone)}</a></li>`);
    if (c.contactEmail) contact.push(`<li>${icon("mail")}<a href="mailto:${esc(c.contactEmail)}">${esc(c.contactEmail)}</a></li>`);
    if (c.whatsapp) contact.push(`<li>${icon("whatsapp")}<a href="https://wa.me/${c.whatsapp}" target="_blank" rel="noopener">WhatsApp us</a></li>`);
    if (c.address) contact.push(`<li>${icon("pin")}<span>${esc(c.address)}</span></li>`);
    if (contact.length) $("#contact-list").innerHTML = contact.join("");

    const s = c.social || {};
    $("#socials").innerHTML = [["instagram", "Instagram"], ["facebook", "Facebook"], ["youtube", "YouTube"]]
      .filter(([k]) => s[k]).map(([k, label]) => `<a href="${esc(s[k])}" target="_blank" rel="noopener" aria-label="${label}">${icon(k)}</a>`).join("");

    if (c.whatsapp) {
      const href = `https://wa.me/${c.whatsapp}?text=${encodeURIComponent("Hi Spices of Yash! I have a question.")}`;
      const fab = $("#wa-float");
      fab.href = href;
      fab.hidden = false;
      const bulk = `https://wa.me/${c.whatsapp}?text=${encodeURIComponent("Hi Spices of Yash! I'd like a wholesale quote.")}`;
      $("#wholesale-actions").insertAdjacentHTML("beforeend", `<a class="btn btn--ghost-light" href="${bulk}" target="_blank" rel="noopener">${icon("whatsapp")} Get a bulk quote</a>`);
      $("#cta-actions").insertAdjacentHTML("afterbegin", `<a class="btn btn--saffron" href="${href}" target="_blank" rel="noopener">${icon("whatsapp")} Chat on WhatsApp</a>`);
    } else if (c.contactEmail) {
      $("#cta-actions").insertAdjacentHTML("afterbegin", `<a class="btn btn--saffron" href="mailto:${esc(c.contactEmail)}">${icon("mail")} Email us</a>`);
      $("#wholesale-actions").insertAdjacentHTML("beforeend", `<a class="btn btn--ghost-light" href="mailto:${esc(c.contactEmail)}?subject=Wholesale%20enquiry">${icon("mail")} Email for a quote</a>`);
    }
  }

  /* ---------- data ---------- */
  async function loadProducts() {
    const products = await getJSON("/api/products");
    state.products = products;
    state.byId = new Map(products.map(p => [p.id, p]));
    state.bySlug = new Map(products.map(p => [p.slug, p]));
    // drop cart lines that no longer exist / clamp to stock
    for (const [id, q] of state.cart) {
      const p = state.byId.get(id);
      if (!p || p.stock <= 0) state.cart.delete(id);
      else if (q > maxFor(p)) state.cart.set(id, maxFor(p));
    }
    saveCart();
    renderChips();
    renderProducts();
    renderFeature();
    renderPriceTable();
    renderCart();
  }

  /* ---------- events ---------- */
  document.addEventListener("click", e => {
    const t = e.target;
    const quick = t.closest("[data-quick]");
    if (quick) { openQuick(quick.dataset.quick); return; }
    const add = t.closest("[data-add]");
    if (add) { addToCart(add.dataset.add); return; }
    const chip = t.closest("[data-category]");
    if (chip) { state.category = chip.dataset.category; renderProducts(); return; }
    const inc = t.closest("[data-inc]");
    if (inc) { setQty(inc.dataset.inc, (state.cart.get(+inc.dataset.inc) || 0) + 1); return; }
    const dec = t.closest("[data-dec]");
    if (dec) { setQty(dec.dataset.dec, (state.cart.get(+dec.dataset.dec) || 0) - 1); return; }
    const rm = t.closest("[data-remove]");
    if (rm) { setQty(rm.dataset.remove, 0); return; }
    const recipe = t.closest("[data-add-recipe]");
    if (recipe) {
      const added = recipe.dataset.addRecipe.split(",").map(s => state.bySlug.get(s.trim())).filter(Boolean)
        .filter(p => addToCart(p.id, 1, { silent: true }));
      toast(added.length ? `Added ${added.length} spice${added.length > 1 ? "s" : ""} to your bag` : "These spices are already in your bag");
      return;
    }
    if (t.closest("[data-goto-shop]")) { document.getElementById("shop").scrollIntoView(); }
  });

  $("#cart-open").addEventListener("click", () => openDialog($("#cart-drawer")));
  $("#bag-bar-open").addEventListener("click", () => openDialog($("#cart-drawer")));
  $("#checkout-open").addEventListener("click", openCheckout);
  $("#checkout-form").addEventListener("submit", submitOrder);
  $("#order-type").addEventListener("change", renderSummary);
  $("#checkout-form").addEventListener("input", e => {
    if (e.target.classList.contains("is-invalid") && e.target.checkValidity()) { e.target.classList.remove("is-invalid"); e.target.removeAttribute("aria-invalid"); }
    if (!$("#checkout-form .is-invalid")) $("#checkout-message").textContent = "";
  });
  $("#confirm-pay").addEventListener("click", async e => {
    if (!e.target.closest("#copy-upi")) return;
    try { await navigator.clipboard.writeText($("#upi-value").textContent); toast("UPI ID copied"); }
    catch { toast("Copy failed — please copy manually"); }
  });

  $("#qv-minus").addEventListener("click", () => stepQuick(-1));
  $("#qv-plus").addEventListener("click", () => stepQuick(1));
  $("#qv-qty").addEventListener("change", () => stepQuick(0));
  $("#qv-add").addEventListener("click", () => {
    if (state.quickId == null) return;
    if (addToCart(state.quickId, parseInt($("#qv-qty").value, 10) || 1)) closeDialog($("#quickview"));
  });

  let searchTimer;
  $("#search-input").addEventListener("input", e => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => { state.query = e.target.value; renderProducts(); }, 120);
  });
  $("#clear-filters").addEventListener("click", () => {
    state.query = ""; state.category = "all";
    $("#search-input").value = "";
    renderProducts();
    $("#search-input").focus();
  });
  $("#search-toggle").addEventListener("click", () => {
    document.getElementById("shop").scrollIntoView({ behavior: "smooth" });
    setTimeout(() => $("#search-input").focus({ preventScroll: true }), 400);
  });

  // mobile nav
  const nav = $("#main-nav");
  const menuBtn = $("#menu-toggle");
  function setMenu(open) {
    nav.classList.toggle("is-open", open);
    menuBtn.setAttribute("aria-expanded", String(open));
    menuBtn.setAttribute("aria-label", open ? "Close menu" : "Open menu");
    menuBtn.innerHTML = icon(open ? "close" : "menu");
  }
  menuBtn.addEventListener("click", () => setMenu(!nav.classList.contains("is-open")));
  nav.addEventListener("click", e => { if (e.target.closest("a")) setMenu(false); });
  document.addEventListener("keydown", e => { if (e.key === "Escape" && nav.classList.contains("is-open")) setMenu(false); });

  /* ---------- boot ---------- */
  loadCart();
  getJSON("/api/config").then(applyConfig).catch(() => refreshCsrf().catch(() => {}));
  loadProducts().catch(() => {
    $("#product-grid").innerHTML = `<div class="empty-state empty-state--full"><h3>We couldn’t load the pantry.</h3><p>Please check your connection and refresh the page.</p></div>`;
    $("#product-grid").setAttribute("aria-busy", "false");
  });
})();
