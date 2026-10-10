import { type Page, expect } from '@playwright/test'
import { expectToast, AUTH_TOAST } from './auth'

/** Seeded doctor from UserSeeder (factory password). */
export function doctorCredentials() {
    return {
        user: process.env.E2E_DOCTOR_USER || 'doctor1@doctor.test',
        password: process.env.E2E_DOCTOR_PASSWORD || 'password',
    }
}

/**
 * Ended consultation owned by doctor1 for checkout UI.
 * Seed locally: docker exec televisao-backend php artisan tinker --execute '...'
 * Override with E2E_CHECKOUT_CONSULTATION_ID.
 */
export function checkoutConsultationId(): string {
    const id = process.env.E2E_CHECKOUT_CONSULTATION_ID
    if (!id) {
        throw new Error(
            'E2E_CHECKOUT_CONSULTATION_ID is required (ended consultation for doctor1@doctor.test)'
        )
    }
    return id
}

export async function loginAsDoctor(page: Page) {
    const { user, password } = doctorCredentials()
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
