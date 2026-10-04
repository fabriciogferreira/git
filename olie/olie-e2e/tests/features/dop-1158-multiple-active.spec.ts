import { test, expect, type Page } from '@playwright/test'
import { loginAsIsolatedE2EUser } from '../helpers/isolated-user'
import { createE2EProject } from '../helpers/project'
import { openProjectContentTab } from '../helpers/content-media'
import {
    channelDialog,
    createE2ECommunicationIntegration,
    deleteE2ECommunicationIntegration,
    e2eCounterpart,
    fillCounterpartPhone,
    listProjectChannels,
    openChannelDialog,
    openExternalConversationViaApi,
    pickIntegration,
    selectExternalMode,
    submitOpenConversation,
} from '../helpers/channel-conversation'
import { setCompanyMultipleActiveChannelsViaApi } from '../helpers/frame-settings'

/**
 * DOP-1158 — the behaviour itself: with the option on, two active conversations may coexist for
 * the same counterpart, and turning it back off refuses new ones without closing what is open.
 *
 * The first test drives the real channel dialog (the front half of the feature); the second flips
 * the company default through the API and asserts the resolution, so it does not spend the request
 * budget that the dialog flow needs. The company card itself is covered by
 * `dop-1158-company-settings.spec.ts`.
 *
 * Complements the baseline (`dop-1158-channels.baseline.spec.ts`), which pins the off/default
 * shape (`active_channel_elsewhere` + the front's move-over question).
 *
 * Runs on an isolated user + work frame per worker, so no fixture collides with another spec.
 */
test.describe('DOP-1158 multiple active conversations — behaviour', () => {
    test.describe.configure({ timeout: 300_000 })

    test.beforeEach(async ({ page, request }, testInfo) => {
        await loginAsIsolatedE2EUser(page, request, { workerIndex: testInfo.parallelIndex })
    })

    async function openExternalConversation(
        page: Page,
        integrationName: string,
        projectId: string,
        national: string
    ) {
        await openProjectContentTab(page, projectId)
        await openChannelDialog(page)
        await selectExternalMode(page)
        await pickIntegration(page, integrationName)
        await fillCounterpartPhone(page, national)
        return submitOpenConversation(page)
    }

    test('an integration override allows a second active conversation for the same counterpart', async ({
        page,
    }) => {
        const integration = await createE2ECommunicationIntegration(page, {
            config: { allow_multiple_active_channels: true },
        })
        const suffix = Date.now()
        const firstProject = await createE2EProject(page, {
            name: `dop1158-override-a-${suffix}`,
        })
        const secondProject = await createE2EProject(page, {
            name: `dop1158-override-b-${suffix}`,
        })
        const counterpart = e2eCounterpart()

        try {
            const first = await openExternalConversation(
                page,
                integration.name,
                firstProject,
                counterpart.national
            )
            expect(first?.status(), await first?.text()).toBe(201)

            // Same counterpart, another card: with the override on this is a second conversation,
            // not the 409 `active_channel_elsewhere` of the baseline.
            const second = await openExternalConversation(
                page,
                integration.name,
                secondProject,
                counterpart.national
            )
            expect(second?.status(), await second?.text()).toBe(201)
            await expect(channelDialog(page)).toBeHidden({ timeout: 20_000 })

            for (const projectId of [firstProject, secondProject]) {
                const channels = await listProjectChannels(page, projectId)
                expect(channels).toHaveLength(1)
                expect(channels[0]).toMatchObject({
                    is_active: true,
                    external_ref: counterpart.externalRef,
                    integration_id: integration.id,
                })
            }
        } finally {
            await deleteE2ECommunicationIntegration(page, integration.id)
        }
    })

    test('company setting allows duplicates; turning it off blocks new opens and closes nothing', async ({
        page,
    }) => {
        const integration = await createE2ECommunicationIntegration(page)
        const suffix = Date.now()
        const firstProject = await createE2EProject(page, {
            name: `dop1158-company-a-${suffix}`,
        })
        const secondProject = await createE2EProject(page, {
            name: `dop1158-company-b-${suffix}`,
        })
        const thirdProject = await createE2EProject(page, {
            name: `dop1158-company-c-${suffix}`,
        })
        const counterpart = e2eCounterpart()

        const open = (projectId: string) =>
            openExternalConversationViaApi(page, {
                projectId,
                integrationId: integration.id,
                externalRef: counterpart.externalRef,
            })

        try {
            expect(await setCompanyMultipleActiveChannelsViaApi(page, true)).toBe(200)

            expect(await open(firstProject)).toBe(201)
            expect(await open(secondProject)).toBe(201)

            // Turn the feature back off. Existing duplicates must stay untouched...
            expect(await setCompanyMultipleActiveChannelsViaApi(page, false)).toBe(200)

            for (const projectId of [firstProject, secondProject]) {
                const channels = await listProjectChannels(page, projectId)
                expect(channels).toHaveLength(1)
                expect(channels[0].is_active).toBe(true)
            }

            // ...and the next open for that counterpart is refused again.
            expect(await open(thirdProject)).toBe(409)
            expect(await listProjectChannels(page, thirdProject)).toHaveLength(0)
        } finally {
            await setCompanyMultipleActiveChannelsViaApi(page, false).catch(() => undefined)
            await deleteE2ECommunicationIntegration(page, integration.id)
        }
    })
})
