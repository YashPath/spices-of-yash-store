// API tests — run with `npm run test:api`.
// Uses a throwaway SQLite database by default. Set TEST_DATABASE_URL to run the
// same tests against Postgres (the database is wiped first, so never point it at production).
const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("fs");
const os = require("os");
const path = require("path");

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "spices-test-"));
process.env.DATA_DIR = tmp;
process.env.SESSION_SECRET = "test-secret-".padEnd(48, "x");
process.env.ADMIN_BOOTSTRAP_USERNAME = "admin";
process.env.ADMIN_BOOTSTRAP_PASSWORD = "test-password-123";
process.env.UPI_ID = "teststore@upi";
process.env.FREE_DELIVERY_MIN = "799";
process.env.DELIVERY_FEE = "49";
process.env.ORDER_RATE_LIMIT = "1000";
process.env.NODE_ENV = "test";
delete process.env.TELEGRAM_BOT_TOKEN;
if (process.env.TEST_DATABASE_URL) process.env.DATABASE_URL = process.env.TEST_DATABASE_URL;
else delete process.env.DATABASE_URL;

const request = require("supertest");
let app, db;

before(async () => {
  if (process.env.DATABASE_URL) {
    const { Client } = require("pg");
    const c = new Client({ connectionString: process.env.DATABASE_URL });
    await c.connect();
    await c.query("DROP TABLE IF EXISTS order_items, orders, coupons, admins, images, products, sessions CASCADE");
    await c.end();
  }
  ({ app, db } = require("../server"));
  await require("../server").ready;
});
after(async () => {
  await db.close();
  fs.rmSync(tmp, { recursive: true, force: true });
});

async function shopper() {
  const agent = request.agent(app);
  const cfg = (await agent.get("/api/config").expect(200)).body;
  return { agent, csrf: cfg.csrfToken, cfg };
}
async function adminAgent() {
  const { agent, csrf } = await shopper();
  const r = await agent.post("/api/admin/login").set("X-CSRF-Token", csrf).send({ username: "admin", password: "test-password-123" }).expect(200);
  return { agent, csrf: r.body.csrfToken };
}
const customer = { name: "Test Customer", phone: "9876543210", address: "12 Rajpur Road, near clock tower", city: "Dehradun", pincode: "248001" };
const products = async () => (await request(app).get("/api/products").expect(200)).body;

test("health check reports the database engine", async () => {
  const r = await request(app).get("/api/health").expect(200);
  assert.equal(r.body.status, "ok");
  assert.equal(r.body.database, process.env.DATABASE_URL ? "postgres" : "sqlite");
});

test("catalogue is seeded with local images", async () => {
  const list = await products();
  assert.equal(list.length, 6);
  for (const p of list) assert.match(p.image, /^\/images\/[a-z-]+\.webp$/);
});

test("config exposes delivery settings", async () => {
  const { cfg } = await shopper();
  assert.equal(cfg.freeDeliveryMin, 799);
  assert.equal(cfg.deliveryFee, 49);
  assert.ok(cfg.csrfToken);
});

test("orders without a CSRF token are rejected", async () => {
  const [p] = await products();
  await request(app).post("/api/orders").send({ ...customer, items: [{ productId: p.id, quantity: 1 }] }).expect(403);
});

test("small order pays delivery, stock goes down", async () => {
  const [p] = await products();
  const { agent, csrf } = await shopper();
  const r = await agent.post("/api/orders").set("X-CSRF-Token", csrf).send({ ...customer, items: [{ productId: p.id, quantity: 2 }] }).expect(201);
  assert.equal(r.body.subtotal, p.price * 2);
  assert.equal(r.body.deliveryFee, 49);
  assert.equal(r.body.total, p.price * 2 + 49);
  assert.match(r.body.upiQr, /^data:image\/png;base64,/);
  assert.match(r.body.upiLink, /^upi:\/\/pay\?pa=teststore%40upi/);
  const after = (await products()).find(x => x.id === p.id);
  assert.equal(after.stock, p.stock - 2);
});

test("order of ₹799 or more gets free delivery", async () => {
  const p = (await products()).find(x => x.slug === "green-cardamom"); // ₹249
  const { agent, csrf } = await shopper();
  const r = await agent.post("/api/orders").set("X-CSRF-Token", csrf).send({ ...customer, items: [{ productId: p.id, quantity: 4 }] }).expect(201);
  assert.equal(r.body.subtotal, 996);
  assert.equal(r.body.deliveryFee, 0);
  assert.equal(r.body.total, 996);
});

test("repeated lines are merged before the stock check", async () => {
  const p = (await products()).find(x => x.slug === "black-peppercorns");
  const { agent, csrf } = await shopper();
  const half = Math.ceil(p.stock / 2) + 1;
  const r = await agent.post("/api/orders").set("X-CSRF-Token", csrf).send({ ...customer, items: [{ productId: p.id, quantity: Math.min(20, half) }, { productId: p.id, quantity: Math.min(20, half) }, { productId: p.id, quantity: 20 }, { productId: p.id, quantity: 20 }] });
  assert.equal(r.status, 409);
  const after = (await products()).find(x => x.id === p.id);
  assert.equal(after.stock, p.stock, "stock must be unchanged after a rejected order");
});

test("wholesale needs the minimum quantity", async () => {
  const [p] = await products();
  const { agent, csrf } = await shopper();
  const bad = await agent.post("/api/orders").set("X-CSRF-Token", csrf).send({ ...customer, orderType: "wholesale", items: [{ productId: p.id, quantity: 2 }] }).expect(400);
  assert.match(bad.body.error, /at least 10 units/);
  const ok = await agent.post("/api/orders").set("X-CSRF-Token", csrf).send({ ...customer, orderType: "wholesale", businessName: "Test Kirana", items: [{ productId: p.id, quantity: 10 }] }).expect(201);
  assert.equal(ok.body.subtotal, p.wholesale_price * 10);
});

test("invalid phone number is rejected", async () => {
  const [p] = await products();
  const { agent, csrf } = await shopper();
  await agent.post("/api/orders").set("X-CSRF-Token", csrf).send({ ...customer, phone: "12345", items: [{ productId: p.id, quantity: 1 }] }).expect(400);
});

test("admin routes need a login", async () => {
  await request(app).get("/api/admin/orders").expect(401);
  await request(app).get("/api/admin/products").expect(401);
});

test("wrong admin password is rejected", async () => {
  const { agent, csrf } = await shopper();
  await agent.post("/api/admin/login").set("X-CSRF-Token", csrf).send({ username: "admin", password: "nope" }).expect(401);
});

test("admin sees orders with delivery fee and can update status and payment", async () => {
  const { agent, csrf } = await adminAgent();
  const orders = (await agent.get("/api/admin/orders").expect(200)).body;
  assert.ok(orders.length >= 3);
  const small = orders.find(o => o.delivery_fee === 49);
  assert.ok(small, "an order with a delivery fee exists");
  assert.ok(small.items.length >= 1);
  await agent.patch(`/api/admin/orders/${small.id}`).set("X-CSRF-Token", csrf).send({ status: "Packed" }).expect(200);
  await agent.patch(`/api/admin/orders/${small.id}`).set("X-CSRF-Token", csrf).send({ status: "Teleported" }).expect(400);
  await agent.patch(`/api/admin/orders/${small.id}/payment`).set("X-CSRF-Token", csrf).send({ paymentStatus: "Paid" }).expect(200);
  const summary = (await agent.get("/api/admin/summary").expect(200)).body;
  assert.equal(summary.revenue, small.total);
});

test("coupons: create, apply, reject duplicates", async () => {
  const admin = await adminAgent();
  await admin.agent.post("/api/admin/coupons").set("X-CSRF-Token", admin.csrf).send({ code: "yash10", discountType: "percent", discountValue: 10, minOrder: 0 }).expect(201);
  await admin.agent.post("/api/admin/coupons").set("X-CSRF-Token", admin.csrf).send({ code: "YASH10", discountType: "percent", discountValue: 10, minOrder: 0 }).expect(409);
  const p = (await products()).find(x => x.slug === "cumin-seeds"); // ₹89
  const { agent, csrf } = await shopper();
  const r = await agent.post("/api/orders").set("X-CSRF-Token", csrf).send({ ...customer, couponCode: "yash10", items: [{ productId: p.id, quantity: 2 }] }).expect(201);
  assert.equal(r.body.discount, 17.8);
  assert.equal(r.body.total, 178 - 17.8 + 49);
  await agent.post("/api/orders").set("X-CSRF-Token", csrf).send({ ...customer, couponCode: "FAKE", items: [{ productId: p.id, quantity: 1 }] }).expect(400);
});

test("product image upload is resized, stored and served", async () => {
  const { agent, csrf } = await adminAgent();
  const sharp = require("sharp");
  const png = await sharp({ create: { width: 1600, height: 2000, channels: 3, background: "#c8102e" } }).png().toBuffer();
  const up = await agent.post("/api/admin/images").set("X-CSRF-Token", csrf).set("Content-Type", "image/png").send(png).expect(201);
  assert.match(up.body.url, /^\/media\/\d+\.webp$/);
  const img = await request(app).get(up.body.url).expect(200);
  assert.equal(img.headers["content-type"], "image/webp");
  const meta = await sharp(img.body).metadata();
  assert.ok(meta.width <= 1000, "resized to at most 1000px wide");
  await agent.post("/api/admin/images").set("X-CSRF-Token", csrf).set("Content-Type", "image/png").send(Buffer.from("not an image")).expect(400);
  const created = await agent.post("/api/admin/products").set("X-CSRF-Token", csrf)
    .send({ name: "Ajwain Seeds", category: "Whole Spices", description: "Carom seeds for parathas and pakoras.", price: 69, weight: "100 g", image: up.body.url, stock: 30 }).expect(201);
  const list = await products();
  assert.equal(list.find(x => x.id === created.body.id).image, up.body.url);
});

test("CSV export guards against spreadsheet formulas", async () => {
  const p = (await products())[0];
  const { agent: shop, csrf: c1 } = await shopper();
  await shop.post("/api/orders").set("X-CSRF-Token", c1).send({ ...customer, name: "=HYPERLINK(1)", items: [{ productId: p.id, quantity: 1 }] }).expect(201);
  const { agent } = await adminAgent();
  const csv = (await agent.get("/api/admin/reports.csv").expect(200)).text;
  assert.ok(csv.includes(`"'=HYPERLINK(1)"`));
  assert.ok(csv.split("\r\n")[0].includes("delivery_fee"));
});

test("reports load", async () => {
  const { agent } = await adminAgent();
  const r = (await agent.get("/api/admin/reports").expect(200)).body;
  assert.ok(Array.isArray(r.monthly) && r.monthly.length >= 1);
  assert.ok(r.bestSellers.length >= 1);
  assert.equal(typeof r.monthly[0].revenue, "number");
});

test("storefront, policies and SEO files are served", async () => {
  const home = await request(app).get("/").expect(200);
  assert.ok(home.text.includes('application/ld+json'));
  assert.ok(!home.text.includes("<!--JSONLD-->"));
  for (const page of ["/privacy", "/terms", "/shipping-policy", "/refund-policy"]) await request(app).get(page).expect(200);
  const sitemap = (await request(app).get("/sitemap.xml").expect(200)).text;
  assert.ok(sitemap.includes("/refund-policy"));
  assert.ok((await request(app).get("/robots.txt").expect(200)).text.includes("Disallow: /admin"));
});

test("static files are not rate-limited", async () => {
  for (let i = 0; i < 320; i++) await request(app).get("/styles.css").expect(200);
});
