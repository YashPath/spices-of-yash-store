# Release QA results

Release: Spices of Yash store v2.1.0 (source package)
Date: 2026-10-02

## Passed in this workspace

- `node --check` passed for `server.js`, storefront/admin JavaScript, database module, and setup/smoke-test scripts.
- `npm test` passed. The static smoke test checks feature routes, wholesale fields, checkout/admin UI hooks, session/CSRF protections, transactional stock handling, Razorpay signature and capture verification, signed webhook handling, local product images, and motion enhancements.
- Archive integrity check passed after packaging.

## Not run / not verified

- `npm install` timed out while trying to reach the package registry; offline installation confirmed required packages were not cached.
- Therefore the app could not be launched here for live HTTP requests, SQLite migrations, browser-based manual checkout, admin login, coupon/order/report flows, or Docker build.
- No public hosting, domain, TLS, merchant UPI, gateway, courier, or email/SMS credentials were available; no public deployment was performed.

## Required before taking real customer orders

1. On a networked machine with Node.js 20+, run `npm install`, `npm test`, and `npm start`.
2. Follow `TESTING-CHECKLIST.md` with test products and a test administrator; resolve all failures before production.
3. Configure HTTPS, persistent storage, a strong secret, backups, business policies/compliance, and real product details.
4. Do not treat UPI as automatically paid. Verify in the merchant bank/UPI app or integrate a payment gateway with verified server-side webhooks.
5. Run `npm audit` and obtain an independent security review.


## Iteration 2 changes (static validation passed on 2026-10-03)

- Added optional Razorpay order creation, server-side HMAC signature verification, and a server-to-server payment status/amount/currency check before marking an order paid; payment stays pending until verification succeeds.
- Added payment-token hashing to tie a public payment session to the created order, plus signed webhook processing for captured/failed payment events.
- Added optional Razorpay Checkout selection only when server-side key credentials are configured.
- Added lightweight 3D depth, floating hero accent, and scroll-reveal motion with reduced-motion support.
- Syntax checks, static smoke tests, HTML parsing, CSS brace balance, bundled-image checks, and frontend secret scan passed. Live gateway transactions, actual webhook delivery, refunds, shipping, and public deployment still require merchant credentials and a deployed HTTPS environment; they are not claimed as tested here.

## Iteration 3 — backend and database safety review (v2.2.1, 2026-10-03)

### Changes made in this review
- Merge duplicate product IDs in checkout and enforce a 20-unit maximum per SKU after merging.
- Validate coupon expiry as a real `YYYY-MM-DD` calendar date; malformed stored dates fail closed at checkout.
- Restrict order status transitions to the intended fulfilment lifecycle; shipped/delivered orders cannot be cancelled through the normal status route.
- Validate product updates with a strict partial schema, including true boolean validation and rejection of unknown fields. Add admin-only inventory listing so inactive products remain manageable, and expose retail price, wholesale price, minimum quantity, stock, and active status in the admin UI.
- Protect CSV exports against spreadsheet formula injection.
- Count only verified-paid, non-cancelled orders as revenue in summary/monthly reports; monthly reports distinguish paid orders from all orders, and top-ordered-product totals only include paid orders.
- Add `npm run db:audit`, a read-only SQLite audit command that checks database integrity, foreign keys, required tables, invalid quantities/prices/statuses, empty orders, and coupon constraints. It does not import the application database module and does not run migrations or seed data.
- Hide admin password input in supported interactive terminals when creating an administrator; non-interactive terminals show an explicit warning that input cannot be hidden.
- Expand static smoke tests for the changes above.

### Verification performed
- `node --check` passed for server, database module, storefront/admin scripts, admin setup, database audit, and smoke tests.
- `npm test` passed after the changes.
- All 10 database-audit SQL checks executed successfully against a synthetic SQLite schema; the paid-revenue report query correctly distinguished total orders from paid orders. This validates query syntax/logic only, not the user’s database.
- A live dependency install attempt timed out in this workspace. As a result, this review has not yet run the database audit against the user's actual local SQLite database or performed live HTTP/browser tests.

### Still required on the user's local machine
1. Make a verified backup of `data\\store.sqlite` before running any database inspection or migration.
2. Run `npm run db:audit` and review its PASS/FAIL/WARN output.
3. Run the complete manual checklist with a disposable test order and verify inventory/report behaviour.
4. Run `npm audit` on the actual installed dependency tree and resolve vulnerabilities without blindly applying breaking upgrades.
5. Rotate the previously exposed session secret before production, use HTTPS and production cookie settings, and complete an independent security review.

This iteration improves code-level safeguards but does not claim production readiness until local database, live integration, dependency, and deployment checks pass.
