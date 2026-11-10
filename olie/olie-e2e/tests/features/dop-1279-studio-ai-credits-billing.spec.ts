import { expect, type Page, test } from '@playwright/test'
import { loginAsE2EUser, stubRecaptchaForPage } from '../helpers/auth'
import { requireFeature } from '../helpers/feature'
import { resolvePageOrigin } from '../helpers/navigation'
import { measureContrastRatio, setResolvedTheme } from '../helpers/theme'

/**
 * DOP-1279 — Studio billing on AI credits (management front).
 *
 * Covers automatable UI: released `studio` flag semantics, statement label,
 * insufficient-credits modal + contrast, and collapsible tool-step groups.
 * Live Worker debit / signed POST usage stay on api-main tests.
 */

const STUDIO_ORIGIN = 'http://localhost:8787'

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

    const permissions = (authUser.permissions ?? ['studio.access', 'ai_credits.view', 'ai_credits.purchase']).map(
        p => (typeof p === 'string' ? { name: p } : p),
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
                    token: 'dop-1279-e2e-token',
                    user_id: '00000000-0000-4000-8000-000000000279',
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
                    user_id: '00000000-0000-4000-8000-000000000279',
                    permissions,
                    features,
                    studio_access: permissions.some(p => p.name === 'studio.access'),
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

async function openInsufficientCreditsModal(page: Page) {
    await page.evaluate(() => {
        const store = (window as unknown as { store?: { dispatch: (a: string, p: unknown) => unknown } }).store
        if (!store) throw new Error('window.store missing')
        return store.dispatch('system/SetInsufficientCreditsInfo', {
            message: 'insufficient_credits',
            available_credits: 12.5,
            auto_recharge_status: 'disabled',
        })
    })

    const dialog = page.getByRole('dialog').filter({
        hasText: /Saldo de créditos insuficiente|Insufficient credits/i,
    })
    await expect(dialog).toBeVisible({ timeout: 10_000 })
    return dialog
}

async function stubStudioConversationWithTools(page: Page, conversationId: string) {
    await page.route('**/api/management/apps/token**', async route => {
        if (route.request().method() !== 'POST') {
            await route.continue()
            return
        }
        await route.fulfill({
            status: 200,
            contentType: 'application/json',
            body: JSON.stringify({
                response: true,
                token: 'dop-1279-studio-app-token',
                expires_at: new Date(Date.now() + 60 * 60_000).toISOString(),
            }),
        })
    })

    await page.route(/localhost:8787/, async route => {
        const url = new URL(route.request().url())
        const path = url.pathname

        if (route.request().method() === 'GET' && path === '/conversations') {
            await route.fulfill({
                status: 200,
                contentType: 'application/json',
                body: JSON.stringify({
                    conversations: [
                        {
                            id: conversationId,
                            title: 'DOP-1279 e2e',
                            updated_at: new Date().toISOString(),
                            message_count: 2,
                        },
                    ],
                }),
            })
            return
        }

        if (route.request().method() === 'GET' && path === `/conversations/${conversationId}`) {
            await route.fulfill({
                status: 200,
                contentType: 'application/json',
                body: JSON.stringify({
                    id: conversationId,
                    title: 'DOP-1279 e2e',
                    messages: [
                        { role: 'user', text: 'monte três passos' },
                        {
                            role: 'assistant',
                            text: 'Pronto.',
                            tools: [
                                { name: 'tool_a', summary: 'Passo A', ok: true },
                                { name: 'tool_b', summary: 'Passo B', ok: true },
                                { name: 'tool_c', summary: 'Passo C', ok: true },
                            ],
                        },
                    ],
                }),
            })
            return
        }

        if (route.request().method() === 'GET' && path === `/conversations/${conversationId}/files`) {
            await route.fulfill({
                status: 200,
                contentType: 'application/json',
                body: JSON.stringify({ files: [] }),
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

test.describe('DOP-1279 studio flag visibility', () => {
    test.describe.configure({ timeout: 90_000 })

    test('opens /studio when features.studio is absent (billing mode)', async ({ page }) => {
        await stubLoginSession(page, {
            permissions: ['studio.access'],
            features: {},
        })
        await page.goto('/auth/login?redirect=/studio')
        await signIn(page)

        await expect(page).toHaveURL(/\/studio\/?/, { timeout: 20_000 })
        await expect(page).not.toHaveURL(/\/auth/)
    })

    test('hides /studio when features.studio is explicitly false', async ({ page }) => {
        await stubLoginSession(page, {
            permissions: ['studio.access'],
            features: { studio: false },
        })
        await page.goto('/auth/login?redirect=/studio')
        await signIn(page)

        await expect(page).toHaveURL(/\/overview\/?$/, { timeout: 20_000 })
        await expect(page).not.toHaveURL(/\/studio/)
    })
})

test.describe('DOP-1279 AI credits statement Studio label', () => {
    test.describe.configure({ timeout: 120_000 })

    test('shows Studio on a debit with metadata.source=studio', async ({ page }) => {
        await loginAsE2EUser(page)

        await page.route('**/api/management/ai/credits/transactions**', async route => {
            if (route.request().method() !== 'GET') {
                await route.continue()
                return
            }
            await route.fulfill({
                status: 200,
                contentType: 'application/json',
                body: JSON.stringify({
                    response: true,
                    transactions: [
                        {
                            id: '00000000-0000-4000-8000-00000000d279',
                            type: 'debit',
                            amount: '-1.25',
                            balance_after: '10.00',
                            created_at: new Date().toISOString(),
                            agent_execution_id: null,
                            metadata: {
                                source: 'studio',
                                model: 'claude-sonnet-5-5',
                                tokens: { input: 100, output: 40 },
                            },
                        },
                    ],
                    meta: {
                        current_page: 1,
                        from: 1,
                        to: 1,
                        last_page: 1,
                        per_page: 30,
                        total: 1,
                    },
                }),
            })
        })

        await page.goto(`${resolvePageOrigin(page)}/frame/billing/ai-credits/transactions`)
        await requireFeature(page, {
            id: 'DOP-1279',
            probe: async () => {
                try {
                    await page.getByText('Studio', { exact: true }).first().waitFor({
                        state: 'visible',
                        timeout: 12_000,
                    })
                    return true
                } catch {
                    return false
                }
            },
        })

        await expect(page.getByText('Studio', { exact: true }).first()).toBeVisible()
    })
})

test.describe('DOP-1279 insufficient credits modal contrast', () => {
    test.describe.configure({ timeout: 120_000 })

    test('opens the modal and reports light/dark contrast ratios', async ({ page }) => {
        await loginAsE2EUser(page)
        await page.goto(`${resolvePageOrigin(page)}/overview`)
        await expect(page).not.toHaveURL(/\/auth/, { timeout: 30_000 })

        const samples: Array<{ theme: string; label: string; ratio: number }> = []

        for (const theme of ['light', 'dark'] as const) {
            await setResolvedTheme(page, theme)
            const dialog = await openInsufficientCreditsModal(page)
            const message = dialog.getByText(
                /Você não tem créditos suficientes|You do not have enough credits/i,
            )
            const available = dialog.getByText(/Saldo disponível|Available balance/i)
            const messageRatio = await measureContrastRatio(message)
            const availableRatio = await measureContrastRatio(available)
            samples.push(
                { theme, label: 'message', ratio: Number(messageRatio.ratio.toFixed(2)) },
                { theme, label: 'available_label', ratio: Number(availableRatio.ratio.toFixed(2)) },
            )
            await expect(dialog.getByText('12,5').or(dialog.getByText('12.5'))).toBeVisible()
            await dialog.getByRole('button', { name: 'Fechar', exact: true }).click()
            await expect(dialog).toBeHidden({ timeout: 10_000 })
        }

        // Same pattern as DOP-1154: record ratios for colleague review; do not gate CI on AA.
        expect(samples.length).toBeGreaterThanOrEqual(4)
        console.log('DOP-1279 insufficient credits modal contrast', samples)
    })
})

test.describe('DOP-1279 studio collapsible tool steps', () => {
    test.describe.configure({ timeout: 120_000 })

    test('folds three consecutive tool steps behind a summary line', async ({ page }) => {
        const conversationId = 'dop-1279-steps'
        await loginAsE2EUser(page)
        await stubStudioConversationWithTools(page, conversationId)

        await page.goto(`${resolvePageOrigin(page)}/studio/${conversationId}`)
        await requireFeature(page, {
            id: 'DOP-1279',
            probe: async () => {
                try {
                    await page
                        .getByRole('button', { name: /3 etapas concluídas|3 steps completed/i })
                        .waitFor({ state: 'visible', timeout: 15_000 })
                    return true
                } catch {
                    return false
                }
            },
        })

        const toggle = page.getByRole('button', { name: /3 etapas concluídas|3 steps completed/i })
        await expect(toggle).toBeVisible()
        await expect(page.getByText('Passo A')).toHaveCount(0)

        await toggle.click()
        await expect(page.getByText('Passo A')).toBeVisible()
        await expect(page.getByText('Passo B')).toBeVisible()
        await expect(page.getByText('Passo C')).toBeVisible()

        const contrastSamples: Array<{ theme: string; ratio: number }> = []
        for (const theme of ['light', 'dark'] as const) {
            await setResolvedTheme(page, theme)
            const { ratio } = await measureContrastRatio(toggle)
            contrastSamples.push({ theme, ratio: Number(ratio.toFixed(2)) })
        }
        console.log('DOP-1279 tool-group summary contrast', contrastSamples)
        void STUDIO_ORIGIN
    })
})
