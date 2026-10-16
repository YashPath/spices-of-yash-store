// Database adapter for Spices of Yash.
//
//  • DATABASE_URL set  → PostgreSQL (recommended for hosting: Render free disks are wiped on redeploy)
//  • otherwise         → SQLite file in DATA_DIR (default ./data) — great for local development
//
// Every query is written once with "?" placeholders and runs on both engines:
//   await db.all(sql, params)  → rows
//   await db.get(sql, params)  → first row or undefined
//   await db.run(sql, params)  → { changes, lastId }
//   await db.tx(async t => { ... t.run(...) ... })  → runs inside one transaction
const fs = require("fs");
const path = require("path");

const usePg = Boolean(process.env.DATABASE_URL);
const dataDir = path.resolve(process.env.DATA_DIR || path.join(__dirname, "..", "data"));
const nowText = () => new Date().toISOString().replace("T", " ").slice(0, 19); // "YYYY-MM-DD HH:MM:SS" UTC

/* ------------------------------------------------------------------ engines */
let engine;

if (usePg) {
  const { Pool, types } = require("pg");
  types.setTypeParser(20, v => parseInt(v, 10));   // COUNT(*) / SUM(int) → number
  types.setTypeParser(1700, v => parseFloat(v));   // NUMERIC → number
  const ssl = /localhost|127\.0\.0\.1/.test(process.env.DATABASE_URL) || process.env.DATABASE_SSL === "false" ? false : { rejectUnauthorized: false };
  const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl, max: Number(process.env.DATABASE_POOL_MAX || 5) });
  const toPg = sql => { let i = 0; return sql.replace(/\?/g, () => `$${++i}`); };
  const runner = client => ({
    async all(sql, params = []) { return (await client.query(toPg(sql), params)).rows; },
    async get(sql, params = []) { return (await client.query(toPg(sql), params)).rows[0]; },
    async run(sql, params = []) {
      const isInsert = /^\s*insert/i.test(sql) && !/returning/i.test(sql);
      const r = await client.query(toPg(isInsert ? `${sql} RETURNING id` : sql), params);
      return { changes: r.rowCount, lastId: isInsert ? r.rows[0]?.id : undefined };
    },
    async exec(sql) { await client.query(sql); }
  });
  engine = {
    kind: "postgres",
    pool,
    ...runner(pool),
    async tx(fn) {
      const client = await pool.connect();
      try {
        await client.query("BEGIN");
        const out = await fn(runner(client));
        await client.query("COMMIT");
        return out;
      } catch (err) {
        await client.query("ROLLBACK").catch(() => {});
        throw err;
      } finally { client.release(); }
    },
    async close() { await pool.end(); }
  };
} else {
  const Database = require("better-sqlite3");
  fs.mkdirSync(dataDir, { recursive: true });
  const sqlite = new Database(path.join(dataDir, "store.sqlite"));
  sqlite.pragma("journal_mode = WAL");
  sqlite.pragma("foreign_keys = ON");
  sqlite.pragma("busy_timeout = 5000");
  const r = {
    async all(sql, params = []) { return sqlite.prepare(sql).all(...params); },
    async get(sql, params = []) { return sqlite.prepare(sql).get(...params); },
    async run(sql, params = []) { const x = sqlite.prepare(sql).run(...params); return { changes: x.changes, lastId: Number(x.lastInsertRowid) }; },
    async exec(sql) { sqlite.exec(sql); }
  };
  // better-sqlite3 is synchronous, so a transaction body that only awaits these
  // helpers finishes before any other request can run.
  let queue = Promise.resolve();
  engine = {
    kind: "sqlite",
    sqlite,
    ...r,
    tx(fn) {
      const job = queue.then(async () => {
        sqlite.exec("BEGIN IMMEDIATE");
        try { const out = await fn(r); sqlite.exec("COMMIT"); return out; }
        catch (err) { if (sqlite.inTransaction) sqlite.exec("ROLLBACK"); throw err; }
      });
      queue = job.catch(() => {});
      return job;
    },
    async close() { sqlite.close(); }
  };
}

/* ------------------------------------------------------------------- schema */
const PK = usePg ? "SERIAL PRIMARY KEY" : "INTEGER PRIMARY KEY AUTOINCREMENT";
const REAL = usePg ? "DOUBLE PRECISION" : "REAL";
const BLOB = usePg ? "BYTEA" : "BLOB";
const NOW_DEFAULT = usePg ? "(to_char(now() AT TIME ZONE 'utc', 'YYYY-MM-DD HH24:MI:SS'))" : "(datetime('now'))";

const tables = [
  `CREATE TABLE IF NOT EXISTS products (
    id ${PK}, name TEXT NOT NULL, slug TEXT NOT NULL UNIQUE, category TEXT NOT NULL, description TEXT NOT NULL,
    price ${REAL} NOT NULL CHECK(price > 0), weight TEXT NOT NULL, image TEXT NOT NULL DEFAULT '',
    stock INTEGER NOT NULL DEFAULT 0 CHECK(stock >= 0), featured INTEGER NOT NULL DEFAULT 0, active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT ${NOW_DEFAULT})`,
  `CREATE TABLE IF NOT EXISTS admins (
    id ${PK}, username TEXT NOT NULL UNIQUE, password_hash TEXT NOT NULL, created_at TEXT NOT NULL DEFAULT ${NOW_DEFAULT})`,
  `CREATE TABLE IF NOT EXISTS orders (
    id ${PK}, customer_name TEXT NOT NULL, phone TEXT NOT NULL, email TEXT NOT NULL DEFAULT '', address TEXT NOT NULL,
    city TEXT NOT NULL, pincode TEXT NOT NULL, notes TEXT NOT NULL DEFAULT '', total ${REAL} NOT NULL,
    status TEXT NOT NULL DEFAULT 'New', created_at TEXT NOT NULL)`,
  `CREATE TABLE IF NOT EXISTS order_items (
    id ${PK}, order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products(id) ON DELETE SET NULL, product_name TEXT NOT NULL,
    unit_price ${REAL} NOT NULL, quantity INTEGER NOT NULL CHECK(quantity > 0))`,
  `CREATE TABLE IF NOT EXISTS coupons (
    id ${PK}, code TEXT NOT NULL UNIQUE, discount_type TEXT NOT NULL CHECK(discount_type IN ('percent','fixed')),
    discount_value ${REAL} NOT NULL CHECK(discount_value > 0), min_order ${REAL} NOT NULL DEFAULT 0 CHECK(min_order >= 0),
    active INTEGER NOT NULL DEFAULT 1, expires_at TEXT DEFAULT NULL, created_at TEXT NOT NULL DEFAULT ${NOW_DEFAULT})`,
  `CREATE TABLE IF NOT EXISTS images (
    id ${PK}, mime TEXT NOT NULL, data ${BLOB} NOT NULL, bytes INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL DEFAULT ${NOW_DEFAULT})`,
  `CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at)`,
  `CREATE INDEX IF NOT EXISTS idx_products_active ON products(active)`,
  `CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id)`
];

const columns = [
  ["products", "wholesale_price", `${REAL} NOT NULL DEFAULT 0`],
  ["products", "wholesale_min_qty", "INTEGER NOT NULL DEFAULT 10"],
  ["orders", "order_type", "TEXT NOT NULL DEFAULT 'retail'"],
  ["orders", "business_name", "TEXT NOT NULL DEFAULT ''"],
  ["orders", "payment_method", "TEXT NOT NULL DEFAULT 'UPI'"],
  ["orders", "payment_status", "TEXT NOT NULL DEFAULT 'Pending verification'"],
  ["orders", "discount", `${REAL} NOT NULL DEFAULT 0`],
  ["orders", "coupon_code", "TEXT NOT NULL DEFAULT ''"],
  ["orders", "delivery_fee", `${REAL} NOT NULL DEFAULT 0`],
  ["orders", "razorpay_order_id", "TEXT NOT NULL DEFAULT ''"],
  ["orders", "razorpay_payment_id", "TEXT NOT NULL DEFAULT ''"],
  ["orders", "payment_token_hash", "TEXT NOT NULL DEFAULT ''"]
];

async function addColumn(table, column, definition) {
  if (usePg) return engine.exec(`ALTER TABLE ${table} ADD COLUMN IF NOT EXISTS ${column} ${definition}`);
  const existing = (await engine.all(`PRAGMA table_info(${table})`)).map(c => c.name);
  if (!existing.includes(column)) await engine.exec(`ALTER TABLE ${table} ADD COLUMN ${column} ${definition}`);
}

const SEED = [
  ["Kashmiri Red Chilli Powder", "kashmiri-red-chilli", "Ground Spices", "Vibrant colour and balanced warmth for curries, marinades and everyday cooking.", 149, "100 g", 80, 1],
  ["Golden Turmeric Powder", "golden-turmeric", "Ground Spices", "Earthy turmeric powder for dals, vegetables and home-style recipes.", 99, "100 g", 100, 1],
  ["Green Cardamom", "green-cardamom", "Whole Spices", "Aromatic green cardamom pods for chai, desserts and festive cooking.", 249, "50 g", 45, 1],
  ["Cumin Seeds", "cumin-seeds", "Whole Spices", "Warm, nutty cumin seeds for tempering, spice blends and roasted dishes.", 89, "100 g", 70, 0],
  ["Black Peppercorns", "black-peppercorns", "Whole Spices", "Bold whole peppercorns with a sharp aroma for mills and spice mixes.", 129, "100 g", 60, 0],
  ["Garam Masala", "garam-masala", "Blended Spices", "A versatile warming blend for finishing curries, gravies and vegetables.", 119, "100 g", 90, 1]
];

let initPromise;
function init() {
  if (!initPromise) initPromise = (async () => {
    for (const sql of tables) await engine.exec(sql);
    for (const [t, c, d] of columns) await addColumn(t, c, d);

    // Seed products on an empty database.
    const { n } = await engine.get("SELECT COUNT(*) AS n FROM products");
    if (Number(n) === 0) {
      await engine.tx(async t => {
        for (const [name, slug, category, description, price, weight, stock, featured] of SEED) {
          await t.run(`INSERT INTO products (name, slug, category, description, price, weight, image, stock, featured, wholesale_price, wholesale_min_qty)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`, [name, slug, category, description, price, weight, `/images/${slug}.webp`, stock, featured, Math.round(price * 0.8), 10]);
        }
      });
    }

    // Point old hotlinked Unsplash images at the bundled local images.
    for (const p of await engine.all("SELECT id, slug, image FROM products")) {
      const local = path.join(__dirname, "..", "public", "images", `${p.slug}.webp`);
      if ((!p.image || p.image.startsWith("https://images.unsplash.com/")) && fs.existsSync(local)) {
        await engine.run("UPDATE products SET image = ? WHERE id = ?", [`/images/${p.slug}.webp`, p.id]);
      }
    }

    // Create the first admin from env vars when there is none (handy on a fresh hosted database).
    const u = process.env.ADMIN_BOOTSTRAP_USERNAME, pw = process.env.ADMIN_BOOTSTRAP_PASSWORD;
    if (u && pw) {
      const { count } = await engine.get("SELECT COUNT(*) AS count FROM admins");
      if (Number(count) === 0) {
        const bcrypt = require("bcryptjs");
        await engine.run("INSERT INTO admins (username, password_hash) VALUES (?, ?)", [u, bcrypt.hashSync(pw, 12)]);
        console.log("Initial admin account created.");
      }
    }
  })();
  return initPromise;
}

/* ----------------------------------------------------------------- sessions */
function sessionStore(session) {
  if (usePg) {
    const PgStore = require("connect-pg-simple")(session);
    return new PgStore({ pool: engine.pool, tableName: "sessions", createTableIfMissing: true });
  }
  const SQLiteStore = require("connect-sqlite3")(session);
  return new SQLiteStore({ db: "sessions.sqlite", dir: dataDir });
}

module.exports = { ...engine, init, now: nowText, sessionStore, dataDir, usePg };
