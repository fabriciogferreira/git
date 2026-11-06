import { type Page, expect } from '@playwright/test'
import { resolvePageOrigin } from './navigation'
import { requireFeature } from './feature'

/**
 * DOP-1258 — native event webhooks under Integrações → API → Webhooks.
 *
 * Gated by Pennant `webhook` + `webhooks.index`. Skip when the running front
 * still shows the coming-soon card or the tab is missing.
 */
export async function openFrameWebhooks(page: Page) {
    await page.goto(`${resolvePageOrigin(page)}/frame/integrations/api/webhooks`)
    await requireFeature(page, {
        id: 'DOP-1258',
        probe: async () => {
            const comingSoon = page.getByText(/Em breve|Coming soon/i).first()
            const createBtn = page.getByRole('button', {
                name: /Novo webhook|New webhook/i,
            })
            try {
                await Promise.race([
                    createBtn.waitFor({ state: 'visible', timeout: 12_000 }),
                    comingSoon.waitFor({ state: 'visible', timeout: 12_000 }),
                ])
            } catch {
                return false
            }
            if (await comingSoon.isVisible().catch(() => false)) {
                return false
            }
            return createBtn.isVisible().catch(() => false)
        },
    })
    await expect(
        page.getByRole('button', { name: /Novo webhook|New webhook/i })
    ).toBeVisible()
}

export function webhookCreateButton(page: Page) {
    return page.getByRole('button', { name: /Novo webhook|New webhook/i })
}

export function webhookEmptyTitle(page: Page) {
    return page.getByText(/Nenhum webhook ainda|No webhooks yet/i)
}

export function webhookRow(page: Page, nameOrUrl: string | RegExp) {
    return page.locator('.webhook-row').filter({ hasText: nameOrUrl }).first()
}

/** Public HTTPS target SafeUrlGuard accepts (not loopback / private). */
export function e2eWebhookTargetUrl(suffix: string) {
    return `https://example.com/olie-e2e-webhooks/${encodeURIComponent(suffix)}`
}
