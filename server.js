require("dotenv").config();
const express = require("express");
const path = require("path");
const fs = require("fs");
const crypto = require("crypto");
const helmet = require("helmet");
const session = require("express-session");
const rateLimit = require("express-rate-limit");
const bcrypt = require("bcryptjs");
const QRCode = require("qrcode");
const { z } = require("zod");
const db = require("./src/db");
const notify = require("./src/notify");

let sharp = null;
try { sharp = require("sharp"); } catch { /* optional: uploads are stored as-is without resizing */ }

const app = express();
const PORT = Number(process.env.PORT || 3000);
const isProd = process.env.NODE_ENV === "production";
const sessionSecret = process.env.SESSION_SECRET;
const STORE_NAME = process.env.STORE_NAME || "Spices of Yash";
const SITE_URL = (process.env.SITE_URL || "https://spices-of-yash-store.onrender.com").replace(/\/$/, "");
const FREE_DELIVERY_MIN = Number(process.env.FREE_DELIVERY_MIN || 799);
const DELIVERY_FEE = Number(process.env.DELIVERY_FEE ?? 49);
const round2 = n => Math.round(Number(n || 0) * 100) / 100;

if (!sessionSecret || sessionSecret.length < 32) {
  console.error("Security setup required: set SESSION_SECRET to a random string of at least 32 characters in .env");
  process.exit(1);
}

app.disable("x-powered-by");
if (isProd) app.set("trust proxy", 1);

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
      fontSrc: ["'self'", "https://fonts.gstatic.com", "data:"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'"],
      objectSrc: ["'none'"],
      upgradeInsecureRequests: isProd ? [] : null
    }
  },
  crossOriginEmbedderPolicy: false
}));
app.use(express.json({ limit: "20kb" }));
app.use(express.urlencoded({ extended: false, limit: "20kb" }));

app.use(session({
  name: "spiceroot.sid",
  store: db.sessionStore(session),
  secret: sessionSecret,
  resave: false,
  saveUninitialized: false,
  cookie: { httpOnly: true, secure: process.env.COOKIE_SECURE === "true" || isProd, sameSite: "lax", maxAge: 1000 * 60 * 60 * 8 }
}));

const generalLimiter = rateLimit({ windowMs: 15 * 60 * 1000, limit: 300, standardHeaders: "draft-7", legacyHeaders: false });
const authLimiter = rateLimit({ windowMs: 15 * 60 * 1000, limit: 8, standardHeaders: "draft-7", legacyHeaders: false, message: { error: "Too many attempts. Please try again later." } });
const orderLimiter = rateLimit({ windowMs: 60 * 60 * 1000, limit: Number(process.env.ORDER_RATE_LIMIT || 12), standardHeaders: "draft-7", legacyHeaders: false, message: { error: "Too many orders from this network. Please try again in a while." } });
app.use("/api", generalLimiter); // only API calls — static assets (images, CSS, fonts) must not count toward the limit

// Wrap async route handlers so errors reach the error middleware.
const ah = fn => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

/* -------------------------------------------------------------- pages */
const publicDir = path.join(__dirname, "public");
let indexTemplate = null;
async function structuredData() {
  const products = await db.all("SELECT * FROM products WHERE active = 1 ORDER BY featured DESC, name ASC");
  const abs = u => (u && u.startsWith("/") ? SITE_URL + u : u);
  const graph = [
    { "@type": "Organization", "@id": `${SITE_URL}/#org`, name: STORE_NAME, url: SITE_URL, logo: `${SITE_URL}/favicon.svg`, ...(process.env.CONTACT_EMAIL ? { email: process.env.CONTACT_EMAIL } : {}) },
    { "@type": "WebSite", name: STORE_NAME, url: SITE_URL },
    ...products.map(p => ({
      "@type": "Product", name: p.name, description: p.description, category: p.category, image: abs(p.image), sku: p.slug,
      brand: { "@type": "Brand", name: STORE_NAME },
      offers: { "@type": "Offer", priceCurrency: "INR", price: p.price, url: `${SITE_URL}/#shop`, availability: p.stock > 0 ? "https://schema.org/InStock" : "https://schema.org/OutOfStock" }
    }))
  ];
  return JSON.stringify({ "@context": "https://schema.org", "@graph": graph }).replace(/</g, "\\u003c");
}
const sendStorefront = ah(async (req, res) => {
  if (!indexTemplate || !isProd) indexTemplate = fs.readFileSync(path.join(publicDir, "index.html"), "utf8");
  const html = indexTemplate.replace("<!--JSONLD-->", `<script type="application/ld+json">${await structuredData()}</script>`).replaceAll("__SITE_URL__", SITE_URL);
  res.type("html").send(html);
});
app.get(["/", "/shop", "/index.html"], sendStorefront);
app.get("/admin", (req, res) => res.sendFile(path.join(publicDir, "admin.html")));

const POLICY_PAGES = { "/privacy": "privacy", "/terms": "terms", "/shipping-policy": "shipping", "/refund-policy": "refund" };
for (const [route, file] of Object.entries(POLICY_PAGES)) {
  app.get(route, (req, res) => res.sendFile(path.join(publicDir, "policies", `${file}.html`)));
}
app.get("/sitemap.xml", (req, res) => {
  const urls = ["/", ...Object.keys(POLICY_PAGES)];
  res.type("application/xml").send(`<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls.map(u => `  <url><loc>${SITE_URL}${u}</loc><changefreq>${u === "/" ? "weekly" : "yearly"}</changefreq><priority>${u === "/" ? "1.0" : "0.3"}</priority></url>`).join("\n")}\n</urlset>\n`);
});
app.get("/robots.txt", (req, res) => {
  res.type("text/plain").send(`User-agent: *\nAllow: /\nDisallow: /admin\nDisallow: /api/\n\nSitemap: ${SITE_URL}/sitemap.xml\n`);
});

// Uploaded product images live in the database so they survive redeploys.
app.get("/media/:id.:ext", ah(async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id <= 0) return res.status(404).end();
  const img = await db.get("SELECT mime, data FROM images WHERE id = ?", [id]);
  if (!img) return res.status(404).end();
  res.set("Cache-Control", "public, max-age=31536000, immutable");
  res.type(img.mime).send(Buffer.from(img.data));
}));

app.use(express.static(publicDir, { extensions: ["html"], maxAge: isProd ? "1h" : 0, index: false }));

/* ------------------------------------------------------------ helpers */
// Create the CSRF token only where the page asks for it (config, csrf, admin/me). Creating it on every
// request made parallel first-visit calls (config + products) start two different sessions.
const ensureCsrf = req => {
  if (!req.session.csrfToken) req.session.csrfToken = crypto.randomBytes(32).toString("hex");
  return req.session.csrfToken;
};
function requireCsrf(req, res, next) {
  const token = req.get("x-csrf-token") || req.body?._csrf;
  const supplied = Buffer.from(String(token || ""));
  const expected = Buffer.from(String(req.session.csrfToken || ""));
  if (!token || !req.session.csrfToken || supplied.length !== expected.length || !crypto.timingSafeEqual(supplied, expected)) {
    return res.status(403).json({ error: "Security token expired. Refresh the page and try again." });
  }
  next();
}
function requireAdmin(req, res, next) {
  if (!req.session.adminId) return res.status(401).json({ error: "Admin login required." });
  next();
}
const cleanText = (value, max = 200) => String(value ?? "").trim().replace(/[<>]/g, "").slice(0, max);
const publicProduct = r => ({ id: r.id, name: r.name, slug: r.slug, category: r.category, description: r.description, price: r.price, wholesale_price: r.wholesale_price, wholesale_min_qty: r.wholesale_min_qty, weight: r.weight, image: r.image, featured: Boolean(r.featured), stock: r.stock });
const deliveryFor = subtotal => (subtotal >= FREE_DELIVERY_MIN ? 0 : DELIVERY_FEE);

const checkoutSchema = z.object({
  name: z.string().trim().min(2).max(100),
  phone: z.string().trim().regex(/^[6-9]\d{9}$/),
  email: z.string().trim().email().max(160).optional().or(z.literal("")),
  address: z.string().trim().min(10).max(500),
  city: z.string().trim().min(2).max(100),
  pincode: z.string().trim().regex(/^\d{6}$/),
  notes: z.string().trim().max(500).optional(),
  orderType: z.enum(["retail", "wholesale"]).default("retail"),
  businessName: z.string().trim().max(160).optional().default(""),
  couponCode: z.string().trim().max(40).optional().default(""),
  paymentMethod: z.enum(["UPI"]).default("UPI"),
  items: z.array(z.object({ productId: z.number().int().positive(), quantity: z.number().int().min(1).max(20) })).min(1).max(30)
});

/* ---------------------------------------------------------- public API */
app.get("/api/health", ah(async (req, res) => {
  try { await db.get("SELECT 1 AS ok"); res.json({ status: "ok", database: db.kind }); }
  catch { res.status(503).json({ status: "unavailable" }); }
}));

app.get("/api/config", (req, res) => res.json({
  storeName: STORE_NAME,
  currency: process.env.CURRENCY || "INR",
  upiConfigured: Boolean(process.env.UPI_ID),
  freeDeliveryMin: FREE_DELIVERY_MIN,
  deliveryFee: DELIVERY_FEE,
  whatsapp: (process.env.WHATSAPP_NUMBER || "").replace(/\D/g, ""),
  contactEmail: process.env.CONTACT_EMAIL || "",
  contactPhone: process.env.CONTACT_PHONE || "",
  address: process.env.STORE_ADDRESS || "",
  fssai: process.env.FSSAI_NUMBER || "",
  social: { instagram: process.env.INSTAGRAM_URL || "", facebook: process.env.FACEBOOK_URL || "", youtube: process.env.YOUTUBE_URL || "" },
  csrfToken: ensureCsrf(req)
}));

app.get("/api/products", ah(async (req, res) => {
  const rows = await db.all("SELECT * FROM products WHERE active = 1 ORDER BY featured DESC, name ASC");
  res.json(rows.map(publicProduct));
}));
app.get("/api/products/:slug", ah(async (req, res) => {
  const row = await db.get("SELECT * FROM products WHERE slug = ? AND active = 1", [req.params.slug]);
  if (!row) return res.status(404).json({ error: "Product not found." });
  res.json(publicProduct(row));
}));

class OrderError extends Error { constructor(status, message) { super(message); this.status = status; } }

app.post("/api/orders", orderLimiter, requireCsrf, ah(async (req, res) => {
  const parsed = checkoutSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "Please check your details and cart quantities." });
  const input = parsed.data;

  // Merge repeated product lines so stock and price checks see the real quantity.
  const merged = new Map();
  for (const i of input.items) merged.set(i.productId, (merged.get(i.productId) || 0) + i.quantity);
  const ids = [...merged.keys()];

  try {
    const result = await db.tx(async t => {
      const products = await t.all(`SELECT id, name, price, wholesale_price, wholesale_min_qty, stock, active FROM products WHERE id IN (${ids.map(() => "?").join(",")})`, ids);
      const byId = new Map(products.map(p => [p.id, p]));
      let subtotal = 0;
      const lines = [];
      for (const [productId, quantity] of merged) {
        const p = byId.get(productId);
        if (!p || !p.active) throw new OrderError(400, "A product in your cart is no longer available.");
        if (p.stock < quantity) throw new OrderError(409, `${p.name} has only ${p.stock} units left.`);
        const price = input.orderType === "wholesale" ? Number(p.wholesale_price) : Number(p.price);
        if (input.orderType === "wholesale" && (!price || quantity < p.wholesale_min_qty)) throw new OrderError(400, `${p.name} requires at least ${p.wholesale_min_qty} units for wholesale pricing.`);
        subtotal += price * quantity;
        lines.push({ productId, name: p.name, price, quantity });
      }
      subtotal = round2(subtotal);

      let discount = 0, couponCode = "";
      if (input.couponCode) {
        const coupon = await t.get("SELECT * FROM coupons WHERE code = ? AND active = 1", [input.couponCode.toUpperCase()]);
        if (!coupon) throw new OrderError(400, "That coupon is invalid or inactive.");
        if (coupon.expires_at && new Date(`${coupon.expires_at}T23:59:59Z`) < new Date()) throw new OrderError(400, "That coupon has expired.");
        if (subtotal < coupon.min_order) throw new OrderError(400, `Coupon requires a minimum order of ₹${coupon.min_order}.`);
        discount = coupon.discount_type === "percent" ? (subtotal * coupon.discount_value) / 100 : coupon.discount_value;
        discount = Math.min(subtotal, round2(discount));
        couponCode = coupon.code;
      }
      const deliveryFee = deliveryFor(subtotal);
      const total = Math.max(0, round2(subtotal - discount + deliveryFee));

      for (const l of lines) {
        const r = await t.run("UPDATE products SET stock = stock - ? WHERE id = ? AND stock >= ?", [l.quantity, l.productId, l.quantity]);
        if (r.changes !== 1) throw new OrderError(409, "Stock changed while placing the order. Refresh your cart and try again.");
      }
      const created = await t.run(`INSERT INTO orders (customer_name, phone, email, address, city, pincode, notes, total, status, created_at, order_type, business_name, payment_method, payment_status, discount, coupon_code, delivery_fee)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'New', ?, ?, ?, ?, 'Pending verification', ?, ?, ?)`,
        [cleanText(input.name, 100), cleanText(input.phone, 10), cleanText(input.email, 160), cleanText(input.address, 500), cleanText(input.city, 100), cleanText(input.pincode, 6), cleanText(input.notes, 500), total, db.now(), input.orderType, cleanText(input.businessName, 160), input.paymentMethod, discount, couponCode, deliveryFee]);
      const orderId = created.lastId;
      for (const l of lines) {
        await t.run("INSERT INTO order_items (order_id, product_id, product_name, unit_price, quantity) VALUES (?, ?, ?, ?, ?)", [orderId, l.productId, l.name, l.price, l.quantity]);
      }
      return { orderId, subtotal, discount, deliveryFee, total, lines };
    });

    const upiId = process.env.UPI_ID || "";
    let upiLink = "", upiQr = "";
    if (upiId) {
      const params = new URLSearchParams({ pa: upiId, pn: STORE_NAME, am: result.total.toFixed(2), cu: "INR", tn: `Order ${result.orderId}` });
      upiLink = `upi://pay?${params.toString()}`;
      try { upiQr = await QRCode.toDataURL(upiLink, { margin: 1, width: 240, color: { dark: "#1d130e", light: "#ffffff" } }); } catch { upiQr = ""; }
    }
    notify.newOrder({ ...result, customer: cleanText(input.name, 100), phone: input.phone, city: cleanText(input.city, 100), orderType: input.orderType, couponCode: input.couponCode }).catch(() => {});
    res.status(201).json({
      message: "Order received. UPI payment remains pending until the store verifies it.",
      orderId: result.orderId, subtotal: result.subtotal, discount: result.discount, deliveryFee: result.deliveryFee, total: result.total,
      items: result.lines.map(l => ({ name: l.name, quantity: l.quantity, price: l.price })),
      paymentStatus: "Pending verification", upiId, upiLink, upiQr
    });
  } catch (err) {
    if (err instanceof OrderError) return res.status(err.status).json({ error: err.message });
    console.error("Order creation failed:", err.message);
    res.status(500).json({ error: "Could not place your order. Please try again." });
  }
}));

app.get("/api/csrf", (req, res) => res.json({ csrfToken: ensureCsrf(req) }));

/* ------------------------------------------------------------ admin API */
const DUMMY_HASH = "$2a$10$abcdefghijklmnopqrstuuV3lB8N0RzX5cYQx7uYg0bWkP9z5lq";
app.post("/api/admin/login", authLimiter, requireCsrf, ah(async (req, res) => {
  const username = cleanText(req.body.username, 100);
  const password = String(req.body.password || "");
  const admin = await db.get("SELECT id, username, password_hash FROM admins WHERE username = ?", [username]);
  const valid = await bcrypt.compare(password, admin ? admin.password_hash : DUMMY_HASH);
  if (!admin || !valid) return res.status(401).json({ error: "Invalid username or password." });
  req.session.regenerate(err => {
    if (err) return res.status(500).json({ error: "Unable to start secure session." });
    req.session.adminId = admin.id;
    req.session.username = admin.username;
    req.session.csrfToken = crypto.randomBytes(32).toString("hex");
    res.json({ message: "Logged in.", username: admin.username, csrfToken: req.session.csrfToken });
  });
}));
app.post("/api/admin/logout", requireAdmin, requireCsrf, (req, res) => {
  req.session.destroy(() => res.json({ message: "Logged out." }));
});
app.get("/api/admin/me", (req, res) => {
  // 200 with loggedIn:false keeps the browser console clean on the login screen.
  if (!req.session.adminId) return res.json({ loggedIn: false, csrfToken: ensureCsrf(req) });
  res.json({ loggedIn: true, username: req.session.username, csrfToken: req.session.csrfToken, alertsConfigured: notify.configured(), database: db.kind });
});

app.get("/api/admin/orders", requireAdmin, ah(async (req, res) => {
  const orders = await db.all("SELECT * FROM orders ORDER BY created_at DESC, id DESC LIMIT 500");
  if (!orders.length) return res.json([]);
  const items = await db.all(`SELECT order_id, product_name, unit_price, quantity FROM order_items WHERE order_id IN (${orders.map(() => "?").join(",")})`, orders.map(o => o.id));
  const byOrder = new Map();
  for (const i of items) { if (!byOrder.has(i.order_id)) byOrder.set(i.order_id, []); byOrder.get(i.order_id).push(i); }
  res.json(orders.map(o => ({ ...o, items: byOrder.get(o.id) || [] })));
}));
app.patch("/api/admin/orders/:id", requireAdmin, requireCsrf, ah(async (req, res) => {
  const status = String(req.body.status || "");
  if (!["New", "Confirmed", "Packed", "Shipped", "Delivered", "Cancelled"].includes(status)) return res.status(400).json({ error: "Invalid order status." });
  const r = await db.run("UPDATE orders SET status = ? WHERE id = ?", [status, Number(req.params.id)]);
  if (!r.changes) return res.status(404).json({ error: "Order not found." });
  res.json({ message: "Order updated." });
}));
app.patch("/api/admin/orders/:id/payment", requireAdmin, requireCsrf, ah(async (req, res) => {
  const paymentStatus = String(req.body.paymentStatus || "");
  if (!["Pending verification", "Paid", "Failed", "Refunded"].includes(paymentStatus)) return res.status(400).json({ error: "Invalid payment status." });
  const r = await db.run("UPDATE orders SET payment_status = ? WHERE id = ?", [paymentStatus, Number(req.params.id)]);
  if (!r.changes) return res.status(404).json({ error: "Order not found." });
  res.json({ message: "Payment status updated." });
}));

app.get("/api/admin/products", requireAdmin, ah(async (req, res) => {
  res.json(await db.all("SELECT id, name, slug, category, description, price, weight, image, stock, featured, active, wholesale_price, wholesale_min_qty FROM products ORDER BY id DESC"));
}));
const productSchema = z.object({
  name: z.string().trim().min(2).max(120),
  category: z.string().trim().min(2).max(80),
  description: z.string().trim().min(5).max(1000),
  price: z.number().positive().max(100000),
  weight: z.string().trim().min(1).max(40),
  image: z.string().trim().max(500).optional().default(""),
  stock: z.number().int().min(0).max(100000),
  wholesale_price: z.number().min(0).max(100000).optional().default(0),
  wholesale_min_qty: z.number().int().min(2).max(100000).optional().default(10),
  featured: z.boolean().optional().default(false)
});
app.post("/api/admin/products", requireAdmin, requireCsrf, ah(async (req, res) => {
  const parsed = productSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "Please provide valid product details." });
  const p = parsed.data;
  const slugBase = p.name.toLowerCase().normalize("NFKD").replace(/[̀-ͯ]/g, "").replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 90) || "spice";
  const slug = `${slugBase}-${crypto.randomBytes(3).toString("hex")}`;
  const r = await db.run("INSERT INTO products (name, slug, category, description, price, weight, image, stock, featured, active, wholesale_price, wholesale_min_qty) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)",
    [p.name, slug, p.category, p.description, p.price, p.weight, cleanText(p.image, 500), p.stock, p.featured ? 1 : 0, p.wholesale_price, p.wholesale_min_qty]);
  res.status(201).json({ id: r.lastId, slug });
}));
app.patch("/api/admin/products/:id", requireAdmin, requireCsrf, ah(async (req, res) => {
  const allowed = ["name", "category", "description", "price", "weight", "image", "stock", "featured", "active", "wholesale_price", "wholesale_min_qty"];
  const entries = Object.entries(req.body || {}).filter(([k]) => allowed.includes(k));
  if (!entries.length) return res.status(400).json({ error: "No valid fields supplied." });
  const normalized = {};
  for (const [key, value] of entries) {
    if (["name", "category", "description", "weight", "image"].includes(key)) normalized[key] = cleanText(value, key === "description" ? 1000 : 500);
    else if (["price", "stock", "wholesale_price", "wholesale_min_qty"].includes(key)) normalized[key] = Number(value);
    else normalized[key] = value ? 1 : 0;
  }
  if (normalized.price !== undefined && (!Number.isFinite(normalized.price) || normalized.price <= 0)) return res.status(400).json({ error: "Invalid price." });
  if (normalized.stock !== undefined && (!Number.isInteger(normalized.stock) || normalized.stock < 0)) return res.status(400).json({ error: "Invalid stock." });
  if (normalized.wholesale_price !== undefined && (!Number.isFinite(normalized.wholesale_price) || normalized.wholesale_price < 0)) return res.status(400).json({ error: "Invalid wholesale price." });
  if (normalized.wholesale_min_qty !== undefined && (!Number.isInteger(normalized.wholesale_min_qty) || normalized.wholesale_min_qty < 2)) return res.status(400).json({ error: "Wholesale minimum quantity must be at least 2." });
  if (normalized.name !== undefined && normalized.name.length < 2) return res.status(400).json({ error: "Product name is too short." });
  const set = Object.keys(normalized).map(k => `${k} = ?`).join(", ");
  const r = await db.run(`UPDATE products SET ${set} WHERE id = ?`, [...Object.values(normalized), Number(req.params.id)]);
  if (!r.changes) return res.status(404).json({ error: "Product not found." });
  res.json({ message: "Product updated." });
}));

// Image upload: the browser sends the file body directly (Content-Type: image/*).
const IMAGE_TYPES = { "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp" };
app.post("/api/admin/images", requireAdmin, requireCsrf, express.raw({ type: Object.keys(IMAGE_TYPES), limit: "8mb" }), ah(async (req, res) => {
  const type = (req.get("content-type") || "").split(";")[0].trim();
  if (!IMAGE_TYPES[type] || !Buffer.isBuffer(req.body) || !req.body.length) return res.status(400).json({ error: "Upload a JPG, PNG or WebP image (max 8 MB)." });
  let data = req.body, mime = type;
  if (sharp) {
    try {
      data = await sharp(req.body).rotate().resize({ width: 1000, height: 1250, fit: "inside", withoutEnlargement: true }).webp({ quality: 82 }).toBuffer();
      mime = "image/webp";
    } catch { return res.status(400).json({ error: "That file doesn’t look like a valid image." }); }
  } else if (data.length > 2 * 1024 * 1024) {
    return res.status(400).json({ error: "Image is larger than 2 MB. Please resize it first." });
  }
  const r = await db.run("INSERT INTO images (mime, data, bytes, created_at) VALUES (?, ?, ?, ?)", [mime, data, data.length, db.now()]);
  res.status(201).json({ id: r.lastId, url: `/media/${r.lastId}.${IMAGE_TYPES[mime]}`, bytes: data.length });
}));

app.get("/api/admin/coupons", requireAdmin, ah(async (req, res) => {
  res.json(await db.all("SELECT * FROM coupons ORDER BY created_at DESC, id DESC"));
}));
app.post("/api/admin/coupons", requireAdmin, requireCsrf, ah(async (req, res) => {
  const schema = z.object({ code: z.string().trim().min(3).max(40).regex(/^[A-Za-z0-9_-]+$/), discountType: z.enum(["percent", "fixed"]), discountValue: z.number().positive().max(100000), minOrder: z.number().min(0).max(1000000).default(0), expiresAt: z.string().regex(/^(\d{4}-\d{2}-\d{2})?$/).optional().default("") });
  const parsed = schema.safeParse(req.body);
  if (!parsed.success || (parsed.data?.discountType === "percent" && parsed.data.discountValue > 100)) return res.status(400).json({ error: "Please check coupon fields; percentage must be 1–100." });
  const c = parsed.data;
  const exists = await db.get("SELECT id FROM coupons WHERE code = ?", [c.code.toUpperCase()]);
  if (exists) return res.status(409).json({ error: "Coupon code already exists." });
  const r = await db.run("INSERT INTO coupons (code, discount_type, discount_value, min_order, active, expires_at, created_at) VALUES (?, ?, ?, ?, 1, ?, ?)",
    [c.code.toUpperCase(), c.discountType, c.discountValue, c.minOrder, c.expiresAt || null, db.now()]);
  res.status(201).json({ id: r.lastId, message: "Coupon created." });
}));
app.patch("/api/admin/coupons/:id", requireAdmin, requireCsrf, ah(async (req, res) => {
  const active = req.body.active;
  if (typeof active !== "boolean") return res.status(400).json({ error: "Active must be true or false." });
  const r = await db.run("UPDATE coupons SET active = ? WHERE id = ?", [active ? 1 : 0, Number(req.params.id)]);
  if (!r.changes) return res.status(404).json({ error: "Coupon not found." });
  res.json({ message: "Coupon updated." });
}));

app.get("/api/admin/reports", requireAdmin, ah(async (req, res) => {
  const monthly = (await db.all(`
    SELECT substr(created_at, 1, 7) AS month, COUNT(*) AS orders,
      SUM(CASE WHEN payment_status = 'Paid' AND status != 'Cancelled' THEN 1 ELSE 0 END) AS "paidOrders",
      SUM(CASE WHEN payment_status = 'Paid' AND status != 'Cancelled' THEN total ELSE 0 END) AS revenue
    FROM orders GROUP BY substr(created_at, 1, 7) ORDER BY month DESC LIMIT 12`)).map(m => ({ ...m, paidOrders: Number(m.paidOrders), revenue: round2(m.revenue) }));
  const bestSellers = (await db.all(`
    SELECT oi.product_name AS name, SUM(oi.quantity) AS units, SUM(oi.unit_price * oi.quantity) AS gross
    FROM order_items oi JOIN orders o ON o.id = oi.order_id WHERE o.status != 'Cancelled'
    GROUP BY oi.product_name ORDER BY units DESC LIMIT 10`)).map(b => ({ ...b, units: Number(b.units), gross: round2(b.gross) }));
  const lowStock = await db.all("SELECT id, name, stock FROM products WHERE active = 1 AND stock <= 10 ORDER BY stock ASC, name ASC");
  const payments = await db.all("SELECT payment_status AS status, COUNT(*) AS count FROM orders WHERE status != 'Cancelled' GROUP BY payment_status");
  res.json({ monthly, bestSellers, lowStock, payments });
}));
app.get("/api/admin/reports.csv", requireAdmin, ah(async (req, res) => {
  const cols = ["id", "created_at", "customer_name", "phone", "city", "pincode", "order_type", "business_name", "total", "discount", "delivery_fee", "coupon_code", "payment_method", "payment_status", "status"];
  const rows = await db.all(`SELECT ${cols.join(",")} FROM orders ORDER BY created_at DESC, id DESC`);
  // Prefix cells that start with = + - @ so spreadsheets don't run them as formulas.
  const safeCsvCell = v => { let s = String(v ?? ""); if (/^[=+\-@\t\r]/.test(s)) s = `'${s}`; return `"${s.replace(/"/g, '""')}"`; };
  res.setHeader("Content-Type", "text/csv; charset=utf-8");
  res.setHeader("Content-Disposition", 'attachment; filename="spices-of-yash-orders.csv"');
  res.send([cols.join(","), ...rows.map(r => cols.map(c => safeCsvCell(r[c])).join(","))].join("\r\n"));
}));
app.get("/api/admin/summary", requireAdmin, ah(async (req, res) => {
  const products = (await db.get("SELECT COUNT(*) AS count FROM products WHERE active = 1")).count;
  const orders = (await db.get("SELECT COUNT(*) AS count FROM orders")).count;
  const revenue = (await db.get("SELECT COALESCE(SUM(total), 0) AS total FROM orders WHERE payment_status = 'Paid' AND status != 'Cancelled'")).total;
  const pending = (await db.get("SELECT COUNT(*) AS count FROM orders WHERE status IN ('New','Confirmed')")).count;
  const lowStock = (await db.get("SELECT COUNT(*) AS count FROM products WHERE active = 1 AND stock <= 10")).count;
  res.json({ products: Number(products), orders: Number(orders), revenue: round2(revenue), pending: Number(pending), lowStock: Number(lowStock) });
}));
app.post("/api/admin/test-alert", requireAdmin, requireCsrf, ah(async (req, res) => {
  if (!notify.configured()) return res.status(400).json({ error: "Set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID in your environment first." });
  try { await notify.send(`✅ ${STORE_NAME}: test alert. New orders will appear here.`); res.json({ message: "Test alert sent. Check Telegram." }); }
  catch (err) { res.status(502).json({ error: `Telegram rejected the message: ${err.message}` }); }
}));

/* ------------------------------------------------------------ fallbacks */
app.get("*", (req, res, next) => {
  if (req.path.startsWith("/api/")) return res.status(404).json({ error: "API endpoint not found." });
  sendStorefront(req, res, next);
});
app.use((err, req, res, next) => { // eslint-disable-line no-unused-vars
  if (err.type === "entity.too.large") return res.status(413).json({ error: "That file or request is too large." });
  console.error("Unhandled error:", err.message);
  res.status(500).json({ error: "Unexpected server error." });
});

const ready = db.init();
if (require.main === module) {
  ready.then(() => app.listen(PORT, () => console.log(`Spice store running at http://localhost:${PORT} (database: ${db.kind})`)))
    .catch(err => { console.error("Database setup failed:", err.message); process.exit(1); });
}
module.exports = { app, ready, db };
