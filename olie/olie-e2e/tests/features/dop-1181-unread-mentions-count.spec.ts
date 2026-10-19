import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'

/**
 * DOP-1181 — the unread badge must ask only for the count, and the mentions
 * list must still load once. Opening home used to fire the full mentions index
 * several times just to paint the badge.
 */
test.describe('DOP-1181 unread mentions count', () => {
    test.describe.configure({ timeout: 120_000 })

    test('loads the badge from the count endpoint and the list once', async ({ page }) => {
        const indexUrls: string[] = []

        page.on('request', request => {
            if (request.method() !== 'GET') return
            const url = request.url()
            if (url.includes('/mentions/count')) return
            if (/\/mentions(\?|$)/.test(url)) indexUrls.push(url)
        })

        const countResponse = page.waitForResponse(
            response =>
                response.url().includes('/mentions/count') &&
                response.request().method() === 'GET' &&
                response.status() === 200,
            { timeout: 45_000 }
        )

        // Injected login lands on home, which is the mentions screen and fires the count.
        await loginAsE2EUser(page)

        const response = await countResponse
        const body = (await response.json()) as { response?: boolean; not_viewed?: number }
        expect(body.response).toBe(true)
        expect(typeof body.not_viewed).toBe('number')

        await expect(page.getByRole('button', { name: 'Todas' })).toBeVisible({ timeout: 20_000 })
        await expect.poll(() => indexUrls.length, { timeout: 20_000 }).toBe(1)
    })
})
