// Starts the store on a throwaway SQLite database for the browser tests.
const fs = require("fs");
const os = require("os");
const path = require("path");
process.env.DATA_DIR = fs.mkdtempSync(path.join(os.tmpdir(), "spices-e2e-"));
process.env.SESSION_SECRET = "e2e-secret-".padEnd(48, "x");
process.env.ADMIN_BOOTSTRAP_USERNAME = "admin";
process.env.ADMIN_BOOTSTRAP_PASSWORD = "e2e-password-123";
process.env.UPI_ID = "teststore@upi";
process.env.PORT = process.env.PORT || "3100";
process.env.ORDER_RATE_LIMIT = "1000";
delete process.env.DATABASE_URL;
delete process.env.TELEGRAM_BOT_TOKEN;
const { app, ready } = require("../../server");
ready.then(() => app.listen(Number(process.env.PORT), () => console.log(`e2e store on ${process.env.PORT}`)));
