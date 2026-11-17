import { type Page, expect } from '@playwright/test'
import { resolvePageOrigin } from './navigation'
import { requireFeature } from './feature'

/**
 * DOP-1258 — native event webhooks under Integrações → API → Webhooks.
 *
 * Feature flag was removed; the tab is always registered. Skip when the
 * running front still lacks the create CTA (old build) or the user cannot
 * see `webhooks.index`.
 */
export async function openFrameWebhooks(page: Page) {
    await page.goto(`${resolvePageOrigin(page)}/frame/integrations/api/webhooks`)
    await requireFeature(page, {
        id: 'DOP-1258',
        probe: async () => {
            const createBtn = page.getByRole('button', {
                name: /Novo webhook|New webhook/i,
            })
            try {
                await createBtn.first().waitFor({ state: 'visible', timeout: 12_000 })
                return true
            } catch {
                // Old coming-soon stub or missing permission — skip.
                return false
            }
        },
    })
    await expect(
        page.getByRole('button', { name: /Novo webhook|New webhook/i }).first()
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
