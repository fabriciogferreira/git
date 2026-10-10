import { test, expect } from '@playwright/test'
import {
    AUTH_TOAST,
    e2eCredentials,
    e2eLandingURL,
    expectSwalToast,
    loginAsE2EUser,
    logoutFromUserMenu,
    stubRecaptchaForPage,
} from './helpers/auth'

test.describe('management auth', () => {
    test.describe.configure({ timeout: 90_000 })

    test('logs into management and shows success toast', async ({ page }) => {
        const { user, password } = e2eCredentials()
        await stubRecaptchaForPage(page)

        await page.goto('/auth')
        await expect(page.getByRole('heading', { name: /Logar no gerencial|Log in/i })).toBeVisible()

        await page.locator('input[name="email"]').fill(user)
        await page.locator('input[name="password"]').fill(password)

        await Promise.all([
            page.waitForResponse(
                r =>
                    /\/login\b/.test(r.url()) &&
                    r.request().method() === 'POST' &&
                    r.status() === 200,
                { timeout: 30_000 }
            ),
            page.getByRole('button', { name: /Entrar|Log in|Login/i }).click(),
        ])

        await expectSwalToast(page, AUTH_TOAST.loggedIn)
        await expect(page).not.toHaveURL(/\/auth/, { timeout: 20_000 })
    })

    test('shows client validation feedback when submitting empty login', async ({ page }) => {
        await stubRecaptchaForPage(page)
        await page.goto('/auth')
        await expect(page.getByRole('heading', { name: /Logar no gerencial|Log in/i })).toBeVisible()

        await page.getByRole('button', { name: /Entrar|Log in|Login/i }).click()

        await expect(page.locator('.invalid-feedback').first()).toBeVisible()
        await expect(page).toHaveURL(/\/auth/)
        await expect(page.locator('.swal2-container')).toHaveCount(0)
    })

    test('shows invalid-credentials toast for wrong password', async ({ page }) => {
        const { user } = e2eCredentials()
        await stubRecaptchaForPage(page)

        await page.goto('/auth')
        await expect(page.getByRole('heading', { name: /Logar no gerencial|Log in/i })).toBeVisible()

        await page.locator('input[name="email"]').fill(user)
        await page.locator('input[name="password"]').fill('wrong-password-e2e')

        await Promise.all([
            page.waitForResponse(
                r =>
                    /\/login\b/.test(r.url()) &&
                    r.request().method() === 'POST' &&
                    r.status() === 422,
                { timeout: 30_000 }
            ),
            page.getByRole('button', { name: /Entrar|Log in|Login/i }).click(),
        ])

        await expectSwalToast(page, AUTH_TOAST.invalidCredentials)
        await expect(page).toHaveURL(/\/auth/)
    })

    test('exposes create-account and forgot-password links to landing', async ({ page }) => {
        await stubRecaptchaForPage(page)
        await page.goto('/auth')
        await expect(page.getByRole('heading', { name: /Logar no gerencial|Log in/i })).toBeVisible()

        const landing = e2eLandingURL()
        const createAccount = page.getByRole('link', { name: /Criar uma conta|Create an account/i })
        const forgotPassword = page.getByRole('link', { name: /Esqueceu.*senha|Forgot.*password/i })

        await expect(createAccount).toBeVisible()
        await expect(forgotPassword).toBeVisible()
        await expect(createAccount).toHaveAttribute('href', `${landing}/register`)
        await expect(forgotPassword).toHaveAttribute('href', `${landing}/forgot-password`)
    })

    test('logs out from user menu and returns to /auth', async ({ page }) => {
        await loginAsE2EUser(page)
        await expect(page).not.toHaveURL(/\/auth/)

        await logoutFromUserMenu(page)
        await expect(page).toHaveURL(/\/auth/)
        await expect(page.getByRole('heading', { name: /Logar no gerencial|Log in/i })).toBeVisible()
    })
})

test.describe('landing auth', () => {
    test.describe.configure({ timeout: 90_000 })

    test('get-started login shows invalid-credentials toast', async ({ page }) => {
        await stubRecaptchaForPage(page)
        await page.goto(`${e2eLandingURL()}/get-started`)

        await expect(page.getByRole('heading', { name: /Fazer login|Log in|Do login/i })).toBeVisible({
            timeout: 20_000,
        })

        await page.locator('input[name="username"]').fill('nobody-e2e@olie.test')
        await page.locator('input[name="password"]').fill('wrong-password-e2e')

        await Promise.all([
            page.waitForResponse(
                r =>
                    /\/login\b/.test(r.url()) &&
                    r.request().method() === 'POST' &&
                    (r.status() === 200 || r.status() === 422),
                { timeout: 30_000 }
            ),
            page.getByRole('button', { name: /Entrar|Log in|Login|Acessar/i }).click(),
        ])

        await expectSwalToast(page, AUTH_TOAST.invalidCredentials)
        await expect(page).toHaveURL(/get-started/)
    })

    test('register shows client validation feedback when submitting empty form', async ({
        page,
    }) => {
        await stubRecaptchaForPage(page)
        await page.goto(`${e2eLandingURL()}/register`)

        await expect(
            page.getByRole('heading', { name: /Criar cadastro|Create account|Register/i })
        ).toBeVisible({ timeout: 20_000 })

        await page.getByRole('button', { name: /Cadastrar|Register|Sign up/i }).click()

        await expect(
            page.locator('small.feedback-error').filter({ hasText: /.+/ }).first()
        ).toBeVisible()
        await expect(page).toHaveURL(/\/register/)
        await expect(page.locator('.swal2-container')).toHaveCount(0)
    })

    test('register creates account, shows success toast, and lands on confirm-email', async ({
        page,
    }) => {
        await stubRecaptchaForPage(page)
        await page.goto(`${e2eLandingURL()}/register`)

        await expect(
            page.getByRole('heading', { name: /Criar cadastro|Create account|Register/i })
        ).toBeVisible({ timeout: 20_000 })

        const slug = `e2e${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`
        const email = `${slug}@olie.test`
        const password = 'E2e-pass1!'

        await page.locator('#name').fill(`E2E Signup ${slug}`)
        await page.locator('#email').fill(email)
        await page.locator('#password').fill(password)
        await page.locator('#password_confirm').fill(password)
        await page.locator('#legal_consent').check()

        await Promise.all([
            page.waitForResponse(
                r =>
                    /\/register\b/.test(r.url()) &&
                    r.request().method() === 'POST' &&
                    r.status() === 200,
                { timeout: 45_000 }
            ),
            page.getByRole('button', { name: /Cadastrar|Register|Sign up/i }).click(),
        ])

        await expectSwalToast(page, AUTH_TOAST.registered)
        await expect(page).toHaveURL(/\/confirm-email\//, { timeout: 20_000 })
        await expect(page.getByText(email)).toBeVisible()
        await expect(
            page.getByRole('heading', { name: /Confirme seu email|Confirm your email/i })
        ).toBeVisible()
    })

    test('register surfaces API validation when email is already taken', async ({ page }) => {
        const { user } = e2eCredentials()
        await stubRecaptchaForPage(page)
        await page.goto(`${e2eLandingURL()}/register`)

        await expect(
            page.getByRole('heading', { name: /Criar cadastro|Create account|Register/i })
        ).toBeVisible({ timeout: 20_000 })

        await page.locator('#name').fill('E2E Duplicate')
        await page.locator('#email').fill(user)
        await page.locator('#password').fill('E2e-pass1!')
        await page.locator('#password_confirm').fill('E2e-pass1!')
        await page.locator('#legal_consent').check()

        await Promise.all([
            page.waitForResponse(
                r =>
                    /\/register\b/.test(r.url()) &&
                    r.request().method() === 'POST' &&
                    r.status() === 422,
                { timeout: 45_000 }
            ),
            page.getByRole('button', { name: /Cadastrar|Register|Sign up/i }).click(),
        ])

        const alert = page.locator('[role="alert"]').filter({
            hasText: /Algo não saiu como esperado|Something went wrong|já.*utilizad|taken|unique/i,
        })
        await expect(alert.first()).toBeVisible({ timeout: 10_000 })
        await expect(page).toHaveURL(/\/register/)
    })
})
