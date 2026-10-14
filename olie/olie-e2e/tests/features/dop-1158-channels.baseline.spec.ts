import { test, expect } from '@playwright/test'
import { loginAsIsolatedE2EUser } from '../helpers/isolated-user'
import { resolvePageOrigin } from '../helpers/navigation'
import { createE2EProject } from '../helpers/project'
import { openProjectContentTab } from '../helpers/content-media'
import {
    ACTIVE_CHANNEL_ELSEWHERE_PROMPT,
    answerActiveChannelElsewhere,
    channelDialog,
    channelRailItem,
    createE2ECommunicationIntegration,
    deleteE2ECommunicationIntegration,
    e2eCounterpart,
    expectActiveChannelElsewherePrompt,
    fillCounterpartPhone,
    getE2EIntegration,
    listProjectChannels,
    openChannelDialog,
    openIntegrationForm,
    pickIntegration,
    saveIntegrationForm,
    selectExternalMode,
    submitOpenConversation,
} from '../helpers/channel-conversation'

/**
 * DOP-1158 — baseline of the external-conversation flow before
 * `allow_multiple_active_channels` changes anything.
 *
 * Today the backend refuses a second active conversation for the same counterpart and the front
 * offers to close the other one. That is the behaviour being relaxed; this pins the current shape
 * so the relaxation can be told apart from a regression:
 *
 *  - a fresh counterpart opens a conversation that shows up in the channel rail;
 *  - the same counterpart in another card hits `active_channel_elsewhere` (409) and the front
 *    asks before touching the other conversation;
 *  - declining leaves both cards alone, accepting moves the conversation over;
 *  - the account's settings modal (where the tri-state will be added) opens, keeps its
 *    `graph_version`, and still refuses to show the stored credentials.
 *
 * Runs on an isolated user + work frame per worker, so the fixtures never collide with another spec
 * and the file is parallel-safe.
 */
test.describe('DOP-1158 channels baseline', () => {
    test.describe.configure({ timeout: 240_000 })

    test.beforeEach(async ({ page, request }, testInfo) => {
        await loginAsIsolatedE2EUser(page, request, { workerIndex: testInfo.parallelIndex })
    })

    test('opens an external conversation and lists it in the channel rail', async ({ page }) => {
        const integration = await createE2ECommunicationIntegration(page)
        const projectId = await createE2EProject(page, { name: `dop1158-open-${Date.now()}` })
        const counterpart = e2eCounterpart()

        try {
            await openProjectContentTab(page, projectId)
            await openChannelDialog(page)
            await selectExternalMode(page)
            await pickIntegration(page, integration.name)
            await fillCounterpartPhone(page, counterpart.national)

            const response = await submitOpenConversation(page)
            expect(response?.status(), await response?.text()).toBe(201)

            await expect(channelDialog(page)).toBeHidden({ timeout: 20_000 })
            await expect(channelRailItem(page, 'WhatsApp')).toBeVisible({ timeout: 20_000 })

            const channels = await listProjectChannels(page, projectId)
            expect(channels).toHaveLength(1)
            expect(channels[0]).toMatchObject({
                name: 'WhatsApp',
                is_active: true,
                external_ref: counterpart.externalRef,
                integration_id: integration.id,
            })
        } finally {
            await deleteE2ECommunicationIntegration(page, integration.id)
        }
    })

    test('asks before moving an active conversation to another card', async ({ page }) => {
        const integration = await createE2ECommunicationIntegration(page)
        const suffix = Date.now()
        const firstProject = await createE2EProject(page, {
            name: `dop1158-hold-${suffix}`,
        })
        const secondProject = await createE2EProject(page, {
            name: `dop1158-take-${suffix}`,
        })
        const counterpart = e2eCounterpart()

        const openWith = async (projectId: string, phone: string) => {
            await openProjectContentTab(page, projectId)
            await openChannelDialog(page)
            await selectExternalMode(page)
            await pickIntegration(page, integration.name)
            await fillCounterpartPhone(page, phone)
            return submitOpenConversation(page)
        }

        try {
            const created = await openWith(firstProject, counterpart.national)
            expect(created?.status(), await created?.text()).toBe(201)

            // Same counterpart, another card: the backend answers 409 and the front questions it.
            const conflict = await openWith(secondProject, counterpart.national)
            expect(conflict?.status()).toBe(409)
            expect(await conflict?.text()).toContain('active_channel_elsewhere')
            await expectActiveChannelElsewherePrompt(page)

            // Declining must leave both cards exactly as they were.
            await answerActiveChannelElsewhere(page, { confirm: false })
            await expect(page.locator('.swal2-container')).toBeHidden({ timeout: 20_000 })
            await expect(channelDialog(page)).toBeVisible()

            expect(await listProjectChannels(page, secondProject)).toHaveLength(0)
            const untouched = await listProjectChannels(page, firstProject)
            expect(untouched).toHaveLength(1)
            expect(untouched[0].is_active).toBe(true)

            // Accepting closes the other conversation and opens it here.
            const moved = await openWith(secondProject, counterpart.national)
            expect(moved?.status(), await moved?.text()).toBe(409)
            await expect(page.locator('.swal2-container')).toContainText(
                ACTIVE_CHANNEL_ELSEWHERE_PROMPT
            )
            await answerActiveChannelElsewhere(page, {
                confirm: true,
                reason: 'dop1158 baseline',
            })

            await expect(channelDialog(page)).toBeHidden({ timeout: 25_000 })
            const taken = await listProjectChannels(page, secondProject)
            expect(taken).toHaveLength(1)
            expect(taken[0]).toMatchObject({ is_active: true, external_ref: counterpart.externalRef })

            const released = await listProjectChannels(page, firstProject)
            expect(released).toHaveLength(1)
            expect(released[0].is_active).toBe(false)
        } finally {
            await deleteE2ECommunicationIntegration(page, integration.id)
        }
    })

    test('opens the integration settings and saves them untouched', async ({ page }) => {
        const integration = await createE2ECommunicationIntegration(page)

        try {
            await page.goto(`${resolvePageOrigin(page)}/frame/integrations/accounts`)
            const dialog = await openIntegrationForm(page, integration.name)

            // Credentials are secrets: the modal never echoes them, it states they are stored and
            // only offers to replace them. Saving the settings must not wipe them.
            await expect(
                dialog.getByText(/Credenciais salvas|Credentials saved/i).first()
            ).toBeVisible()
            await expect(
                dialog.locator('button:has-text("Substituir credenciais"), button:has-text("Replace credentials")').first()
            ).toBeVisible()
            await expect(dialog.locator('#integration-credentials-phone_number_id')).toHaveCount(0)

            // The connector's own settings — where the tri-state will live.
            await expect(dialog.locator('#integration-config-graph_version')).toHaveValue('v21.0')

            const response = await saveIntegrationForm(page)
            expect(response.status()).toBe(200)
            await expect(dialog).toBeHidden({ timeout: 20_000 })

            const stored = await getE2EIntegration(page, integration.id)
            expect(stored?.config).toMatchObject({ graph_version: 'v21.0' })
        } finally {
            await deleteE2ECommunicationIntegration(page, integration.id)
        }
    })
})
