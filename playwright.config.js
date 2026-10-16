// Browser tests: `npm run test:e2e`  (first time: `npx playwright install chromium`)
const { defineConfig, devices } = require("@playwright/test");
module.exports = defineConfig({
  testDir: "tests/e2e",
  timeout: 30000,
  retries: process.env.CI ? 1 : 0,
  workers: 1,
  reporter: process.env.CI ? "github" : "list",
  use: { baseURL: "http://localhost:3100", trace: "retain-on-failure" },
  projects: [
    { name: "desktop", use: { ...devices["Desktop Chrome"], viewport: { width: 1440, height: 900 } } },
    { name: "mobile", use: { ...devices["Pixel 7"] } }
  ],
  webServer: { command: "node tests/e2e/start-server.js", url: "http://localhost:3100/api/health", reuseExistingServer: !process.env.CI, timeout: 30000 }
});
