const Database = require("better-sqlite3");
const dbPath = process.argv[2];
let db;
try {
  db = new Database(dbPath, { readonly: true, fileMustExist: true });
  const result = db.pragma("integrity_check", { simple: true });
  console.log("SQLite integrity_check:", result);
  db.close();
  process.exit(result === "ok" ? 0 : 1);
} catch (error) {
  console.error("SQLite check error:", error.message);
  try { if (db) db.close(); } catch {}
  process.exit(2);
}
