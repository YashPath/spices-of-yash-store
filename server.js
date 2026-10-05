require("dotenv").config();
const express = require("express");
const path = require("path");
const helmet = require("helmet");
const session = require("express-session");
const SQLiteStore = require("connect-sqlite3")(session);
const rateLimit = require("express-rate-limit");
const crypto = require("crypto");
const db = require("./src/db");
const { z } = require("zod");

const app = express();
const PORT = Number(process.env.PORT || 3000);
const isProd = process.env.NODE_ENV === "production";
const sessionSecret = process.env.SESSION_SECRET;

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
  store: new SQLiteStore({ db: "sessions.sqlite", dir: path.join(__dirname, "data") }),
  secret: sessionSecret,
  resave: false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,
    secure: process.env.COOKIE_SECURE === "true" || isProd,
    sameSite: "lax",
    maxAge: 1000 * 60 * 60 * 8
  }
}));

const generalLimiter = rateLimit({ windowMs: 15 * 60 * 1000, limit: 300, standardHeaders: "draft-7", legacyHeaders: false });
const authLimiter = rateLimit({ windowMs: 15 * 60 * 1000, limit: 8, standardHeaders: "draft-7", legacyHeaders: false, message: { error: "Too many attempts. Please try again later." } });
const orderLimiter = rateLimit({ windowMs: 60 * 60 * 1000, limit: 12, standardHeaders: "draft-7", legacyHeaders: false });
app.use(generalLimiter);

// Explicit customer/admin page routes must run before static-file extension
// resolution so the root always opens the storefront, never admin.html.
const publicDir = path.join(__dirname, "public");
app.get("/", (req, res) => res.sendFile(path.join(publicDir, "index.html")));
app.get("/shop", (req, res) => res.sendFile(path.join(publicDir, "index.html")));
app.get("/admin", (req, res) => res.sendFile(path.join(publicDir, "admin.html")));
app.use(express.static(publicDir, { extensions: ["html"], maxAge: isProd ? "1h" : 0 }));

function csrfToken(req, res, next) {
  if (!req.session.csrfToken) req.session.csrfToken = crypto.randomBytes(32).toString("hex");
  res.locals.csrfToken = req.session.csrfToken;
  next();
}
app.use(csrfToken);
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
function cleanText(value, max = 200) {
  return String(value ?? "").trim().replace(/[<>]/g, "").slice(0, max);
}
function publicProduct(row) {
  return { id: row.id, name: row.name, slug: row.slug, category: row.category, description: row.description, price: row.price, wholesale_price: row.wholesale_price, wholesale_min_qty: row.wholesale_min_qty, weight: row.weight, image: row.image, featured: Boolean(row.featured), stock: row.stock };
}
const checkoutSchema = z.object({
  name: z.string().trim().min(2).max(100),
  phone: z.string().trim().regex(/^[6-9]\d{9}$/),
  email: z.string().trim().email().max(160).optional().or(z.literal("")),
  address: z.string().trim().min(10).max(500),
  city: z.string().trim().min(2).max(100),
  pincode: z.string().trim().regex(/^\d{6}$/),
  notes: z.string().trim().max(500).optional(),
  orderType: z.enum(['retail','wholesale']).default('retail'),
  businessName: z.string().trim().max(160).optional().default(''),
  couponCode: z.string().trim().max(40).optional().default(''),
  paymentMethod: z.enum(['UPI']).default('UPI'),
  items: z.array(z.object({ productId: z.number().int().positive(), quantity: z.number().int().min(1).max(20) })).min(1).max(30)
});

app.get("/api/health", (req, res) => {
  try {
    db.prepare("SELECT 1 AS ok").get();
    res.json({ status: "ok" });
  } catch {
    res.status(503).json({ status: "unavailable" });
  }
});

app.get("/api/config", (req, res) => res.json({
  storeName: process.env.STORE_NAME || "Spices of Yash",
  currency: process.env.CURRENCY || "INR",
  upiConfigured: Boolean(process.env.UPI_ID),
  csrfToken: req.session.csrfToken
}));

app.get("/api/products", (req, res) => {
  const rows = db.prepare("SELECT * FROM products WHERE active = 1 ORDER BY featured DESC, name ASC").all();
  res.json(rows.map(publicProduct));
});
app.get("/api/products/:slug", (req, res) => {
  const row = db.prepare("SELECT * FROM products WHERE slug = ? AND active = 1").get(req.params.slug);
  if (!row) return res.status(404).json({ error: "Product not found." });
  res.json(publicProduct(row));
});

app.post("/api/orders", orderLimiter, requireCsrf, (req, res) => {
  const parsed = checkoutSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "Please check your details and cart quantities." });
  const input = parsed.data;
  const uniqueIds = [...new Set(input.items.map(i => i.productId))];
  const placeholders = uniqueIds.map(() => "?").join(",");
  const products = db.prepare(`SELECT id, name, price, wholesale_price, wholesale_min_qty, stock, active FROM products WHERE id IN (${placeholders})`).all(...uniqueIds);
  const productMap = new Map(products.map(p => [p.id, p]));
  let subtotal = 0;
  const orderItems = [];
  for (const item of input.items) {
    const p = productMap.get(item.productId);
    if (!p || !p.active) return res.status(400).json({ error: "A product in your cart is no longer available." });
    if (p.stock < item.quantity) return res.status(409).json({ error: `${p.name} has only ${p.stock} units left.` });
    const price = input.orderType === 'wholesale' ? Number(p.wholesale_price) : Number(p.price);
    if (input.orderType === 'wholesale' && (!price || item.quantity < p.wholesale_min_qty)) return res.status(400).json({ error: `${p.name} requires at least ${p.wholesale_min_qty} units for wholesale pricing.` });
    subtotal += price * item.quantity;
    orderItems.push({ productId: p.id, name: p.name, price, quantity: item.quantity });
  }
  let discount = 0;
  let appliedCoupon = '';
  if (input.couponCode) {
    const coupon = db.prepare("SELECT * FROM coupons WHERE code = ? AND active = 1").get(input.couponCode.toUpperCase());
    if (!coupon) return res.status(400).json({ error: "That coupon is invalid or inactive." });
    if (coupon.expires_at && new Date(coupon.expires_at + 'T23:59:59Z') < new Date()) return res.status(400).json({ error: "That coupon has expired." });
    if (subtotal < coupon.min_order) return res.status(400).json({ error: `Coupon requires a minimum order of ₹${coupon.min_order}.` });
    discount = coupon.discount_type === 'percent' ? subtotal * coupon.discount_value / 100 : coupon.discount_value;
    discount = Math.min(subtotal, Math.round(discount * 100) / 100);
    appliedCoupon = coupon.code;
  }
  const total = Math.max(0, Math.round((subtotal - discount) * 100) / 100);
  const createOrder = db.transaction(() => {
    for (const item of orderItems) {
      const result = db.prepare("UPDATE products SET stock = stock - ? WHERE id = ? AND stock >= ?").run(item.quantity, item.productId, item.quantity);
      if (result.changes !== 1) throw new Error("STOCK_CONFLICT");
    }
    const result = db.prepare(`INSERT INTO orders (customer_name, phone, email, address, city, pincode, notes, total, status, created_at, order_type, business_name, payment_method, payment_status, discount, coupon_code)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'New', datetime('now'), ?, ?, ?, 'Pending verification', ?, ?)`)
      .run(cleanText(input.name, 100), cleanText(input.phone, 10), cleanText(input.email, 160), cleanText(input.address, 500), cleanText(input.city, 100), cleanText(input.pincode, 6), cleanText(input.notes, 500), total, input.orderType, cleanText(input.businessName, 160), input.paymentMethod, discount, appliedCoupon);
    const orderId = result.lastInsertRowid;
    const insertItem = db.prepare("INSERT INTO order_items (order_id, product_id, product_name, unit_price, quantity) VALUES (?, ?, ?, ?, ?)");
    for (const item of orderItems) insertItem.run(orderId, item.productId, item.name, item.price, item.quantity);
    return orderId;
  });
  try {
    const orderId = createOrder();
    res.status(201).json({ message: "Order received. UPI payment remains pending until the store verifies it.", orderId, subtotal, discount, total, paymentStatus: 'Pending verification', upiId: process.env.UPI_ID || '' });
  } catch (err) {
    if (err.message === "STOCK_CONFLICT") return res.status(409).json({ error: "Stock changed while placing the order. Refresh your cart and try again." });
    console.error("Order creation failed:", err.message);
    res.status(500).json({ error: "Could not place your order. Please try again." });
  }
});

app.get("/api/csrf", (req, res) => res.json({ csrfToken: req.session.csrfToken }));
app.post("/api/admin/login", authLimiter, requireCsrf, (req, res) => {
  const username = cleanText(req.body.username, 100);
  const password = String(req.body.password || "");
  const admin = db.prepare("SELECT id, username, password_hash FROM admins WHERE username = ?").get(username);
  const bcrypt = require("bcryptjs");
  const valid = admin ? bcrypt.compareSync(password, admin.password_hash) : bcrypt.compareSync(password, "$2a$10$abcdefghijklmnopqrstuuV3lB8N0RzX5cYQx7uYg0bWkP9z5lq");
  if (!admin || !valid) return res.status(401).json({ error: "Invalid username or password." });
  req.session.regenerate(err => {
    if (err) return res.status(500).json({ error: "Unable to start secure session." });
    req.session.adminId = admin.id;
    req.session.username = admin.username;
    req.session.csrfToken = crypto.randomBytes(32).toString("hex");
    res.json({ message: "Logged in.", username: admin.username, csrfToken: req.session.csrfToken });
  });
});
app.post("/api/admin/logout", requireAdmin, requireCsrf, (req, res) => {
  req.session.destroy(() => res.json({ message: "Logged out." }));
});
app.get("/api/admin/me", (req, res) => {
  if (!req.session.adminId) return res.status(401).json({ error: "Not logged in." });
  res.json({ username: req.session.username, csrfToken: req.session.csrfToken });
});
app.get("/api/admin/orders", requireAdmin, (req, res) => {
  const orders = db.prepare("SELECT * FROM orders ORDER BY created_at DESC LIMIT 300").all();
  const getItems = db.prepare("SELECT product_name, unit_price, quantity FROM order_items WHERE order_id = ?");
  res.json(orders.map(o => ({ ...o, items: getItems.all(o.id) })));
});
app.patch("/api/admin/orders/:id", requireAdmin, requireCsrf, (req, res) => {
  const status = String(req.body.status || "");
  const allowed = ["New", "Confirmed", "Packed", "Shipped", "Delivered", "Cancelled"];
  if (!allowed.includes(status)) return res.status(400).json({ error: "Invalid order status." });
  const result = db.prepare("UPDATE orders SET status = ? WHERE id = ?").run(status, Number(req.params.id));
  if (!result.changes) return res.status(404).json({ error: "Order not found." });
  res.json({ message: "Order updated." });
});
app.post("/api/admin/products", requireAdmin, requireCsrf, (req, res) => {
  const schema = z.object({
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
  const parsed = schema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "Please provide valid product details." });
  const p = parsed.data;
  const slugBase = p.name.toLowerCase().normalize("NFKD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 90) || "spice";
  const slug = `${slugBase}-${crypto.randomBytes(3).toString("hex")}`;
  const result = db.prepare("INSERT INTO products (name, slug, category, description, price, weight, image, stock, featured, active, wholesale_price, wholesale_min_qty) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)")
    .run(p.name, slug, p.category, p.description, p.price, p.weight, p.image, p.stock, p.featured ? 1 : 0, p.wholesale_price, p.wholesale_min_qty);
  res.status(201).json({ id: result.lastInsertRowid, slug });
});
app.patch("/api/admin/products/:id", requireAdmin, requireCsrf, (req, res) => {
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
  const setClause = Object.keys(normalized).map(k => `${k} = ?`).join(", ");
  const result = db.prepare(`UPDATE products SET ${setClause} WHERE id = ?`).run(...Object.values(normalized), Number(req.params.id));
  if (!result.changes) return res.status(404).json({ error: "Product not found." });
  res.json({ message: "Product updated." });
});
app.patch("/api/admin/orders/:id/payment", requireAdmin, requireCsrf, (req, res) => {
  const paymentStatus = String(req.body.paymentStatus || "");
  if (!["Pending verification", "Paid", "Failed", "Refunded"].includes(paymentStatus)) return res.status(400).json({ error: "Invalid payment status." });
  const result = db.prepare("UPDATE orders SET payment_status = ? WHERE id = ?").run(paymentStatus, Number(req.params.id));
  if (!result.changes) return res.status(404).json({ error: "Order not found." });
  res.json({ message: "Payment status updated." });
});
app.get("/api/admin/coupons", requireAdmin, (req, res) => {
  res.json(db.prepare("SELECT * FROM coupons ORDER BY created_at DESC").all());
});
app.post("/api/admin/coupons", requireAdmin, requireCsrf, (req, res) => {
  const schema = z.object({ code: z.string().trim().min(3).max(40).regex(/^[A-Za-z0-9_-]+$/), discountType: z.enum(['percent','fixed']), discountValue: z.number().positive().max(100000), minOrder: z.number().min(0).max(1000000).default(0), expiresAt: z.string().max(10).optional().default('') });
  const parsed = schema.safeParse(req.body);
  if (!parsed.success || (parsed.data?.discountType === 'percent' && parsed.data.discountValue > 100)) return res.status(400).json({error:'Please check coupon fields; percentage must be 1–100.'});
  const c = parsed.data;
  try {
    const result = db.prepare("INSERT INTO coupons (code,discount_type,discount_value,min_order,active,expires_at) VALUES (?,?,?,?,1,?)")
      .run(c.code.toUpperCase(), c.discountType, c.discountValue, c.minOrder, c.expiresAt || null);
    res.status(201).json({id:result.lastInsertRowid, message:'Coupon created.'});
  } catch { res.status(409).json({error:'Coupon code already exists.'}); }
});
app.patch("/api/admin/coupons/:id", requireAdmin, requireCsrf, (req,res) => {
  const active = req.body.active;
  if (typeof active !== 'boolean') return res.status(400).json({error:'Active must be true or false.'});
  const result = db.prepare("UPDATE coupons SET active=? WHERE id=?").run(active?1:0, Number(req.params.id));
  if (!result.changes) return res.status(404).json({error:'Coupon not found.'});
  res.json({message:'Coupon updated.'});
});
app.get("/api/admin/reports", requireAdmin, (req,res) => {
  const monthly = db.prepare("SELECT strftime('%Y-%m',created_at) month, COUNT(*) orders, ROUND(SUM(CASE WHEN status != 'Cancelled' THEN total ELSE 0 END),2) revenue FROM orders GROUP BY month ORDER BY month DESC LIMIT 12").all();
  const bestSellers = db.prepare("SELECT oi.product_name name, SUM(oi.quantity) units, ROUND(SUM(oi.unit_price*oi.quantity),2) gross FROM order_items oi JOIN orders o ON o.id=oi.order_id WHERE o.status != 'Cancelled' GROUP BY oi.product_name ORDER BY units DESC LIMIT 10").all();
  const lowStock = db.prepare("SELECT id,name,stock FROM products WHERE active=1 AND stock<=10 ORDER BY stock ASC,name ASC").all();
  const payments = db.prepare("SELECT payment_status status,COUNT(*) count FROM orders GROUP BY payment_status").all();
  res.json({monthly,bestSellers,lowStock,payments});
});
app.get("/api/admin/reports.csv", requireAdmin, (req,res) => {
  const rows = db.prepare("SELECT id,created_at,customer_name,phone,city,pincode,order_type,business_name,total,discount,coupon_code,payment_method,payment_status,status FROM orders ORDER BY created_at DESC").all();
  const cols = ['id','created_at','customer_name','phone','city','pincode','order_type','business_name','total','discount','coupon_code','payment_method','payment_status','status'];
  const cell = v => `"${String(v ?? '').replace(/"/g,'""')}"`;
  res.setHeader('Content-Type','text/csv; charset=utf-8'); res.setHeader('Content-Disposition','attachment; filename="spices-of-yash-orders.csv"');
  res.send([cols.join(','),...rows.map(r=>cols.map(c=>cell(r[c])).join(','))].join('\r\n'));
});
app.get("/api/admin/summary", requireAdmin, (req, res) => {
  const products = db.prepare("SELECT COUNT(*) AS count FROM products WHERE active = 1").get().count;
  const orders = db.prepare("SELECT COUNT(*) AS count FROM orders").get().count;
  const revenue = db.prepare("SELECT COALESCE(SUM(total),0) AS total FROM orders WHERE status != 'Cancelled'").get().total;
  const pending = db.prepare("SELECT COUNT(*) AS count FROM orders WHERE status IN ('New','Confirmed')").get().count;
  res.json({ products, orders, revenue, pending });
});

app.get("*", (req, res) => {
  if (req.path.startsWith("/api/")) return res.status(404).json({ error: "API endpoint not found." });
  res.sendFile(path.join(publicDir, "index.html"));
});
app.use((err, req, res, next) => {
  console.error("Unhandled error:", err.message);
  res.status(500).json({ error: "Unexpected server error." });
});

app.listen(PORT, () => console.log(`Spice store running at http://localhost:${PORT}`));
