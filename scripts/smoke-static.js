const fs = require('fs');
const path = require('path');
const assert = require('assert');
const root = path.join(__dirname, '..');
const read = (p) => fs.readFileSync(path.join(root, p), 'utf8');
const server = read('server.js');
const admin = read('public/admin.html');
const adminJs = read('public/admin.js');
const storefront = read('public/index.html');
const storefrontJs = read('public/app.js');
const db = read('src/db.js');

for (const file of ['scripts/db-audit.js', 'server.js', 'src/db.js', 'public/index.html', 'public/app.js', 'public/admin.html', 'public/admin.js', 'public/styles.css', 'public/admin.css', '.env.example', 'README.md', 'SECURITY.md']) {
  assert(fs.existsSync(path.join(root, file)), `Missing required file: ${file}`);
}
for (const route of ['/api/health', '/api/products', '/api/orders', '/api/admin/login', '/api/admin/orders', '/api/admin/products', '/api/admin/coupons', '/api/admin/reports', '/api/admin/reports.csv', '/api/payments/razorpay/order', '/api/payments/razorpay/verify']) {
  assert(server.includes(`"${route}"`), `Missing expected route: ${route}`);
}
for (const feature of ['wholesale_price', 'wholesale_min_qty', 'payment_status', 'discount', 'coupon_code']) {
  assert(db.includes(feature), `Missing database field/feature: ${feature}`);
  assert(server.includes(feature), `Missing server handling: ${feature}`);
}
for (const field of ['wholesale_price', 'wholesale_min_qty', 'discountValue', 'minOrder']) {
  assert(admin.includes(`name="${field}"`), `Missing admin form field: ${field}`);
  assert(adminJs.includes(field), `Missing admin client handling: ${field}`);
}
for (const phrase of ['checkout-form', 'product-grid', 'cart-items', 'search-input']) assert(storefront.includes(`id="${phrase}"`), `Missing storefront element: ${phrase}`);
assert(storefrontJs.includes('payload.items'), 'Checkout must submit cart items');
assert(server.includes('req.session.adminId'), 'Admin routes must enforce a logged-in session');
assert(server.includes('app.get("/api/admin/products", requireAdmin'), 'Full product inventory must be admin-only');
assert(adminJs.includes('data-save-product'), 'Admin UI must expose product pricing/stock/active updates');
assert(adminJs.includes('/api/admin/products'), 'Admin UI must load inactive products for management');
assert(server.includes('timingSafeEqual'), 'CSRF token comparison must be timing-safe');
assert(server.includes('db.transaction'), 'Order stock updates must use a transaction');
assert(server.includes('Pending verification'), 'UPI payment must not be auto-marked as paid');
assert(server.includes('createHmac("sha256"'), 'Razorpay payment signatures must be verified server-side');
assert(server.includes('payment.status !== "captured"'), 'Orders must not be marked paid before gateway capture is confirmed');
assert(server.includes('/api/payments/razorpay/webhook'), 'A signed payment webhook route must be present');
assert(server.includes('RAZORPAY_KEY_SECRET'), 'Razorpay server secret must be used only server-side');
assert(server.includes('REFUND_REQUIRED'), 'Paid orders must not be cancelled before refund handling');
assert(server.includes('mergedItems'), 'Repeated product IDs must be merged before stock/price checks');
assert(server.includes('isValidDateOnly'), 'Coupon expiry must use strict calendar-date validation');
assert(server.includes('safeCsvCell'), 'CSV exports must guard against spreadsheet formula injection');
assert(server.includes('INVALID_TRANSITION'), 'Order status changes must follow a controlled lifecycle');
assert(server.includes("payment_status = 'Paid'"), 'Revenue summaries must exclude unverified orders');
assert(server.includes('paidOrders'), 'Monthly report must distinguish paid orders from all orders');
assert(server.includes('}).partial().strict()'), 'Product updates must reject unknown fields and validate supplied values');
assert(read('scripts/db-audit.js').includes('readonly: true'), 'Database audit must open the live database in read-only mode');
assert(!read('scripts/db-audit.js').includes('require("../src/db")'), 'Database audit must not run app migrations or seed logic');
assert(read('package.json').includes('db:audit'), 'A read-only database audit command must be available');
assert(read('scripts/create-admin.js').includes('askHidden'), 'Admin creation must hide password input on supported terminals');
assert(db.includes('razorpay_order_id') && db.includes('payment_token_hash'), 'Database must persist gateway and payment-token references');
assert(storefront.includes('checkout.razorpay.com'), 'Razorpay checkout script must be available for online payments');
assert(storefrontJs.includes('/api/payments/razorpay/verify'), 'Checkout must verify gateway payment before showing paid status');
assert(storefrontJs.includes('IntersectionObserver'), 'Scroll reveal motion enhancement must be present');
assert(storefrontJs.includes('no order has been placed'), 'Missing payment widget must fail before creating an order');
assert(storefrontJs.includes('form.reset()'), 'Checkout form must reset after successful order/payment');
assert(fs.existsSync(path.join(root, 'PAYMENT-SETUP.md')), 'Payment setup guide must exist');
assert(!/RAZORPAY_KEY_SECRET/.test(storefrontJs + storefront), 'Gateway secret must never be exposed in frontend files');
for (const slug of ['kashmiri-red-chilli','golden-turmeric','green-cardamom','cumin-seeds','black-peppercorns','garam-masala']) assert(fs.existsSync(path.join(root, 'public', 'images', `${slug}.webp`)), `Missing bundled product image: ${slug}.webp`);
console.log('Static smoke tests passed: core routes, wholesale fields, checkout/admin hooks, CSRF/session checks, transactional stock handling, Razorpay signature/capture verification, webhook validation, local product images, motion enhancements, duplicate-cart aggregation, coupon-date validation, CSV formula-injection protection, order lifecycle validation, paid-only revenue, strict product updates, read-only SQLite integrity auditing, hidden admin-password entry, and complete admin inventory editing.');
console.log('Note: these are static checks, not a live HTTP/database/browser integration test.');
