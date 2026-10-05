import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { requireVisible } from '../helpers/feature'
import { resolvePageOrigin } from '../helpers/navigation'
import {
    createE2ECommunicationIntegration,
    deleteE2ECommunicationIntegration,
    openIntegrationDetails,
} from '../helpers/channel-conversation'
import { mockIntegrationConnectionState } from '../helpers/integration-connection'

/**
 * DOP-1180 — feature specs for the connection-state indicator (list + details).
 *
 * Skips when `.integration-connection-badge` is absent (front without this card).
 * Cloud fixtures from the API stay `unknown` with null `changed_at`; other states are
 * stubbed via `mockIntegrationConnectionState` (field is not client-writable).
 */
test.describe('DOP-1180 integrations connection state', () => {
    test.describe.configure({ timeout: 120_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
    })

    test('list and details show the connection badge next to is_active (unknown)', async ({
        page,
    }) => {
        const integration = await createE2ECommunicationIntegration(page, {
            name: `dop1180-feat-unknown-${Date.now()}`,
        })

        try {
            await page.goto(`${resolvePageOrigin(page)}/frame/integrations/accounts`)

            const row = page
                .locator('.integration-row')
                .filter({ hasText: integration.name })
                .first()
            await expect(row).toBeVisible({ timeout: 30_000 })

            const listBadge = row.locator('.integration-connection-badge')
            await requireVisible(page, 'DOP-1180', listBadge)

            await expect(row.getByText(/Ativa|Active/i)).toBeVisible()
            await expect(listBadge).toHaveAttribute('data-connection-state', 'unknown')
            await expect(listBadge.getByText(/Desconhecido|Unknown/i)).toBeVisible()

            await openIntegrationDetails(page, integration.name)

            const detailsBadge = page.locator('.integration-connection-badge').first()
            await expect(detailsBadge).toBeVisible()
            await expect(detailsBadge).toHaveAttribute('data-connection-state', 'unknown')
            await expect(
                page.getByText(/Sessão com o provedor|Provider session/i).first()
            ).toBeVisible()
            await expect(
                page
                    .getByText(/Ainda sem informação do provedor|No information from the provider yet/i)
                    .first()
            ).toBeVisible()

            // unknown + null changed_at → no relative-time line under the badge.
            await expect(
                detailsBadge.locator('.text-muted.fs-8')
            ).toHaveCount(0)

            // Webhook wiring panel stays a separate concept.
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

    test('active + disconnected shows both indicators and relative time on details', async ({
        page,
    }) => {
        const integration = await createE2ECommunicationIntegration(page, {
            name: `dop1180-feat-disc-${Date.now()}`,
        })

        const changedAt = new Date(Date.now() - 3 * 60 * 60 * 1000).toISOString()

        try {
            await mockIntegrationConnectionState(page, integration.id, {
                connection_state: 'disconnected',
                connection_state_changed_at: changedAt,
            })

            await page.goto(`${resolvePageOrigin(page)}/frame/integrations/accounts`)

            const row = page
                .locator('.integration-row')
                .filter({ hasText: integration.name })
                .first()
            await expect(row).toBeVisible({ timeout: 30_000 })

            const listBadge = row.locator('.integration-connection-badge')
            await requireVisible(page, 'DOP-1180', listBadge)

            await expect(row.getByText(/Ativa|Active/i)).toBeVisible()
            await expect(listBadge).toHaveAttribute('data-connection-state', 'disconnected')
            await expect(listBadge.getByText(/Desconectada|Disconnected/i)).toBeVisible()

            await openIntegrationDetails(page, integration.name)

            const detailsBadge = page.locator('.integration-connection-badge').first()
            await expect(detailsBadge).toHaveAttribute('data-connection-state', 'disconnected')
            await expect(
                page
                    .getByText(
                        /A sessão com o provedor caiu|The provider session dropped/i
                    )
                    .first()
            ).toBeVisible()
            // moment fromNow — locale-dependent ("há 3 horas" / "3 hours ago").
            await expect(detailsBadge.locator('.text-muted.fs-8')).toBeVisible()
            await expect(detailsBadge.locator('.text-muted.fs-8')).toHaveText(
                /\d|hora|hour|ago|há/i
            )

            await expect(page.getByText(/Ativa|Active/i).first()).toBeVisible()
            await expect(
                page.getByRole('button', { name: /Pausar|Pause/i }).first()
            ).toBeVisible()
        } finally {
            await deleteE2ECommunicationIntegration(page, integration.id)
        }
    })

    test('pausing keeps connection_state while flipping is_active to Pausada', async ({
        page,
    }) => {
        const integration = await createE2ECommunicationIntegration(page, {
            name: `dop1180-feat-pause-${Date.now()}`,
        })

        try {
            await mockIntegrationConnectionState(page, integration.id, {
                connection_state: 'connected',
                connection_state_changed_at: new Date().toISOString(),
            })

            await page.goto(`${resolvePageOrigin(page)}/frame/integrations/accounts`)
            await openIntegrationDetails(page, integration.name)

            const detailsBadge = page.locator('.integration-connection-badge').first()
            await requireVisible(page, 'DOP-1180', detailsBadge)
            await expect(detailsBadge).toHaveAttribute('data-connection-state', 'connected')

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
            await expect(detailsBadge).toHaveAttribute('data-connection-state', 'connected')
            await expect(detailsBadge.getByText(/Conectada|Connected/i)).toBeVisible()

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
