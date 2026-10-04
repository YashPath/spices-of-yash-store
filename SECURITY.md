# Security notes

## Implemented baseline
- Helmet security headers and a restrictive Content Security Policy.
- `HttpOnly`, `SameSite=Lax` session cookie; `Secure` cookies in production.
- SQLite-backed session storage, session ID regeneration after login.
- CSRF token checks on order creation and admin mutations.
- Rate limiting on general requests, login, and order creation.
- Zod validation and server-side product/stock/total calculation.
- Parameterized SQL queries, foreign keys, stock constraints, and transactional order creation.
- Request body size limits and generic API error messages.
- Admin passwords stored using bcrypt hashes (never plaintext).

## Must do before production
- HTTPS and secure cookie settings; strong unique session secret.
- Admin MFA, robust account lockout, audit logs, alerting, backups and restore drills.
- Payment integration with verified server-side webhooks if accepting online payment.
- Privacy policy, retention/deletion procedure, and restricted access to order data.
- Dependency vulnerability scanning and an independent security review.
- Do not expose SQLite files or `.env`; keep them out of version control.

## New retail/wholesale controls
- Wholesale unit prices and minimum quantities are validated server-side.
- Coupon code, active status, expiry, minimum basket and discount are validated on the server; totals are calculated server-side.
- Admin-only coupon management, report endpoints and CSV export require an authenticated session and CSRF protection for mutations.
- UPI status remains Pending verification. Do not treat UPI intent URLs, screenshots or customer-submitted claims as proof of payment. Add signed gateway webhooks for automated confirmation.
