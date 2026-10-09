const fs = require("fs");
const path = require("path");
const Database = require("better-sqlite3");
const dataDir = path.join(__dirname, "..", "data");
fs.mkdirSync(dataDir, { recursive: true });
const db = new Database(path.join(dataDir, "store.sqlite"));
db.pragma("journal_mode = WAL");
db.pragma("foreign_keys = ON");
db.pragma("busy_timeout = 5000");

db.exec(`
CREATE TABLE IF NOT EXISTS products (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  category TEXT NOT NULL,
  description TEXT NOT NULL,
  price REAL NOT NULL CHECK(price > 0),
  weight TEXT NOT NULL,
  image TEXT NOT NULL DEFAULT '',
  stock INTEGER NOT NULL DEFAULT 0 CHECK(stock >= 0),
  featured INTEGER NOT NULL DEFAULT 0,
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS admins (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS orders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_name TEXT NOT NULL,
  phone TEXT NOT NULL,
  email TEXT NOT NULL DEFAULT '',
  address TEXT NOT NULL,
  city TEXT NOT NULL,
  pincode TEXT NOT NULL,
  notes TEXT NOT NULL DEFAULT '',
  total REAL NOT NULL,
  status TEXT NOT NULL DEFAULT 'New',
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS order_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
  product_name TEXT NOT NULL,
  unit_price REAL NOT NULL,
  quantity INTEGER NOT NULL CHECK(quantity > 0)
);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at);
CREATE INDEX IF NOT EXISTS idx_products_active ON products(active);
CREATE TABLE IF NOT EXISTS coupons (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL UNIQUE,
  discount_type TEXT NOT NULL CHECK(discount_type IN ('percent','fixed')),
  discount_value REAL NOT NULL CHECK(discount_value > 0),
  min_order REAL NOT NULL DEFAULT 0 CHECK(min_order >= 0),
  active INTEGER NOT NULL DEFAULT 1,
  expires_at TEXT DEFAULT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

`);

function addColumn(table, column, definition) {
  const columns = db.prepare(`PRAGMA table_info(${table})`).all().map(c => c.name);
  if (!columns.includes(column)) db.exec(`ALTER TABLE ${table} ADD COLUMN ${column} ${definition}`);
}
addColumn('products', 'wholesale_price', 'REAL NOT NULL DEFAULT 0');
addColumn('products', 'wholesale_min_qty', 'INTEGER NOT NULL DEFAULT 10');
addColumn('orders', 'order_type', "TEXT NOT NULL DEFAULT 'retail'");
addColumn('orders', 'business_name', "TEXT NOT NULL DEFAULT ''");
addColumn('orders', 'payment_method', "TEXT NOT NULL DEFAULT 'UPI'");
addColumn('orders', 'payment_status', "TEXT NOT NULL DEFAULT 'Pending verification'");
addColumn('orders', 'discount', 'REAL NOT NULL DEFAULT 0');
addColumn('orders', 'coupon_code', "TEXT NOT NULL DEFAULT ''");
addColumn('orders', 'razorpay_order_id', "TEXT NOT NULL DEFAULT ''");
addColumn('orders', 'razorpay_payment_id', "TEXT NOT NULL DEFAULT ''");
addColumn('orders', 'payment_token_hash', "TEXT NOT NULL DEFAULT ''");

const count = db.prepare("SELECT COUNT(*) AS n FROM products").get().n;
if (count === 0) {
  const insert = db.prepare(`INSERT INTO products (name, slug, category, description, price, weight, image, stock, featured, wholesale_price, wholesale_min_qty)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`);
  const seed = [
    ["Kashmiri Red Chilli Powder", "kashmiri-red-chilli", "Ground Spices", "Vibrant colour and balanced warmth for curries, marinades and everyday cooking.", 149, "100 g", "https://images.unsplash.com/photo-1596040033229-a9821ebd058d?auto=format&fit=crop&w=900&q=85", 80, 1],
    ["Golden Turmeric Powder", "golden-turmeric", "Ground Spices", "Earthy turmeric powder for dals, vegetables and home-style recipes.", 99, "100 g", "https://images.unsplash.com/photo-1615485500704-8e990f9900f5?auto=format&fit=crop&w=900&q=85", 100, 1],
    ["Green Cardamom", "green-cardamom", "Whole Spices", "Aromatic green cardamom pods for chai, desserts and festive cooking.", 249, "50 g", "https://images.unsplash.com/photo-1615485290382-441e4d049cb5?auto=format&fit=crop&w=900&q=85", 45, 1],
    ["Cumin Seeds", "cumin-seeds", "Whole Spices", "Warm, nutty cumin seeds for tempering, spice blends and roasted dishes.", 89, "100 g", "https://images.unsplash.com/photo-1599909533608-4f8d5f4f7d2a?auto=format&fit=crop&w=900&q=85", 70, 0],
    ["Black Peppercorns", "black-peppercorns", "Whole Spices", "Bold whole peppercorns with a sharp aroma for mills and spice mixes.", 129, "100 g", "https://images.unsplash.com/photo-1505576399273-565b52d4ac71?auto=format&fit=crop&w=900&q=85", 60, 0],
    ["Garam Masala", "garam-masala", "Blended Spices", "A versatile warming blend for finishing curries, gravies and vegetables.", 119, "100 g", "https://images.unsplash.com/photo-1532336414038-cf19250c5757?auto=format&fit=crop&w=900&q=85", 90, 1]
  ];
  const tx = db.transaction(items => items.forEach(p => insert.run(...p, Math.round(p[4] * 0.8), 10)));
  tx(seed);
}

// Create initial admin if the database has no admin.
const bootstrapUsername = process.env.ADMIN_BOOTSTRAP_USERNAME;
const bootstrapPassword = process.env.ADMIN_BOOTSTRAP_PASSWORD;

if (bootstrapUsername && bootstrapPassword) {
  const adminCount = db
    .prepare("SELECT COUNT(*) AS count FROM admins")
    .get().count;

  if (adminCount === 0) {
    const bcrypt = require("bcryptjs");
    const passwordHash = bcrypt.hashSync(bootstrapPassword, 12);

    db.prepare(
      "INSERT INTO admins (username, password_hash) VALUES (?, ?)"
    ).run(bootstrapUsername, passwordHash);

    console.log("Initial admin account created.");
  }
}
module.exports = db;
