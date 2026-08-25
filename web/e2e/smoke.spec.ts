import { execSync } from "node:child_process";
import { expect, test } from "@playwright/test";

// Needs: `supabase start`, `supabase db reset`, `psql … -f supabase/seed_dev.sql`, and web/.env.local (see README).
test.skip(!process.env.PADDLTIR_LIVE_SUPABASE, "set PADDLTIR_LIVE_SUPABASE=1 with the local stack + demo seed running");

// Seed-safety: the test logs a 555 m self erg row. Delete it afterwards so the DB is left in seed state.
test.afterAll(() => {
  if (!process.env.PADDLTIR_LIVE_SUPABASE) return;
  execSync(
    `docker exec -i supabase_db_paddltir psql -U postgres -d postgres -c "delete from erg_tests where source='self' and metres=555"`,
  );
});

test("a paddler signs in, sees their next event, finds their seat, logs an erg", async ({ page }) => {
  await page.goto("/");
  await expect(page).toHaveURL(/\/login$/);
  await page.getByLabel("Password").fill("password123");
  await page.getByRole("button", { name: "Sign in with password" }).click();
  // The Server Action's client-side transition is still in flight when click() returns; an
  // immediate page.goto() below would abort it mid-request and strand the session on /login.
  // Let it land first (swallow errors — the retry loop below still catches a genuine failure).
  await page.waitForURL((url) => !url.pathname.startsWith("/login"), { timeout: 10_000 }).catch(() => {});

  // Next event = the seeded training; availability is seeded "in".
  // The first authenticated request after sign-in can transiently 500 on the local stack
  // (Supabase Auth "JWT issued at future" clock skew) — retry the navigation until it renders.
  await expect(async () => {
    await page.goto("/");
    await expect(page.getByRole("heading", { name: "Tuesday training" })).toBeVisible({ timeout: 5_000 });
  }).toPass({ timeout: 30_000 });

  const group = page.getByRole("radiogroup", { name: "Availability for Tuesday training" });
  await expect(group.getByRole("radio", { name: "In" })).toHaveAttribute("aria-checked", "true");
  await group.getByRole("radio", { name: "Maybe" }).click();
  await page.reload();
  await expect(group.getByRole("radio", { name: "Maybe" })).toHaveAttribute("aria-checked", "true");
  await group.getByRole("radio", { name: "In" }).click();

  // The race day: Lily is Bench 1 left in Heat 1; the Final is empty.
  await page.getByRole("link", { name: /Sydney Regatta/ }).click();
  await expect(page.getByRole("heading", { name: "Premier Mixed 200m" })).toBeVisible();
  await expect(page.getByText("Bench 1 left", { exact: true })).toBeVisible();
  await expect(page.getByLabel("Bench 1 left: Lily (you)")).toBeVisible();
  await expect(page.getByLabel("Drummer: Dee Drummer")).toBeVisible();
  await page.getByRole("tab", { name: "Final" }).click();
  await expect(page.getByText("Not in this heat")).toBeVisible();

  // Erg
  await page.getByRole("link", { name: "Erg" }).click();
  await page.getByLabel("Metres (1 min)").fill("555");
  await page.getByRole("button", { name: "Log erg test" }).click();
  await expect(page.getByRole("status")).toHaveText("Saved 555 m.");
  // Scoped to the history row (not just exact text): 555 m also becomes the new "Best" in the
  // Trend card above the history list, so an unscoped getByText("555 m", { exact: true }) is
  // ambiguous between the two once this test's own entry raises the personal best.
  await expect(page.locator("li").filter({ hasText: "555 m" }).getByText("555 m", { exact: true })).toBeVisible();

  // Profile + manifest
  await page.getByRole("link", { name: "Profile" }).click();
  await expect(page.getByText("Signed in as lily@paddltir.dev")).toBeVisible();
  await expect(page.locator('link[rel="manifest"]')).toHaveAttribute("href", /manifest\.webmanifest/);
});
