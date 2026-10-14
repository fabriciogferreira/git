import { type Page, expect } from '@playwright/test'

/** Matches televisao-api UserSeeder local defaults (factory password). Overridable via env. */
export function e2eCredentials() {
    return {
        user: process.env.E2E_USER || 'super@super.super',
        password: process.env.E2E_PASSWORD || 'password',
    }
}

export const AUTH_TOAST = {
    loggedIn: /Login feito com sucesso/i,
    loggedOut: /Logout realizado com sucesso/i,
} as const

/** Assert a Sonner toast containing `pattern` is visible. */
export async function expectToast(page: Page, pattern: RegExp, timeout = 15_000) {
    const toast = page.locator('[data-sonner-toast]').getByText(pattern)
    await expect(toast.first()).toBeVisible({ timeout })
}

/** Login via /login with seed credentials. */
export async function loginAsE2EUser(page: Page) {
    const { user, password } = e2eCredentials()
    await page.goto('/login')
    await expect(page.getByText(/Seja bem-vindo/i)).toBeVisible()

    await page.locator('input[name="email"]').fill(user)
    await page.locator('#login-password').fill(password)

    await Promise.all([
        page.waitForResponse(
            r =>
                /\/users\/login\b/.test(r.url()) &&
                r.request().method() === 'POST' &&
                r.ok(),
            { timeout: 30_000 }
        ),
        page.locator('#login-submit').click(),
    ])

    await expectToast(page, AUTH_TOAST.loggedIn)
    await expect(page).toHaveURL(/\/dashboard/, { timeout: 20_000 })
}

/** Confirm logout dialog and land on /login. */
export async function logoutFromSidebar(page: Page) {
    // Tooltip trigger has no stable id; open via the destructive "Sair" label in the sidebar.
    await page.getByText(/^Sair$/).first().click({ force: true })
    await expect(page.getByText(/Deseja mesmo sair/i)).toBeVisible({ timeout: 10_000 })
    await page.locator('#logout-button').click()
    await expect(page).toHaveURL(/\/login/, { timeout: 20_000 })
}
