// Copy everything from the local SQLite file (data/store.sqlite) into the
// Postgres database in DATABASE_URL — products, orders, coupons, admins, images.
// Usage:  DATABASE_URL=postgres://... npm run db:copy-to-postgres
// Safe to run on an empty Postgres database; it refuses if orders already exist there.
require("dotenv").config();
const path = require("path");
const fs = require("fs");
const Database = require("better-sqlite3");

if (!process.env.DATABASE_URL) { console.error("Set DATABASE_URL to your Postgres connection string first."); process.exit(1); }
const file = path.resolve(process.env.SQLITE_FILE || path.join(process.env.DATA_DIR || path.join(__dirname, "..", "data"), "store.sqlite"));
if (!fs.existsSync(file)) { console.error(`SQLite file not found: ${file}`); process.exit(1); }

(async () => {
  const src = new Database(file, { readonly: true, fileMustExist: true });
  const db = require("../src/db");
  await db.init();
  const existing = (await db.get("SELECT COUNT(*) AS n FROM orders")).n;
  if (existing > 0 && process.argv[2] !== "--force") { console.error(`Postgres already has ${existing} orders. Nothing copied. Use --force to copy anyway.`); process.exit(1); }

  const tables = ["products", "admins", "coupons", "orders", "order_items", "images"];
  await db.tx(async t => {
    await t.exec("TRUNCATE order_items, orders, coupons, admins, images, products RESTART IDENTITY CASCADE");
    for (const table of tables) {
      const hasTable = src.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name=?").get(table);
      if (!hasTable) continue;
      const pgCols = (await t.all("SELECT column_name FROM information_schema.columns WHERE table_name = ?", [table])).map(c => c.column_name);
      const rows = src.prepare(`SELECT * FROM ${table}`).all();
      for (const row of rows) {
        const cols = Object.keys(row).filter(c => pgCols.includes(c));
        await t.run(`INSERT INTO ${table} (${cols.join(",")}) VALUES (${cols.map(() => "?").join(",")}) RETURNING id`, cols.map(c => row[c]));
      }
      await t.exec(`SELECT setval(pg_get_serial_sequence('${table}', 'id'), COALESCE((SELECT MAX(id) FROM ${table}), 0) + 1, false)`);
      console.log(`${table}: ${rows.length} rows copied`);
    }
  });
  src.close();
  await db.close();
  console.log("Done. Your Postgres database now matches the SQLite file.");
})().catch(err => { console.error("Copy failed:", err.message); process.exit(1); });
