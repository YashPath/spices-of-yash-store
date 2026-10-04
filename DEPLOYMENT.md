# Deployment notes — Spices of Yash

This application is ready to be built for a Node.js host or Docker, but it has **not** been deployed to a public domain from this workspace.

## Required environment variables

- `NODE_ENV=production`
- `PORT` (provided by most hosts; otherwise `3000`)
- `SESSION_SECRET` — unique random value, at least 32 characters; use a secret manager
- `COOKIE_SECURE=true` — HTTPS is required
- `STORE_NAME=Spices of Yash`
- `CURRENCY=INR`
- `UPI_ID` — optional merchant UPI ID; payments are not automatically verified

## Persistent storage

Mount a persistent writable volume at `/app/data` when using Docker. SQLite holds both store data and sessions. Back up the entire directory consistently and test restore procedures. Do not use ephemeral storage for a real store.

## Deploy checklist

1. Configure HTTPS and all environment variables in the hosting dashboard.
2. Create the first administrator in a private terminal using `npm run admin:create` (or run the command in a one-off deployment shell).
3. Verify `/api/health` returns `{"status":"ok"}`.
4. Place a test order with test product data, check stock/order persistence, test coupons and wholesale minimums, and verify admin order status/report/CSV flows.
5. Configure real prices, product photos, contact details, shipping/returns/privacy policies, tax and applicable food-business compliance.
6. Integrate a payment provider with signed server-side webhooks before representing online payments as automatic. UPI ID instructions alone do not process or verify payment.
7. Run dependency vulnerability checks and an independent security review before public sales.

## What this package cannot configure for you

It does not provision a domain, hosting account, TLS certificate, production administrator credentials, merchant UPI account, payment gateway, courier integration, email/SMS service, legal policies, or business registrations.
