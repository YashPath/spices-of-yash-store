# Spices of Yash — Full-stack spices store

Spices of Yash is a local-first retail and wholesale storefront starter with product browsing, category filters, cart, checkout/order capture, admin login, inventory editing, order-status management, and SQLite persistence.

> **Before selling:** This is a starter, not a security-audited production deployment. Replace demo branding, imagery, contact details, product copy and prices. Test the order flow. Configure HTTPS, backups, privacy/terms/returns policies, delivery rules and applicable Indian food-business compliance (including FSSAI where applicable). UPI order selection and merchant UPI ID instructions are supported, but payment is not automatically verified and no payment gateway is integrated.

## Requirements
- Node.js 20 or newer
- npm

## Run on Windows (VS Code)
1. Extract the ZIP.
2. Open the extracted `spices-of-yash-store` folder in VS Code (**File → Open Folder**).
3. Open **Terminal → New Terminal**.
4. Install packages:
   ```bash
   npm install
   ```
5. Create your environment file:
   ```powershell
   Copy-Item .env.example .env
   ```
   Edit `.env` and set `SESSION_SECRET` to a long random value (32+ characters). You can generate one with:
   ```bash
   node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
   ```
6. Create the first admin user:
   ```bash
   npm run admin:create
   ```
   Choose a username and a password of at least 12 characters. The setup script currently displays password input as you type; run it in a private terminal and do not share your screen.
7. Start the app:
   ```bash
   npm start
   ```
8. Open `http://localhost:3000` in your browser. Admin dashboard: `http://localhost:3000/admin`.

The SQLite database is created automatically at `data/store.sqlite`. Session data is stored in `data/sessions.sqlite`.

## What works
- Responsive product storefront and product-category filtering
- Search products, add/remove cart items and adjust quantities
- Checkout validates customer input and server-side stock/prices
- Orders and line items persist in SQLite; inventory decrements atomically
- Admin account password hashes use bcrypt
- Admin dashboard: order list, status updates, add products, update stock, wholesale prices/minimum quantities, coupon management, sales reports and CSV export
- Security baseline: Helmet headers/CSP, HTTP-only SameSite session cookie, session regeneration on login, CSRF token on state-changing requests, rate limiting, request size limits, validation, parameterized SQL, server-side totals, stock checks, and generic error messages

## Important production checklist
- Deploy behind HTTPS and set `NODE_ENV=production` and `COOKIE_SECURE=true`.
- Set a unique high-entropy `SESSION_SECRET`; never commit `.env`.
- Use a persistent disk/managed database and automated encrypted backups.
- Configure UPI_ID and manually verify transfers; add a payment gateway integration (Razorpay/Stripe etc.) with verified server-side webhooks before accepting online payments. Never trust payment status from the browser.
- Configure delivery pricing, GST/invoice needs, returns/refunds, shipping integrations, email/SMS order confirmation and customer-support contact.
- Add privacy notice, terms, cancellation/return policy and consent as required.
- Confirm applicable FSSAI registration/licensing, label declarations, Legal Metrology and GST requirements with qualified local professionals.
- Use a production reverse proxy, TLS, dependency scanning, logging/monitoring, admin MFA, account lockout, and security testing.
- Replace remote demo images with images you own or are licensed to use. Review the CSP if changing external image/font sources.

## Notes
- Demo seed products/prices are illustrative. Edit them in `src/db.js` or use the admin dashboard to add real products.
- Customer orders are stored with personal information. Restrict database access, define a retention policy, and never commit production database files.
- Checkout currently creates an order for store follow-up; it does not charge the customer.


## Retail, wholesale, coupons and reports
- Wholesale order pricing uses the configured per-product wholesale price and minimum quantity; the server validates quantities and calculates totals.
- Coupons support percentage or fixed discounts, minimum order value, expiry and activation.
- Admin reports include monthly order value, top-selling products, low-stock items and payment-status counts; CSV export contains order metadata.
- UPI is currently a payment instruction/preference only. A configured UPI ID does not prove payment; verify receipt in your bank/UPI app or integrate a gateway with signed server-side webhooks. Never mark a customer-paid order based only on a screenshot.


## Online payments (Razorpay)

The store supports optional Razorpay Checkout for online UPI/cards when credentials are configured. Add `RAZORPAY_KEY_ID` and `RAZORPAY_KEY_SECRET` to `.env` on the server only. Start with Razorpay Test Mode keys and test the complete checkout before considering Live Mode. Never place the secret in browser code or commit `.env`. The server creates the gateway order from the server-calculated order total and verifies the payment signature before marking an order paid. Configure the Razorpay webhook URL as `https://YOUR-DOMAIN/api/payments/razorpay/webhook`, subscribe to `payment.captured` and `payment.failed`, and set the webhook secret in `RAZORPAY_WEBHOOK_SECRET`. Manual UPI remains pending until a store admin verifies it.

Live customer payments additionally require an approved merchant account, real keys, a public HTTPS deployment, correct business/contact/return policies, and a verified payment/refund/fulfilment workflow. This local ZIP cannot be considered live-payment-ready until those merchant-specific steps and end-to-end tests are completed.

## Motion / performance

The storefront uses lightweight CSS 3D depth and scroll-reveal effects; no heavy 3D library is required. Motion respects `prefers-reduced-motion`. Product photography is bundled locally to avoid depending on remote image URLs.
