import { expect, type Page, test } from '@playwright/test'
import { stubRecaptchaForPage } from '../helpers/auth'

/**
 * DOP-1242 — after login, an internal `redirect` query must open that path.
 * External, protocol-relative, public, and unknown paths fall back to the dashboard
 * so the login does not become an open redirect or a loop back to /auth/login.
 *
 * Identify, login, and get-auth-user are stubbed. The local API rejects the
 * reCAPTCHA stub ("Token inválido"), and a 401 from get-auth-user logs the user out
 * before the URL can be asserted.
 *
 * Also covers permission-denied and feature-flagged redirects (prior review), so the
 * user lands on the dashboard instead of staying on /auth/login.
 */

const INTERNAL_TARGET = '/overview/my-assignee?from=dop-1242'

function authPayload(url: string, method: string): 'identify' | 'login' | 'user' | 'other' {
    const path = new URL(url).pathname

    if (method === 'POST' && path.endsWith('/login/identify')) return 'identify'
    if (method === 'POST' && path.endsWith('/login')) return 'login'
    if (method === 'GET' && path.endsWith('/get-auth-user')) return 'user'
    return 'other'
}

async function stubLoginSession(
    page: Page,
    authUser: {
        permissions?: Array<string | { name: string }>
        features?: Record<string, boolean>
    } = {},
) {
    await stubRecaptchaForPage(page)

    // get-auth-user stores objects with `name`; CheckUserPermission maps `p.name`
    const permissions = (authUser.permissions ?? []).map(p =>
        typeof p === 'string' ? { name: p } : p,
    )
    const features = authUser.features ?? {}

    await page.route(/api\.olie\.localhost/, async route => {
        const request = route.request()
        const kind = authPayload(request.url(), request.method())

        if (kind === 'identify') {
            await route.fulfill({
                status: 200,
                contentType: 'application/json',
                body: JSON.stringify({ response: true, method: 'password' }),
            })
            return
        }

        if (kind === 'login') {
            await route.fulfill({
                status: 200,
                contentType: 'application/json',
                body: JSON.stringify({
                    response: true,
                    token: 'dop-1242-e2e-token',
                    user_id: '00000000-0000-4000-8000-000000000124',
                    frame_type: 'work',
                }),
            })
            return
        }

        if (kind === 'user') {
            await route.fulfill({
                status: 200,
                contentType: 'application/json',
                body: JSON.stringify({
                    response: true,
                    user_id: '00000000-0000-4000-8000-000000000124',
                    permissions,
                    features,
                    current_relationship: {},
                }),
            })
            return
        }

        await route.fulfill({
            status: 200,
            contentType: 'application/json',
            body: JSON.stringify({ response: true }),
        })
    })
}

async function signIn(page: Page) {
    await page.locator('[data-testid="login-email"]').fill('tester@olie.ai')
    await page.locator('[data-testid="login-submit"]').click()
    await page.locator('[data-testid="login-password"]').fill('password')
    await page.locator('[data-testid="login-submit"]').click()
}

test.describe('DOP-1242 login redirect', () => {
    test.describe.configure({ timeout: 90_000 })

    test('opens the internal path from the redirect query, including its query string', async ({ page }) => {
        await stubLoginSession(page)
        await page.goto(INTERNAL_TARGET)

        await expect(page).toHaveURL(/\/auth\/login\?redirect=/)
        const redirect = new URL(page.url()).searchParams.get('redirect')
        expect(redirect).toBe(INTERNAL_TARGET)

        await signIn(page)

        await expect(page).toHaveURL(/\/overview\/my-assignee\?from=dop-1242/, { timeout: 20_000 })
        await expect(page).not.toHaveURL(/\/auth/)
    })

    test('discards an external redirect and stays on the dashboard', async ({ page }) => {
        await stubLoginSession(page)
        await page.goto('/auth/login?redirect=https://evil.example/phish')
        await signIn(page)

        await expect(page).toHaveURL(/\/overview\/?$/, { timeout: 20_000 })
        expect(new URL(page.url()).host).toBe('devframe.olie.localhost')
    })

    test('discards a protocol-relative redirect', async ({ page }) => {
        await stubLoginSession(page)
        await page.goto('/auth/login?redirect=//evil.example/phish')
        await signIn(page)

        await expect(page).toHaveURL(/\/overview\/?$/, { timeout: 20_000 })
        expect(new URL(page.url()).host).toBe('devframe.olie.localhost')
    })

    test('discards an unknown path instead of looping back to login', async ({ page }) => {
        await stubLoginSession(page)
        await page.goto('/auth/login?redirect=/does-not-exist-dop-1242')
        await signIn(page)

        await expect(page).toHaveURL(/\/overview\/?$/, { timeout: 20_000 })
        await expect(page).not.toHaveURL(/\/auth/)
    })

    test('discards the public login path instead of looping', async ({ page }) => {
        await stubLoginSession(page)
        await page.goto('/auth/login?redirect=/auth/login')
        await signIn(page)

        await expect(page).toHaveURL(/\/overview\/?$/, { timeout: 20_000 })
        await expect(page).not.toHaveURL(/redirect=/)
    })

    test('without redirect goes to the dashboard', async ({ page }) => {
        await stubLoginSession(page)
        await page.goto('/auth/login')
        await signIn(page)

        await expect(page).toHaveURL(/\/overview\/?$/, { timeout: 20_000 })
        await expect(page).not.toHaveURL(/\/auth/)
    })

    test('discards a backslash-prefixed redirect', async ({ page }) => {
        await stubLoginSession(page)
        await page.goto('/auth/login?redirect=/%5Cevil.com')
        await signIn(page)

        await expect(page).toHaveURL(/\/overview\/?$/, { timeout: 20_000 })
        expect(new URL(page.url()).host).toBe('devframe.olie.localhost')
    })

    test('discards a route the user cannot open and does not stay on login', async ({ page }) => {
        await stubLoginSession(page)
        await page.goto('/auth/login?redirect=/customers/index')
        await signIn(page)

        await expect(page).toHaveURL(/\/overview\/?$/, { timeout: 20_000 })
        await expect(page).not.toHaveURL(/\/auth/)
        await expect(page).not.toHaveURL(/\/customers/)
    })

    test('discards a feature-flagged route the frame does not have', async ({ page }) => {
        await stubLoginSession(page, {
            permissions: ['studio.access'],
            features: {},
        })
        await page.goto('/auth/login?redirect=/studio')
        await signIn(page)

        await expect(page).toHaveURL(/\/overview\/?$/, { timeout: 20_000 })
        await expect(page).not.toHaveURL(/\/auth/)
        await expect(page).not.toHaveURL(/\/studio/)
    })
})
