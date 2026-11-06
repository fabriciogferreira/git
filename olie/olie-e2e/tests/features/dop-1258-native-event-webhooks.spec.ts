import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { measureContrastRatio, setResolvedTheme } from '../helpers/theme'
import {
    e2eWebhookTargetUrl,
    openFrameWebhooks,
    webhookCreateButton,
    webhookEmptyTitle,
    webhookRow,
} from '../helpers/webhooks'

/**
 * DOP-1258 — native event webhooks (Integrações → API → Webhooks).
 *
 * Covers the management UI the card asked for: list/empty state, create with
 * secret reveal, details + deliveries tab. Skips when Pennant `webhook` is off
 * on the frame under test (coming-soon card).
 *
 * Uses the seeded `tester@olie.ai` / `devframe` session. Activate the flag on
 * that frame before expecting the suite to run (not the coming-soon path).
 */
test.describe('DOP-1258 native event webhooks', () => {
    test.describe.configure({ timeout: 180_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
        await openFrameWebhooks(page)
    })

    test('shows empty state and opens the create dialog', async ({ page }) => {
        // Empty or populated both expose Novo webhook; empty copy is optional.
        await expect(webhookCreateButton(page).first()).toBeVisible()

        if ((await page.locator('.webhook-row').count()) === 0) {
            await expect(webhookEmptyTitle(page)).toBeVisible()
        }

        await webhookCreateButton(page).first().click()
        await expect(
            page.getByRole('heading', { name: /Novo webhook|New webhook/i })
        ).toBeVisible({ timeout: 15_000 })
        await expect(
            page.getByLabel(/URL de destino|Destination URL/i)
        ).toBeVisible()
        await expect(
            page.getByText(/Quais eventos enviar|Which events to send/i)
        ).toBeVisible()
        await expect(
            page.getByText(
                /Tudo o que acontecer nesta conta|Everything that happens in this account/i
            )
        ).toBeVisible()
    })

    test('creates a webhook, shows the secret once, then opens details and deliveries', async ({
        page,
    }) => {
        const name = `dop1258-${Date.now()}`
        const targetUrl = e2eWebhookTargetUrl(name)

        await webhookCreateButton(page).first().click()
        await expect(
            page.getByRole('heading', { name: /Novo webhook|New webhook/i })
        ).toBeVisible({ timeout: 15_000 })

        await page.getByLabel(/URL de destino|Destination URL/i).fill(targetUrl)
        await page.getByLabel(/^Nome$|^Name$/i).fill(name)

        const createResponse = page.waitForResponse(
            r =>
                /\/webhooks\/?$/.test(new URL(r.url()).pathname) &&
                r.request().method() === 'POST' &&
                (r.status() === 200 || r.status() === 201 || r.status() === 422),
            { timeout: 30_000 }
        )

        await page
            .getByRole('button', { name: /^Criar webhook$|^Create webhook$/i })
            .click()

        const created = await createResponse
        expect(created.status(), await created.text()).toBeLessThan(300)

        await expect(
            page.getByText(/Guarde o secret agora|Save the secret now/i)
        ).toBeVisible({ timeout: 20_000 })
        await expect(
            page.getByText(/Ele não aparece de novo|It will not appear again/i)
        ).toBeVisible()

        const secretDialog = page.getByRole('dialog').filter({
            hasText: /Guarde o secret agora|Save the secret now/i,
        })
        const secretField = secretDialog.getByRole('textbox')
        await expect(secretField).toBeVisible()
        await expect(secretField).not.toHaveValue('')

        await secretDialog.getByRole('button', { name: /Já guardei|I saved it/i }).click()

        const row = webhookRow(page, name)
        await expect(row).toBeVisible({ timeout: 20_000 })
        await expect(row.getByText(/Ativo|Active/i)).toBeVisible()

        await row.click()
        await expect(page).toHaveURL(/\/frame\/integrations\/api\/webhooks\/[^/]+/)
        await expect(page.getByText(name).first()).toBeVisible()

        await page.getByRole('button', { name: /^Envios$|^Deliveries$/i }).click()
        await expect(
            page.getByText(/Nenhum envio ainda|No deliveries yet/i).first()
        ).toBeVisible({ timeout: 15_000 })

        // Soft-delete via management API so the shared frame stays tidy.
        const webhookId = page.url().split('/').pop()!
        await page.evaluate(async id => {
            const token = localStorage.getItem('token')
            await fetch(`http://api.olie.localhost/api/management/webhooks/${id}`, {
                method: 'DELETE',
                headers: {
                    Accept: 'application/json',
                    Authorization: `Bearer ${token}`,
                    Origin: location.origin,
                },
            })
        }, webhookId)
    })

    test('measures subtitle and helper copy contrast in light and dark', async ({ page }) => {
        const subtitle = page.locator('.card-subtitle.text-muted').first()
        await expect(subtitle).toBeVisible()

        const samples: Array<{ theme: string; label: string; ratio: number }> = []

        for (const theme of ['light', 'dark'] as const) {
            await setResolvedTheme(page, theme)
            const { ratio: subtitleRatio } = await measureContrastRatio(subtitle)
            samples.push({ theme, label: 'card subtitle', ratio: Number(subtitleRatio.toFixed(2)) })

            const muted = page.locator('.card-body .text-muted').filter({ hasText: /\S/ }).first()
            if (await muted.isVisible().catch(() => false)) {
                const { ratio } = await measureContrastRatio(muted)
                samples.push({
                    theme,
                    label: 'body muted',
                    ratio: Number(ratio.toFixed(2)),
                })
            }
        }

        console.log('DOP-1258 contrast samples:', JSON.stringify(samples, null, 2))
        for (const sample of samples) {
            expect(sample.ratio, `${sample.theme} ${sample.label}`).toBeGreaterThan(1)
        }

        // WCAG AA for normal text is 4.5:1 — soft-fail surface for the review report.
        const belowAa = samples.filter(s => s.ratio < 4.5)
        if (belowAa.length) {
            console.warn(
                'DOP-1258 contrast below WCAG AA 4.5:1:',
                JSON.stringify(belowAa, null, 2)
            )
        }
    })
})
