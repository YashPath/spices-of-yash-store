# Spices of Yash — QA checklist

## Storefront and checkout
- [ ] Browse/search/filter products and confirm sold-out items cannot be added.
- [ ] Place a retail order with valid Indian phone number and 6-digit PIN.
- [ ] Try invalid phone, PIN, empty cart and quantities beyond stock.
- [ ] Confirm server uses current database prices rather than browser totals.
- [ ] Apply valid, inactive, expired, below-minimum, and unknown coupon codes.
- [ ] Confirm discount cannot exceed subtotal and totals are rounded correctly.
- [ ] Place wholesale order at the minimum quantity; test below-minimum rejection.
- [ ] Confirm stock changes atomically and is not oversold on concurrent orders.
- [ ] Confirm payment status remains Pending verification until an admin checks the bank/UPI app and marks it verified.

## Admin
- [ ] Unauthenticated requests to /api/admin/* return 401.
- [ ] Invalid login is rate-limited; session ID rotates on login.
- [ ] Missing/incorrect CSRF token blocks all state-changing requests.
- [ ] Create and deactivate a coupon; duplicate coupon codes are rejected.
- [ ] Update stock and wholesale pricing; validate negative values are rejected.
- [ ] Verify monthly report, best-seller list, low-stock list and CSV export.
- [ ] Verify order status changes and cancellation reporting.

## Production readiness
- [ ] Configure HTTPS, NODE_ENV=production, COOKIE_SECURE=true and strong unique SESSION_SECRET.
- [ ] Configure a real UPI ID and verify payment manually, or integrate a gateway with signed webhooks.
- [ ] Test encrypted backups and restore; add monitoring, MFA and audit logs.
- [ ] Review privacy, shipping, refund, GST, Legal Metrology and applicable FSSAI obligations.
- [ ] Run npm audit and an independent security review before accepting public traffic.
