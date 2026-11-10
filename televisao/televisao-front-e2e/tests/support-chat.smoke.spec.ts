import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from './helpers/auth'

/**
 * Support chat (super inbox) smoke for recent UX fixes:
 * breadcrumb label, headset nav icon, accent-insensitive search,
 * and long-message wrapping in the thread bubble.
 */
test.describe('televisao-front support chat', () => {
    test.describe.configure({ timeout: 120_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
    })

    test('shows Home > Suporte breadcrumb and headset nav icon', async ({
        page,
    }) => {
        await page.goto('/dashboard/support-chat')

        await expect(page.locator('#support-chat-inbox')).toBeVisible({
            timeout: 30_000,
        })

        const breadcrumb = page.getByRole('navigation', { name: /breadcrumb/i })
        await expect(breadcrumb.getByText(/^Home$/i)).toBeVisible()
        await expect(breadcrumb.getByText(/^Suporte$/i)).toBeVisible()

        const supportNav = page.locator('a[href*="support-chat"]').first()
        await expect(supportNav).toBeVisible()
        await expect(supportNav.locator('svg.lucide-headset')).toBeVisible()
    })

    test('finds accented clinic names with ascii search', async ({ page }) => {
        await page.goto('/dashboard/support-chat')

        await expect(page.locator('#support-chat-inbox')).toBeVisible({
            timeout: 30_000,
        })

        const search = page.locator('#support-chat-inbox-search')
        await search.fill('cli')

        await expect
            .poll(
                async () =>
                    page.locator('[id^="support-chat-inbox-item-"]').count(),
                { timeout: 20_000 }
            )
            .toBeGreaterThan(0)

        await expect(
            page
                .locator('[id^="support-chat-inbox-item-"]')
                .filter({ hasText: /Cl[ií]nica/i })
                .first()
        ).toBeVisible({ timeout: 15_000 })

        await search.fill('zzz-clinica-inexistente-e2e')
        await expect(
            page.getByText(/Nenhum chamado nesta lista/i)
        ).toBeVisible({ timeout: 20_000 })
    })

    test('wraps a long unbroken message inside the bubble width', async ({
        page,
    }) => {
        await page.goto('/dashboard/support-chat')

        await expect(page.locator('#support-chat-inbox')).toBeVisible({
            timeout: 30_000,
        })

        const firstChat = page.locator('[id^="support-chat-inbox-item-"]').first()
        await expect(firstChat).toBeVisible({ timeout: 20_000 })
        await firstChat.click()

        await expect(page.locator('#support-chat-thread')).toBeVisible({
            timeout: 20_000,
        })
        await expect(page.locator('#support-chat-composer-input')).toBeVisible({
            timeout: 15_000,
        })

        const longWord = 'a'.repeat(280)
        await page.locator('#support-chat-composer-input').fill(longWord)

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

        const bubble = page
            .locator('[data-slot="bubble-content"]')
            .filter({ hasText: longWord.slice(0, 40) })
            .last()

        await expect(bubble).toBeVisible({ timeout: 20_000 })

        const metrics = await bubble.evaluate(el => ({
            width: el.clientWidth,
            height: el.clientHeight,
            scrollWidth: el.scrollWidth,
        }))

        // Must use real bubble width (not ~1 glyph) and stay within max ~24rem.
        expect(metrics.width).toBeGreaterThan(120)
        expect(metrics.width).toBeLessThanOrEqual(400)
        expect(metrics.scrollWidth).toBeLessThanOrEqual(metrics.width + 2)
        // 280 a's at ~1ch would be thousands of px tall if the old collapse bug returned.
        expect(metrics.height).toBeLessThan(900)
    })
})
