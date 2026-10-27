import { test, expect } from '@playwright/test'
import { loginAsIsolatedE2EUser } from '../helpers/isolated-user'
import { createE2EProject, mergeE2EProjects } from '../helpers/project'
import {
    createE2ECommunicationIntegration,
    deleteE2ECommunicationIntegration,
    e2eCounterpart,
    listProjectChannels,
    openExternalConversationViaApi,
} from '../helpers/channel-conversation'

/**
 * OS-563 — merging projects must carry the majority project's WhatsApp channel
 * onto the survivor (active), instead of leaving it on the soft-deleted source.
 */
test.describe('OS-563 project merge keeps WhatsApp channel', () => {
    test.describe.configure({ timeout: 300_000 })

    test.beforeEach(async ({ page, request }, testInfo) => {
        await loginAsIsolatedE2EUser(page, request, { workerIndex: testInfo.parallelIndex })
    })

    test('survivor keeps the majority WhatsApp channel active', async ({ page }) => {
        const integration = await createE2ECommunicationIntegration(page)
        const suffix = Date.now()
        const majorityId = await createE2EProject(page, {
            name: `e2e-os563-majority-${suffix}`,
        })
        const otherId = await createE2EProject(page, {
            name: `e2e-os563-other-${suffix}`,
        })
        const counterpart = e2eCounterpart()

        try {
            expect(
                await openExternalConversationViaApi(page, {
                    projectId: majorityId,
                    integrationId: integration.id,
                    externalRef: counterpart.externalRef,
                })
            ).toBe(201)

            const before = await listProjectChannels(page, majorityId)
            const majorityChannel = before.find(
                channel =>
                    channel.is_active &&
                    channel.integration_id === integration.id &&
                    (channel.external_ref === counterpart.externalRef ||
                        channel.external_ref?.startsWith(counterpart.externalRef))
            )
            expect(majorityChannel, JSON.stringify(before)).toBeTruthy()

            const survivorId = await mergeE2EProjects(page, {
                majorityId,
                projectIds: [majorityId, otherId],
            })

            expect(survivorId).not.toBe(majorityId)

            const survivorChannels = await listProjectChannels(page, survivorId)
            const carried = survivorChannels.find(channel => channel.id === majorityChannel!.id)

            expect(carried, JSON.stringify(survivorChannels)).toBeTruthy()
            expect(carried!.is_active).toBe(true)
            expect(carried!.integration_id).toBe(integration.id)
        } finally {
            await deleteE2ECommunicationIntegration(page, integration.id)
        }
    })
})
