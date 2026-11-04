import { expect, type Page, test } from '@playwright/test'
import { stubRecaptchaForPage } from '../helpers/auth'
import { requireFeature, requireVisible } from '../helpers/feature'

/**
 * OS-556 — long frame names wrap with `text-break` instead of overflowing the
 * sidebar badge (which used to generate unwanted scroll).
 *
 * Identify / login / get-auth-user / get-users are stubbed so the badge renders
 * `minhasvendastestetempalte` without depending on a seeded frame rename.
 * Real login still uses the temporary test RECAPTCHA_SECRET path in
 * ~/git/olie/prompts/workflow-policy.md when stubs are not used elsewhere.
 */

const LONG_FRAME_NAME = 'minhasvendastestetempalte'

function authPayload(url: string, method: string): 'identify' | 'login' | 'user' | 'users' | 'other' {
    const path = new URL(url).pathname
    if (method === 'POST' && path.endsWith('/login/identify')) return 'identify'
    if (method === 'POST' && path.endsWith('/login')) return 'login'
    if (method === 'GET' && path.endsWith('/get-auth-user')) return 'user'
    if (method === 'GET' && path.includes('/get-users')) return 'users'
    return 'other'
}

async function stubSession(page: Page) {
    await stubRecaptchaForPage(page)

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
                    token: 'os-556-e2e-token',
                    user_id: '00000000-0000-4000-8000-000000000556',
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
                    user_id: '00000000-0000-4000-8000-000000000556',
                    permissions: [{ name: '*' }],
                    features: {},
                    current_relationship: {
                        frame: { name: LONG_FRAME_NAME, subdomain: 'devframe' },
                    },
                }),
            })
            return
        }

        if (kind === 'users') {
            await route.fulfill({
                status: 200,
                contentType: 'application/json',
                body: JSON.stringify({
                    response: true,
                    users: [
                        {
                            id: '00000000-0000-4000-8000-000000000556',
                            name: 'Test User',
                            relationships: [{ status: 2 }],
                        },
                    ],
                    frames: [
                        {
                            id: '00000000-0000-4000-8000-000000000001',
                            name: LONG_FRAME_NAME,
                            subdomain: 'devframe',
                            logo_img: null,
                        },
                    ],
                }),
            })
            return
        }

        await route.fulfill({
            status: 200,
            contentType: 'application/json',
            body: JSON.stringify({ response: true, data: [] }),
        })
    })
}

async function signIn(page: Page) {
    await page.goto('/auth/login')
    await page.locator('[data-testid="login-email"]').fill('tester@olie.ai')
    await page.locator('[data-testid="login-submit"]').click()
    await page.locator('[data-testid="login-password"]').fill('password')
    await page.locator('[data-testid="login-submit"]').click()
    await expect(page).not.toHaveURL(/\/auth/, { timeout: 20_000 })
}

/** Keep the store frame name long even if a later get-users race overwrites it. */
async function forceLongFrameName(page: Page) {
    await page.evaluate(name => {
        const store = (
            window as unknown as {
                store?: {
                    state: { user?: { frames?: Array<{ name: string; subdomain: string }> } }
                    commit: (type: string, payload: unknown) => void
                }
            }
        ).store
        if (!store?.state?.user?.frames?.length) return false
        const frames = store.state.user.frames.map(frame =>
            frame.subdomain === 'devframe' ? { ...frame, name } : frame
        )
        store.commit('user/UPDATE_FRAMES', frames)
        return true
    }, LONG_FRAME_NAME)
}

test.describe('OS-556 sidebar frame name scroll', () => {
    test.describe.configure({ timeout: 90_000 })
    test.use({ viewport: { width: 1280, height: 720 } })

    test.beforeEach(async ({ page }) => {
        await stubSession(page)
        await signIn(page)
    })

    test('long frame name wraps with text-break without overflowing the badge', async ({ page }) => {
        await page.goto('/overview')
        await forceLongFrameName(page)

        const aside = page.locator('.aside-menu')
        await requireVisible(page, 'OS-556', aside)

        const badge = page.locator('.menu-badge')
        const nameWrap = badge.locator('.text-break')
        await requireFeature(page, {
            id: 'OS-556',
            probe: async () => (await nameWrap.count()) > 0,
        })

        await expect(badge.getByText(LONG_FRAME_NAME)).toBeVisible()

        const wrap = await nameWrap.evaluate(el => {
            const style = getComputedStyle(el)
            return {
                overflowWrap: style.overflowWrap,
                wordBreak: style.wordBreak,
                scrollWidth: el.scrollWidth,
                clientWidth: el.clientWidth,
                scrollHeight: el.scrollHeight,
                clientHeight: el.clientHeight,
            }
        })
        expect(wrap.overflowWrap === 'break-word' || wrap.wordBreak === 'break-word').toBe(true)
        expect(
            wrap.scrollWidth,
            `frame name overflowed horizontally (scrollWidth=${wrap.scrollWidth}, clientWidth=${wrap.clientWidth})`
        ).toBeLessThanOrEqual(wrap.clientWidth + 1)
    })
})
