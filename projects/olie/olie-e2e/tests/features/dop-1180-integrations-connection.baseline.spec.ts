import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { resolvePageOrigin } from '../helpers/navigation'
import {
    createE2ECommunicationIntegration,
    deleteE2ECommunicationIntegration,
    openIntegrationDetails,
} from '../helpers/channel-conversation'

/**
 * DOP-1180 — baseline of the integrations list + details **before** `connection_state`
 * is shown in the UI.
 *
 * Today the surface only exposes `is_active` (Ativa / Pausada). The API already returns
 * `connection_state` / `connection_state_changed_at`, but the front ignores them. This
 * pins the current shape so the new indicator can be told apart from a regression:
 *
 *  - list rows render `.integration-row` with the Ativa/Pausada badge;
 *  - details lead with the Ativa/Pausada hero (copy + Pausar/Ativar);
 *  - the "Conexão com o provedor" panel is webhook/wiring, not session health.
 *
 * Absence of a `connection_state` badge is the gap under test in the feature specs —
 * this baseline does not fail when that UI is still missing.
 *
 * Uses the seeded `tester@olie.ai` frame. Each test creates/deletes its own named
 * `whatsapp_cloud` fixture.
 */
test.describe('DOP-1180 integrations connection baseline', () => {
    test.describe.configure({ timeout: 120_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
    })

    test('list shows is_active badge on the integration row', async ({ page }) => {
        const integration = await createE2ECommunicationIntegration(page, {
            name: `dop1180-list-${Date.now()}`,
        })

        try {
            await page.goto(`${resolvePageOrigin(page)}/frame/integrations/accounts`)

            const row = page
                .locator('.integration-row')
                .filter({ hasText: integration.name })
                .first()
            await expect(row).toBeVisible({ timeout: 30_000 })

            await expect(row.getByText(/Ativa|Active/i)).toBeVisible()
            await expect(row.getByText(/Pausada|Paused/i)).toHaveCount(0)
        } finally {
            await deleteE2ECommunicationIntegration(page, integration.id)
        }
    })

    test('details show is_active hero and provider wiring section', async ({ page }) => {
        const integration = await createE2ECommunicationIntegration(page, {
            name: `dop1180-details-${Date.now()}`,
        })

        try {
            await page.goto(`${resolvePageOrigin(page)}/frame/integrations/accounts`)
            await openIntegrationDetails(page, integration.name)

            await expect(page.getByText(/Ativa|Active/i).first()).toBeVisible()
            await expect(
                page
                    .getByText(
                        /Enviando e recebendo mensagens normalmente|Sending and receiving messages normally/i
                    )
                    .first()
            ).toBeVisible()
            await expect(
                page.getByRole('button', { name: /Pausar|Pause/i }).first()
            ).toBeVisible()

            // Webhook / wiring panel — same word "conexão", different meaning from session health.
            await expect(
                page
                    .getByRole('heading', {
                        name: /Conexão com o provedor|Connection to the provider/i,
                    })
                    .first()
            ).toBeVisible()
            await expect(
                page
                    .getByText(
                        /Por onde as mensagens chegam|Where messages come in/i
                    )
                    .first()
            ).toBeVisible()
        } finally {
            await deleteE2ECommunicationIntegration(page, integration.id)
        }
    })

    test('pausing flips the details hero to Pausada without touching provider wiring', async ({
        page,
    }) => {
        const integration = await createE2ECommunicationIntegration(page, {
            name: `dop1180-pause-${Date.now()}`,
        })

        try {
            await page.goto(`${resolvePageOrigin(page)}/frame/integrations/accounts`)
            await openIntegrationDetails(page, integration.name)

            const pauseResponse = page.waitForResponse(
                r =>
                    /\/integrations\//.test(r.url()) &&
                    r.request().method() === 'PUT' &&
                    (r.status() === 200 || r.status() === 422),
                { timeout: 30_000 }
            )

            await page.getByRole('button', { name: /Pausar|Pause/i }).first().click()
            expect((await pauseResponse).status()).toBe(200)

            await expect(page.getByText(/Pausada|Paused/i).first()).toBeVisible({
                timeout: 20_000,
            })
            await expect(
                page
                    .getByText(
                        /As mensagens que chegarem serão recusadas|Incoming messages will be rejected/i
                    )
                    .first()
            ).toBeVisible()
            await expect(
                page.getByRole('button', { name: /Ativar|Activate/i }).first()
            ).toBeVisible()

            await expect(
                page
                    .getByRole('heading', {
                        name: /Conexão com o provedor|Connection to the provider/i,
                    })
                    .first()
            ).toBeVisible()
        } finally {
            await deleteE2ECommunicationIntegration(page, integration.id)
        }
    })
})
