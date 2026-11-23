import { test, expect } from '@playwright/test'
import { loginAsDoctor } from './helpers/doctor'

/**
 * Doctor support-chat lifecycle: open/send, resolve (freeze composer), reopen, send again.
 *
 * Shares doctor1 with `support-chat.02-tv-41.spec.ts` — that suite must stay
 * alphabetically before this file when both run after one seed (`02-` < `doctor-`).
 */
test.describe('televisao-front support chat doctor lifecycle', () => {
    test.describe.configure({ timeout: 120_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsDoctor(page)
    })

    test('doctor can open, resolve, and reopen a support chat', async ({
        page,
    }) => {
        await page.goto('/dashboard/support-chat')

        await expect(page.locator('#support-chat-page')).toBeVisible({
            timeout: 30_000,
        })

        const empty = page.locator('#support-chat-empty')
        const thread = page.locator('#support-chat-thread')

        if (await empty.isVisible().catch(() => false)) {
            const body = `e2e-doctor-open-${Date.now()}`
            await page.locator('#support-chat-composer-input').fill(body)
            await Promise.all([
                page.waitForResponse(
                    (r) =>
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

        if (await page.locator('#support-chat-reopen').isVisible().catch(() => false)) {
            await Promise.all([
                page.waitForResponse(
                    (r) =>
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
                (r) =>
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

        await Promise.all([
            page.waitForResponse(
                (r) =>
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

        const followUp = `e2e-doctor-reopen-${Date.now()}`
        await page.locator('#support-chat-composer-input').fill(followUp)
        await Promise.all([
            page.waitForResponse(
                (r) =>
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
