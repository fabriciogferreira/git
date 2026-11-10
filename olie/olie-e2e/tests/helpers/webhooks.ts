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
            // Prefer the create CTA — other Settings stubs also say "Em breve", so a
            // page-wide coming-soon match false-skips when the flag is already on.
            const createBtn = page.getByRole('button', {
                name: /Novo webhook|New webhook/i,
            })
            try {
                await createBtn.first().waitFor({ state: 'visible', timeout: 12_000 })
                return true
            } catch {
                // Flag off (or no permission): gated card / missing CTA — skip.
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
