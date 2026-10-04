'use strict';

// Read-only database audit. It deliberately does not import src/db.js because
// that module runs migrations and seed logic when loaded.
const fs = require('fs');
const path = require('path');
const Database = require('better-sqlite3');

const dbPath = path.join(__dirname, '..', 'data', 'store.sqlite');
if (!fs.existsSync(dbPath)) {
  console.error(`Database not found: ${dbPath}`);
  console.error('No database was created or changed. Start the store once, then rerun this audit.');
  process.exit(2);
}

let db;
let failures = 0;
let warnings = 0;
function pass(message) { console.log(`PASS  ${message}`); }
function fail(message) { failures += 1; console.error(`FAIL  ${message}`); }
function warn(message) { warnings += 1; console.warn(`WARN  ${message}`); }

try {
  db = new Database(dbPath, { readonly: true, fileMustExist: true });
  db.pragma('query_only = ON');
  db.pragma('busy_timeout = 5000');

  const integrity = db.pragma('integrity_check');
  if (integrity.length === 1 && integrity[0].integrity_check === 'ok') pass('SQLite integrity_check');
  else fail(`SQLite integrity_check reported: ${JSON.stringify(integrity)}`);

  const fk = db.pragma('foreign_key_check');
  if (fk.length === 0) pass('Foreign-key consistency');
  else fail(`Foreign-key violations: ${JSON.stringify(fk.slice(0, 10))}`);

  const requiredTables = ['products', 'admins', 'orders', 'order_items', 'coupons'];
  const tables = new Set(db.prepare("SELECT name FROM sqlite_master WHERE type='table'").all().map(x => x.name));
  for (const table of requiredTables) {
    if (tables.has(table)) pass(`Required table exists: ${table}`);
    else fail(`Required table missing: ${table}`);
  }

  if (requiredTables.every(t => tables.has(t))) {
    const checks = [
      ['negative product stock', "SELECT COUNT(*) AS n FROM products WHERE stock < 0"],
      ['invalid product prices', "SELECT COUNT(*) AS n FROM products WHERE price <= 0 OR wholesale_price < 0"],
      ['invalid order totals/discounts', "SELECT COUNT(*) AS n FROM orders WHERE total < 0 OR discount < 0"],
      ['invalid order item quantities/prices', "SELECT COUNT(*) AS n FROM order_items WHERE quantity <= 0 OR unit_price < 0"],
      ['orders with no line items', "SELECT COUNT(*) AS n FROM orders o WHERE NOT EXISTS (SELECT 1 FROM order_items i WHERE i.order_id=o.id)"],
      ['invalid order statuses', "SELECT COUNT(*) AS n FROM orders WHERE status NOT IN ('New','Confirmed','Packed','Shipped','Delivered','Cancelled')"],
      ['invalid payment statuses', "SELECT COUNT(*) AS n FROM orders WHERE payment_status NOT IN ('Pending verification','Paid','Failed','Refunded')"],
      ['invalid percentage coupons', "SELECT COUNT(*) AS n FROM coupons WHERE discount_type='percent' AND (discount_value <= 0 OR discount_value > 100)"],
      ['invalid coupon values', "SELECT COUNT(*) AS n FROM coupons WHERE min_order < 0 OR discount_value <= 0"],
      ['malformed coupon expiry dates', "SELECT COUNT(*) AS n FROM coupons WHERE expires_at IS NOT NULL AND (length(expires_at) != 10 OR expires_at NOT GLOB '????-??-??')"]
    ];
    for (const [label, sql] of checks) {
      const n = db.prepare(sql).get().n;
      if (n === 0) pass(`${label}: none found`);
      else fail(`${label}: ${n} record(s)`);
    }

    const counts = {
      products: db.prepare('SELECT COUNT(*) AS n FROM products').get().n,
      activeProducts: db.prepare('SELECT COUNT(*) AS n FROM products WHERE active=1').get().n,
      admins: db.prepare('SELECT COUNT(*) AS n FROM admins').get().n,
      orders: db.prepare('SELECT COUNT(*) AS n FROM orders').get().n,
      coupons: db.prepare('SELECT COUNT(*) AS n FROM coupons').get().n
    };
    console.log('\nDatabase counts (read-only):');
    for (const [key, value] of Object.entries(counts)) console.log(`  ${key}: ${value}`);
    if (counts.admins === 0) warn('No admin account exists; create one before operating the store.');
    if (counts.products === 0) warn('No products exist.');
  }
} catch (err) {
  fail(`Audit could not complete: ${err.message}`);
} finally {
  if (db) db.close();
}

console.log(`\nDatabase audit finished: ${failures} failure(s), ${warnings} warning(s).`);
if (failures) process.exitCode = 1;
