const { test, expect } = require("@playwright/test");

function watchErrors(page) {
  const errors = [];
  page.on("console", m => { if (m.type() === "error") errors.push(m.text()); });
  page.on("pageerror", e => errors.push(e.message));
  return errors;
}

test("shopper can search, use quick view, check out and see delivery + UPI details", async ({ page }) => {
  const errors = watchErrors(page);
  await page.goto("/");
  await expect(page.locator(".product-card")).toHaveCount(6);
  await expect(page.locator("#feature-name")).not.toBeEmpty();

  await page.fill("#search-input", "zzzz");
  await expect(page.locator("#empty-state")).toBeVisible();
  await page.click("#clear-filters");
  await expect(page.locator(".product-card")).toHaveCount(6);

  // Quick view: Garam Masala ×3 (₹119 each)
  await page.locator(".product-card", { hasText: "Garam Masala" }).locator("[data-quick]").click();
  await expect(page.locator("#quickview")).toBeVisible();
  await page.click("#qv-plus");
  await page.click("#qv-plus");
  await page.click("#qv-add");
  await expect(page.locator("#cart-count")).toHaveText("3");

  // Cart survives a reload
  await page.reload();
  await expect(page.locator("#cart-count")).toHaveText("3");

  const isMobile = await page.locator("#bag-bar").isVisible();
  await page.click(isMobile ? "#bag-bar-open" : "#cart-open");
  await expect(page.locator("#cart-delivery")).toHaveText("₹49");
  await expect(page.locator("#cart-grand")).toHaveText("₹406");
  await page.click("#checkout-open");

  await page.click("#place-order");
  await expect(page.locator("#checkout-message")).toContainText("highlighted");
  await page.fill("[name=name]", "Browser Test");
  await page.fill("[name=phone]", "9876543210");
  await page.fill("[name=address]", "12 Rajpur Road, near clock tower");
  await page.fill("[name=city]", "Dehradun");
  await page.fill("[name=pincode]", "248001");
  await expect(page.locator("#summary-total")).toHaveText("₹406");
  await page.click("#place-order");

  await expect(page.locator("#confirm-step")).toBeVisible();
  await expect(page.locator("#confirm-totals")).toContainText("₹406");
  await expect(page.locator("#confirm-pay")).toContainText("teststore@upi");
  await expect(page.locator("#confirm-pay img")).toBeVisible();
  await expect(page.locator("#cart-count")).toHaveText("0");
  expect(errors).toEqual([]);
});

test("page has no horizontal scroll", async ({ page }) => {
  await page.goto("/");
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  expect(overflow).toBeLessThanOrEqual(0);
});

test("policy pages load with store navigation", async ({ page }) => {
  const errors = watchErrors(page);
  for (const [url, title] of [["/privacy", "Privacy policy"], ["/terms", "Terms of use"], ["/shipping-policy", "Shipping policy"], ["/refund-policy", "Refund & return policy"]]) {
    await page.goto(url);
    await expect(page.locator("h1")).toHaveText(title);
  }
  await page.goto("/shipping-policy");
  await expect(page.locator("[data-delivery-fee]").first()).toHaveText("₹49");
  expect(errors).toEqual([]);
});

test("admin can log in, see the order and update it", async ({ page }) => {
  const errors = watchErrors(page);
  page.on("dialog", d => d.accept());
  await page.goto("/admin");
  await page.fill("#login-username", "admin");
  await page.fill("#login-password", "e2e-password-123");
  await page.click("#login-form button");
  await expect(page.locator("#dashboard")).toBeVisible();
  await expect(page.locator("#health-list")).toContainText("Database");

  await page.click("#tab-orders");
  await page.fill("#order-search", "Browser Test");
  const order = page.locator(".order").first();
  await expect(order).toContainText("Browser Test");
  await expect(order).toContainText("Delivery");
  await order.locator("select").selectOption("Packed");
  await order.locator("[data-save-order]").click();
  await expect(page.locator("#toast")).toContainText("updated");
  await page.locator(".order").first().locator("[data-verify-payment]").click();
  await expect(page.locator(".order").first()).toContainText("Payment verified");

  await page.click("#tab-products");
  await expect(page.locator(".inv-row")).toHaveCount(6);
  expect(errors).toEqual([]);
});
