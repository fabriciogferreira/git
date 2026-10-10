import { test, expect } from '@playwright/test'
import { loginAsIsolatedE2EUser } from '../helpers/isolated-user'
import { resolvePageOrigin } from '../helpers/navigation'
import {
    chooseMultipleActiveChannels,
    createE2ECommunicationIntegration,
    deleteE2ECommunicationIntegration,
    getE2EIntegration,
    multipleActiveChannelsField,
    openIntegrationDetails,
    openIntegrationForm,
    requireMultipleActiveChannelsIntegration,
    saveIntegrationForm,
} from '../helpers/channel-conversation'

/**
 * DOP-1158 — tri-state override on an integration.
 *
 * The stored value is `config.allow_multiple_active_channels`: `true` / `false` / **absent**, and
 * absence is what "inherit from the company" means. `UpdateIntegration` replaces the whole `config`
 * group, so the modal has to omit the key on "inherit" — sending `false` there would silently turn
 * the feature off instead of following the company.
 *
 * Runs on an isolated user + work frame per worker (parallel-safe; no shared `devframe` seed).
 */
test.describe('DOP-1158 multiple active conversations — integration override', () => {
    test.describe.configure({ timeout: 120_000 })

    test.beforeEach(async ({ page, request }, testInfo) => {
        await loginAsIsolatedE2EUser(page, request, { workerIndex: testInfo.parallelIndex })
    })

    test('hydrates and persists the tri-state, omitting the key when inheriting', async ({ page }) => {
        const integration = await createE2ECommunicationIntegration(page, {
            config: { allow_multiple_active_channels: true },
        })

        try {
            // Opening the form lands on the details route; go back to the list each time.
            const openForm = async () => {
                await page.goto(`${resolvePageOrigin(page)}/frame/integrations/accounts`)
                return openIntegrationForm(page, integration.name)
            }

            let dialog = await openForm()
            await requireMultipleActiveChannelsIntegration(page, dialog)

            // A stored `true` hydrates to "allow".
            await expect(multipleActiveChannelsField(dialog)).toHaveText(
                /Permitir várias|Allow several/i
            )

            // inherit → the key must leave the stored config (not become `false`).
            await chooseMultipleActiveChannels(page, dialog, 'inherit')
            expect((await saveIntegrationForm(page)).status()).toBe(200)
            await expect(dialog).toBeHidden({ timeout: 20_000 })

            let stored = await getE2EIntegration(page, integration.id)
            expect(stored?.config).toMatchObject({ graph_version: 'v21.0' })
            expect(stored?.config).not.toHaveProperty('allow_multiple_active_channels')

            // block → explicit `false`.
            dialog = await openForm()
            await expect(multipleActiveChannelsField(dialog)).toHaveText(
                /Herdar da empresa|Inherit from the company/i
            )
            await chooseMultipleActiveChannels(page, dialog, 'block')
            expect((await saveIntegrationForm(page)).status()).toBe(200)
            await expect(dialog).toBeHidden({ timeout: 20_000 })

            stored = await getE2EIntegration(page, integration.id)
            expect(stored?.config).toMatchObject({
                graph_version: 'v21.0',
                allow_multiple_active_channels: false,
            })

            // allow → explicit `true`.
            dialog = await openForm()
            await expect(multipleActiveChannelsField(dialog)).toHaveText(
                /Permitir apenas uma|Allow only one/i
            )
            await chooseMultipleActiveChannels(page, dialog, 'allow')
            expect((await saveIntegrationForm(page)).status()).toBe(200)
            await expect(dialog).toBeHidden({ timeout: 20_000 })

            stored = await getE2EIntegration(page, integration.id)
            expect(stored?.config).toMatchObject({
                graph_version: 'v21.0',
                allow_multiple_active_channels: true,
            })
        } finally {
            await deleteE2ECommunicationIntegration(page, integration.id)
        }
    })

    test('shows the effective state on the integration details', async ({ page }) => {
        const allowed = await createE2ECommunicationIntegration(page, {
            config: { allow_multiple_active_channels: true },
        })
        const blocked = await createE2ECommunicationIntegration(page, {
            config: { allow_multiple_active_channels: false },
        })

        try {
            await page.goto(`${resolvePageOrigin(page)}/frame/integrations/accounts`)
            await openIntegrationDetails(page, allowed.name)
            await expect(
                page.getByText(/Conversas ativas por contato|Active conversations per contact/i).first()
            ).toBeVisible()
            await expect(
                page
                    .getByText(
                        /Permitindo várias conversas por contato \(nesta integração\)|Allowing multiple conversations per contact \(this integration\)/i
                    )
                    .first()
            ).toBeVisible()

            await page.goto(`${resolvePageOrigin(page)}/frame/integrations/accounts`)
            await openIntegrationDetails(page, blocked.name)
            await expect(
                page
                    .getByText(
                        /Permitindo uma conversa por contato \(nesta integração\)|Allowing one conversation per contact \(this integration\)/i
                    )
                    .first()
            ).toBeVisible()
        } finally {
            await deleteE2ECommunicationIntegration(page, allowed.id)
            await deleteE2ECommunicationIntegration(page, blocked.id)
        }
    })
})
