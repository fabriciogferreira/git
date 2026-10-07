import { test, expect } from '@playwright/test'
import {
    AUTH_TOAST,
    e2eCredentials,
    expectToast,
    loginAsE2EUser,
    logoutFromSidebar,
} from './helpers/auth'

test.describe('televisao-front auth', () => {
    test.describe.configure({ timeout: 90_000 })

    test('shows login page heading and registration links', async ({ page }) => {
        await page.goto('/login')
        await expect(page.getByText(/Seja bem-vindo/i)).toBeVisible()
        await expect(page.locator('#clinic-signUp-button')).toBeVisible()
        await expect(page.locator('#doctor-signUp-button')).toBeVisible()
        await expect(page.getByRole('link', { name: /redefini/i })).toHaveAttribute(
            'href',
            '/forgot-password'
        )
    })

    test('shows client validation when submitting empty login', async ({ page }) => {
        await page.goto('/login')
        await expect(page.getByText(/Seja bem-vindo/i)).toBeVisible()

        await page.locator('#login-submit').click()

        await expect(page.getByText(/E-mail inválido|pelo menos 6 caracteres/i).first()).toBeVisible()
        await expect(page).toHaveURL(/\/login/)
    })

    test('shows error toast for wrong password', async ({ page }) => {
        const { user } = e2eCredentials()
        await page.goto('/login')
        await expect(page.getByText(/Seja bem-vindo/i)).toBeVisible()

        await page.locator('input[type="email"]').fill(user)
        await page.locator('#login-password').fill('wrong-password-e2e')

        await Promise.all([
            page.waitForResponse(
                r =>
                    /\/users\/login\b/.test(r.url()) &&
                    r.request().method() === 'POST' &&
                    r.status() >= 400,
                { timeout: 30_000 }
            ),
            page.locator('#login-submit').click(),
        ])

        await expect(page.locator('[data-sonner-toast]').first()).toBeVisible({ timeout: 15_000 })
        await expect(page).toHaveURL(/\/login/)
    })

    test('logs in with seed user and reaches dashboard', async ({ page }) => {
        await loginAsE2EUser(page)
        await expect(page).toHaveURL(/\/dashboard/)
    })

    test('logs out back to login', async ({ page }) => {
        await loginAsE2EUser(page)
        await logoutFromSidebar(page)
        await expectToast(page, AUTH_TOAST.loggedOut).catch(() => undefined)
        await expect(page.getByText(/Seja bem-vindo/i)).toBeVisible()
    })
})
