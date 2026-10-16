// Static smoke test: checks that key files, routes, security rules and
// storefront features are present. Run with `npm test`.
const fs = require('fs');
const path = require('path');
const assert = require('assert');
const root = path.join(__dirname, '..');
const read = (p) => fs.readFileSync(path.join(root, p), 'utf8');

const required = ['server.js', 'src/db.js', 'src/notify.js', 'public/policies/privacy.html', 'public/policies/terms.html', 'public/policies/shipping.html', 'public/policies/refund.html', 'public/index.html', 'public/app.js', 'public/animations.js', 'public/styles.css',
  'public/admin.html', 'public/admin.js', 'public/admin.css', 'public/favicon.svg', 'public/images/og-image.jpg',
  'public/fonts/fraunces-latin-opsz-normal.woff2', 'public/fonts/manrope-latin-wght-normal.woff2', 'scripts/db-audit.js', '.env.example', 'README.md'];
for (const file of required) assert(fs.existsSync(path.join(root, file)), `Missing required file: ${file}`);

const server = read('server.js');
const db = read('src/db.js');
const html = read('public/index.html');
const appJs = read('public/app.js');
const css = read('public/styles.css');
const admin = read('public/admin.html');
const adminJs = read('public/admin.js');

// API routes
for (const route of ['/api/health', '/api/config', '/api/products', '/api/orders', '/api/csrf', '/api/admin/login', '/api/admin/orders',
  '/api/admin/products', '/api/admin/coupons', '/api/admin/reports', '/api/admin/reports.csv', '/api/admin/summary', '/api/admin/images', '/api/admin/test-alert', '/sitemap.xml', '/robots.txt']) {
  assert(server.includes(`"${route}"`), `Missing expected route: ${route}`);
}

// Security
assert(server.includes("scriptSrc: [\"'self'\"]"), 'CSP must keep script-src self (no unsafe-inline scripts)');
assert(!/<script(?![^>]*\bsrc=)(?![^>]*application\/ld\+json)[^>]*>/i.test(html), 'index.html must not contain inline executable <script> blocks');
assert(server.includes('timingSafeEqual'), 'CSRF token comparison must be timing-safe');
assert(server.includes('req.session.adminId'), 'Admin routes must enforce a logged-in session');
assert(server.includes('app.get("/api/admin/products", requireAdmin'), 'Full product inventory must be admin-only');
assert(server.includes('db.tx('), 'Order stock updates must use a transaction');
assert(server.includes("'Pending verification'"), 'UPI payments must not be auto-marked as paid');
assert(server.includes('safeCsvCell'), 'CSV export must guard against spreadsheet formulas');
assert(read('src/db.js').includes('DATABASE_URL'), 'Postgres support must be available via DATABASE_URL');
assert(server.includes('app.use("/api", generalLimiter)'), 'Rate limiter must apply to the API only, not static assets');
assert(server.includes('\\\\u003c') || server.includes('\\u003c'), 'JSON-LD output must escape "<"');

// Database
for (const feature of ['wholesale_price', 'wholesale_min_qty', 'payment_status', 'discount', 'coupon_code']) {
  assert(db.includes(feature), `Missing database field/feature: ${feature}`);
  assert(server.includes(feature), `Missing server handling: ${feature}`);
}
assert(!db.includes('images.unsplash.com/photo'), 'Seed data must use local product images');

// Admin
for (const field of ['wholesale_price', 'wholesale_min_qty', 'discountValue', 'minOrder']) {
  assert(admin.includes(`name="${field}"`), `Missing admin form field: ${field}`);
  assert(adminJs.includes(field), `Missing admin client handling: ${field}`);
}

// Storefront
for (const id of ['checkout-form', 'product-grid', 'cart-items', 'search-input', 'empty-state', 'quickview', 'ship-meter', 'confirm-step', 'wa-float', 'bag-bar', 'menu-toggle', 'price-table-body']) {
  assert(html.includes(`id="${id}"`), `Missing storefront element: #${id}`);
}
assert(html.includes('<!--JSONLD-->'), 'index.html needs the JSON-LD placeholder');
assert(html.includes('og:image'), 'Open Graph tags missing');
assert(!/â€|âœ|âŒ|â˜|Ã—/.test(html + appJs), 'Mojibake characters found in storefront files');
assert(appJs.includes('payload.items'), 'Checkout must submit cart items');
assert(appJs.includes('localStorage'), 'Cart must persist in localStorage');
assert(css.includes('.js-ready .sy-reveal'), 'Reveal animations must only hide content once JS is ready');

console.log('Smoke test passed: files, routes, security rules and storefront features look good.');
