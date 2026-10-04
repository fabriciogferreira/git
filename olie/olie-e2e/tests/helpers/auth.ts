import { type Page, type Response, expect } from '@playwright/test'

const E2E_RECAPTCHA_TOKEN = 'e2e-playwright-token'

/** Matches api-main UserSeeder / User factory local defaults. Overridable via env. */
export function e2eCredentials() {
    return {
        user: process.env.E2E_USER || 'tester@olie.ai',
        password: process.env.E2E_PASSWORD || 'password',
    }
}

/** Landing SPA base URL (signup / forgot-password live here, not on management). */
export function e2eLandingURL() {
    return (process.env.E2E_LANDING_URL || 'http://landing-page.olie.localhost').replace(
        /\/$/,
        ''
    )
}

/** SweetAlert2 toast / popup copy shown for auth feedback. */
export const AUTH_TOAST = {
    loggedIn: /Logado com sucesso|Successfully logged in/i,
    invalidCredentials: /Email ou senha inválidos|Invalid email or password|credenciais não são válidas/i,
    registered: /Usuário registrado|User registered/i,
} as const

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

/**
 * Seconds to wait after a 429, preferring `Retry-After` and falling back to the app envelope's
 * `wait_seconds` (`FrameworkExceptionRenderer` sends both). Capped so a stuck limiter cannot hang
 * the suite forever.
 */
async function throttleWaitSeconds(response: Response): Promise<number> {
    const retryAfter = response.headers()['retry-after']
    const body = (await response.json().catch(() => null)) as {
        wait_seconds?: string | number
    } | null

    const seconds = Number(retryAfter ?? body?.wait_seconds ?? 20)
    return Number.isFinite(seconds) && seconds > 0 ? Math.min(60, seconds) : 20
}

function sleep(seconds: number) {
    return new Promise<void>(resolve => setTimeout(resolve, seconds * 1000))
}

/** Assert a SweetAlert2 toast/popup containing `pattern` is visible. */
export async function expectSwalToast(page: Page, pattern: RegExp, timeout = 10_000) {
    const toast = page.locator('.swal2-container').getByText(pattern)
    await expect(toast.first()).toBeVisible({ timeout })
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
    const maxAttempts = 6
    let throttled = 0

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
        await page.goto(authPath)
        await expect(page.getByRole('heading', { name: /Logar no gerencial|Log in/i })).toBeVisible()

        await page.locator('input[name="email"]').fill(user)
        await page.locator('input[name="password"]').fill(password)

        const [response] = await Promise.all([
            page.waitForResponse(
                r => /\/login\b/.test(r.url()) && r.request().method() === 'POST',
                { timeout: 30_000 }
            ),
            page.getByRole('button', { name: /Entrar|Log in|Login/i }).click(),
        ])

        // `throttle:login` is 8/min per IP and E2E provisions many users; wait it out instead of
        // failing the spec. Capped so a persistently saturated bucket still surfaces as a failure.
        if (response.status() === 429) {
            if (throttled >= 3) {
                throw new Error(`login throttled (429) after ${throttled} waits`)
            }
            throttled++
            await sleep(await throttleWaitSeconds(response))
            continue
        }

        try {
            await expect(page).not.toHaveURL(/\/auth/, { timeout: 20_000 })
            return
        } catch (err) {
            if (attempt === maxAttempts) throw err
            await dismissErrorModal(page)
        }
    }
}

/** Login via /auth. Defaults to seeded tester@olie.ai / password. Retries once on captcha/toast flake. */
export async function loginAsE2EUser(page: Page) {
    const { user, password } = e2eCredentials()
    await loginWithCredentials(page, user, password)
}

/**
 * Open the sidebar user menu and click logout.
 * Clears token + reloads → middleware sends the user back to /auth.
 */
export async function logoutFromUserMenu(page: Page) {
    const menuTrigger = page
        .locator('button[data-bs-toggle="dropdown"]')
        .filter({ has: page.locator('img') })
        .first()

    await expect(menuTrigger).toBeVisible({ timeout: 20_000 })
    await menuTrigger.click()

    const logoutItem = page
        .locator('.dropdown-menu .dropdown-item')
        .filter({ hasText: /Sair|Leave/i })
        .first()
    await expect(logoutItem).toBeVisible({ timeout: 5_000 })

    await Promise.all([
        page.waitForURL(/\/auth/, { timeout: 30_000 }),
        logoutItem.click(),
    ])
}
