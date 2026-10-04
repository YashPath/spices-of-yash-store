# Razorpay setup for Spices of Yash

## Before taking real payments

This integration is optional. With no Razorpay credentials, the store continues to accept manual UPI orders that stay **Pending verification** until an admin confirms the transfer. Never treat a screenshot or a browser redirect as proof of payment.

## 1. Configure Test Mode first

1. Create/verify your Razorpay merchant account directly with Razorpay.
2. In the Razorpay Dashboard, enable **Test Mode** and generate API keys.
3. Open the store project folder and edit `.env` locally (do not send its contents to anyone). Set:

```dotenv
RAZORPAY_KEY_ID=rzp_test_your_key_id
RAZORPAY_KEY_SECRET=your_test_key_secret
RAZORPAY_WEBHOOK_SECRET=your_webhook_secret
```

Use your real values from the dashboard; the sample strings above are placeholders. Restart `npm start` after editing `.env`. The Online payment option should appear in checkout when both API key values are set.

## 2. Configure the webhook after public HTTPS deployment

In the Razorpay Dashboard, add this endpoint after the site is deployed on HTTPS:

`https://YOUR-DOMAIN/api/payments/razorpay/webhook`

Use the same webhook secret as `RAZORPAY_WEBHOOK_SECRET` and subscribe to `payment.captured` and `payment.failed`. The webhook signature is checked against the raw request body. Do not use `http://localhost` as a production webhook endpoint.

## 3. Test the full journey

- Make a small Test Mode order and complete the provider's test checkout.
- Confirm the browser shows payment success only after the server verifies the signature.
- Confirm the admin order displays `Paid`; test failed and dismissed checkout attempts too.
- Confirm the webhook reaches the server and duplicate webhook events do not create duplicate orders.
- Check order total, coupon, stock, order status, and the reports export.

## 4. Go live only after merchant approval

Complete Razorpay's onboarding and required business verification. Replace test keys with **Live Mode** keys only in the production server's environment, configure the production webhook secret, use HTTPS, configure backups and persistent storage, and run a live low-value test according to the provider's process. Never commit `.env`, expose the secret in frontend code, or paste keys into chat.

## Important limitations

The code does not provision a merchant account, enable live credentials, deploy the store, set up shipping/courier integrations, send order emails/SMS, or determine legal/tax obligations. Those require your business details, provider approval, hosting, and separate operational setup.
