/* Fills store contact details and delivery amounts on policy pages from /api/config. */
(() => {
  const money = n => new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(n);
  const year = document.getElementById("year");
  if (year) year.textContent = new Date().getFullYear();
  fetch("/api/config", { credentials: "same-origin" }).then(r => r.json()).then(c => {
    document.querySelectorAll("[data-cfg]").forEach(el => {
      const v = c[el.dataset.cfg];
      if (v) el.textContent = el.dataset.cfg === "contactEmail" ? v : `· ${v}`;
      else if (el.dataset.cfg !== "contactEmail") el.remove();
    });
    if (c.freeDeliveryMin) document.querySelectorAll("[data-free-min]").forEach(el => { el.textContent = money(c.freeDeliveryMin); });
    if (c.deliveryFee != null) document.querySelectorAll("[data-delivery-fee]").forEach(el => { el.textContent = money(c.deliveryFee); });
    const f = document.getElementById("fssai");
    if (f && c.fssai) f.textContent = `FSSAI Lic. No. ${c.fssai}`;
  }).catch(() => {});
})();
