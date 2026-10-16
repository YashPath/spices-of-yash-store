# Deployment notes — Spices of Yash

## Recommended: Render web service + Neon Postgres (both have free tiers)

Render's free web services have **temporary disks**: anything written to `data/` (the SQLite database and sessions) is lost on every redeploy or restart. Use Postgres for the live store.

1. **Database:** create a project at neon.tech and copy the connection string.
2. **Render → New → Web Service** from the GitHub repo.
   - Build command: `npm install`
   - Start command: `npm start`
3. **Environment variables**
   - `NODE_ENV=production`
   - `DATABASE_URL` — the Neon connection string
   - `SESSION_SECRET` — at least 32 random characters (`node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"`)
   - `SITE_URL=https://<your-service>.onrender.com`
   - `UPI_ID`, `WHATSAPP_NUMBER`, `CONTACT_EMAIL`, `CONTACT_PHONE`, `STORE_ADDRESS`, `FSSAI_NUMBER`
   - `DELIVERY_FEE`, `FREE_DELIVERY_MIN` (optional)
   - `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` (order alerts, optional)
   - `ADMIN_BOOTSTRAP_USERNAME`, `ADMIN_BOOTSTRAP_PASSWORD` — first deploy only, creates the admin on the empty database; delete afterwards
4. Deploy and open `/api/health` → `{"status":"ok","database":"postgres"}`.
5. Log in at `/admin`. The Overview tab shows whether the database and alerts are set up.

Tables (products, orders, coupons, admins, images, sessions) are created automatically on first start.

## Staying on SQLite
Only on a host with a persistent disk. Set `DATA_DIR` to the mounted folder (e.g. Render disk at `/var/data`) and back it up regularly.

## Before taking real orders
1. Place a test order, check the Telegram alert, mark it paid and shipped in the admin.
2. Replace product photos and prices with your own, fill in contact details and FSSAI number.
3. Read the policy pages (`/privacy`, `/terms`, `/shipping-policy`, `/refund-policy`) and change anything that doesn’t match how you work.
4. UPI payments are verified by you manually. Integrate a payment gateway with signed webhooks before telling customers payment is confirmed automatically.
