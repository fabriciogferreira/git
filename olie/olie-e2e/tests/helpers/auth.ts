import { type Page, expect } from '@playwright/test'

const E2E_RECAPTCHA_TOKEN = 'e2e-playwright-token'

/** Matches api-main UserSeeder / User factory local defaults. Overridable via env. */
export function e2eCredentials() {
    return {
        user: process.env.E2E_USER || 'tester@olie.ai',
        password: process.env.E2E_PASSWORD || 'password',
    }
}

/**
 * Invisible reCAPTCHA often never loads inside the e2e container (no Google / timeout),
 * leaving Login with token=null → request_errors.required_token.
 * Stub grecaptcha before /auth so getToken() always resolves.
 * Pair with api-main skipping RecaptchaValidate in local|testing
 * (local uses Google's test secret which accepts any token).
 */
export async function stubRecaptchaForPage(page: Page) {
    await page.route('https://www.google.com/recaptcha/**', route => route.abort())
    await page.route('https://www.gstatic.com/recaptcha/**', route => route.abort())

    await page.addInitScript(token => {
        const fake = {
            ready: (cb: () => void) => cb(),
            execute: () => {
                queueMicrotask(() => {
                    const cb = (window as unknown as { onRecaptchaCallback?: (t: string) => void })
                        .onRecaptchaCallback
                    cb?.(token)
                })
            },
            reset: () => undefined,
        }

        Object.defineProperty(window, 'grecaptcha', {
            configurable: true,
            get: () => fake,
            set: () => undefined,
        })
    }, E2E_RECAPTCHA_TOKEN)
}

async function dismissErrorModal(page: Page) {
    const ok = page.getByRole('button', { name: /^OK$/i })
    if (await ok.isVisible().catch(() => false)) {
        await ok.click()
    }
}

/** Login via /auth with explicit credentials. Optional absolute baseURL for isolated frames. */
export async function loginWithCredentials(
    page: Page,
    user: string,
    password: string,
    baseURL?: string
) {
    await stubRecaptchaForPage(page)

    const authPath = baseURL ? `${baseURL.replace(/\/$/, '')}/auth` : '/auth'

    for (let attempt = 1; attempt <= 2; attempt++) {
        await page.goto(authPath)
        await expect(page.getByRole('heading', { name: /Logar no gerencial|Log in/i })).toBeVisible()

        await page.locator('input[name="email"]').fill(user)
        await page.locator('input[name="password"]').fill(password)

        await Promise.all([
            page.waitForResponse(
                r =>
                    /\/login\b/.test(r.url()) &&
                    r.request().method() === 'POST' &&
                    (r.status() === 200 || r.status() === 422),
                { timeout: 30_000 }
            ),
            page.getByRole('button', { name: /Entrar|Log in|Login/i }).click(),
        ])

        try {
            await expect(page).not.toHaveURL(/\/auth/, { timeout: 20_000 })
            return
        } catch (err) {
            if (attempt === 2) throw err
            await dismissErrorModal(page)
        }
    }
}

/** Login via /auth. Defaults to seeded tester@olie.ai / password. Retries once on captcha/toast flake. */
export async function loginAsE2EUser(page: Page) {
    const { user, password } = e2eCredentials()
    await loginWithCredentials(page, user, password)
}
