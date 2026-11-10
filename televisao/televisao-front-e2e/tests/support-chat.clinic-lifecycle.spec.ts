import { test, expect } from '@playwright/test'
import { loginAsClinicAdmin } from './helpers/clinic'

/**
 * Clinic support-chat lifecycle: open/send, resolve (freeze composer + actions),
 * reopen, then send again.
 */
test.describe('televisao-front support chat clinic lifecycle', () => {
    test.describe.configure({ timeout: 120_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsClinicAdmin(page)
    })

    test('clinic can open, resolve, and reopen a support chat', async ({
        page,
    }) => {
        await page.goto('/dashboard/support-chat')

        await expect(page.locator('#support-chat-page')).toBeVisible({
            timeout: 30_000,
        })

        const empty = page.locator('#support-chat-empty')
        const thread = page.locator('#support-chat-thread')

        if (await empty.isVisible().catch(() => false)) {
            const body = `e2e-clinic-open-${Date.now()}`
            await page.locator('#support-chat-composer-input').fill(body)
            await Promise.all([
                page.waitForResponse(
                    r =>
                        /\/support-chats\/messages\b/.test(r.url()) &&
                        r.request().method() === 'POST' &&
                        r.ok(),
                    { timeout: 30_000 }
                ),
                page.locator('#support-chat-composer-send').click(),
            ])
            await expect(thread).toBeVisible({ timeout: 20_000 })
            await expect(
                page.locator('[data-slot="bubble-content"]').filter({ hasText: body })
            ).toBeVisible({ timeout: 15_000 })
        } else {
            await expect(thread).toBeVisible({ timeout: 20_000 })
        }

        // If already resolved from a prior run, reopen first.
        if (await page.locator('#support-chat-reopen').isVisible().catch(() => false)) {
            await Promise.all([
                page.waitForResponse(
                    r =>
                        /\/support-chats\/[^/]+\/reopen\b/.test(r.url()) &&
                        r.request().method() === 'POST' &&
                        r.ok(),
                    { timeout: 30_000 }
                ),
                page.locator('#support-chat-reopen').click(),
            ])
        }

        await expect(page.locator('#support-chat-resolve')).toBeVisible({
            timeout: 15_000,
        })
        await expect(page.locator('#support-chat-composer-input')).toBeEnabled()

        await Promise.all([
            page.waitForResponse(
                r =>
                    /\/support-chats\/[^/]+\/resolve\b/.test(r.url()) &&
                    r.request().method() === 'POST' &&
                    r.ok(),
                { timeout: 30_000 }
            ),
            page.locator('#support-chat-resolve').click(),
        ])

        await expect(page.locator('#support-chat-reopen')).toBeVisible({
            timeout: 15_000,
        })
        await expect(page.locator('#support-chat-composer-input')).toBeDisabled()
        await expect(
            page.getByPlaceholder(/Reabra o chamado para enviar mensagens/i)
        ).toBeVisible()
        await expect(
            page.locator('[id^="support-chat-message-actions-"]')
        ).toHaveCount(0)

        await Promise.all([
            page.waitForResponse(
                r =>
                    /\/support-chats\/[^/]+\/reopen\b/.test(r.url()) &&
                    r.request().method() === 'POST' &&
                    r.ok(),
                { timeout: 30_000 }
            ),
            page.locator('#support-chat-reopen').click(),
        ])

        await expect(page.locator('#support-chat-resolve')).toBeVisible({
            timeout: 15_000,
        })
        await expect(page.locator('#support-chat-composer-input')).toBeEnabled()

        const followUp = `e2e-clinic-reopen-${Date.now()}`
        await page.locator('#support-chat-composer-input').fill(followUp)
        await Promise.all([
            page.waitForResponse(
                r =>
                    /\/support-chats\/messages\b/.test(r.url()) &&
                    r.request().method() === 'POST' &&
                    r.ok(),
                { timeout: 30_000 }
            ),
            page.locator('#support-chat-composer-send').click(),
        ])

        await expect(
            page
                .locator('[data-slot="bubble-content"]')
                .filter({ hasText: followUp })
        ).toBeVisible({ timeout: 15_000 })
    })
})
