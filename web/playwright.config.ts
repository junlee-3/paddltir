import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  timeout: 60_000,
  retries: 0,
  use: { baseURL: "http://localhost:3000", ...devices["Pixel 7"] },
  webServer: {
    command: "pnpm dev",
    url: "http://localhost:3000/login",
    reuseExistingServer: true,
    timeout: 120_000,
    env: { NEXT_PUBLIC_PADDLTIR_DEV_LOGIN: "1" },
  },
});
