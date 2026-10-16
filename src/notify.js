// New-order alerts via Telegram (free). Setup:
//  1. In Telegram, message @BotFather → /newbot → copy the token into TELEGRAM_BOT_TOKEN
//  2. Send any message to your new bot, then open
//     https://api.telegram.org/bot<TOKEN>/getUpdates and copy "chat":{"id": ...} into TELEGRAM_CHAT_ID
//  3. In the admin dashboard, press "Send test alert".
const money = n => `₹${Number(n || 0).toLocaleString("en-IN", { maximumFractionDigits: 2 })}`;

function configured() {
  return Boolean(process.env.TELEGRAM_BOT_TOKEN && process.env.TELEGRAM_CHAT_ID);
}

async function send(text) {
  if (!configured()) return false;
  const r = await fetch(`https://api.telegram.org/bot${process.env.TELEGRAM_BOT_TOKEN}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ chat_id: process.env.TELEGRAM_CHAT_ID, text, disable_web_page_preview: true }),
    signal: AbortSignal.timeout(8000)
  });
  if (!r.ok) {
    const body = await r.json().catch(() => ({}));
    throw new Error(body.description || `HTTP ${r.status}`);
  }
  return true;
}

async function newOrder(o) {
  if (!configured()) return false;
  const lines = [
    `🛒 New order #${o.orderId} — ${money(o.total)}`,
    `${o.customer} · ${o.phone} · ${o.city}`,
    `${o.orderType === "wholesale" ? "Wholesale" : "Retail"}${o.couponCode ? ` · coupon ${String(o.couponCode).toUpperCase()}` : ""}`,
    "",
    ...o.lines.map(l => `• ${l.name} × ${l.quantity} = ${money(l.price * l.quantity)}`),
    "",
    `Subtotal ${money(o.subtotal)}${o.discount ? ` · discount −${money(o.discount)}` : ""} · delivery ${o.deliveryFee ? money(o.deliveryFee) : "free"}`,
    "Payment: UPI, pending verification"
  ];
  try { return await send(lines.join("\n")); }
  catch (err) { console.error("Order alert failed:", err.message); return false; }
}

module.exports = { configured, send, newOrder };
