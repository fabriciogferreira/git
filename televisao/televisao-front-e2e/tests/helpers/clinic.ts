import { type Page, expect } from '@playwright/test'
import { expectToast, AUTH_TOAST } from './auth'

/** Seeded clinic admin from ClinicSeeder (factory password). */
export function clinicAdminCredentials() {
    return {
        user: process.env.E2E_CLINIC_ADMIN_USER || 'clinic-admin@clinic.com',
        password: process.env.E2E_CLINIC_ADMIN_PASSWORD || 'password',
    }
}

export async function loginAsClinicAdmin(page: Page) {
    const { user, password } = clinicAdminCredentials()
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
