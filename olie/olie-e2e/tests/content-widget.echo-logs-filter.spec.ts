import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from './helpers/auth'
import { createE2EProject } from './helpers/project'
import { requireLogsFilterHidesMessage } from './helpers/feature'
import {
    openProjectOverview,
    sendMediaMessage,
    setContentFilter,
} from './helpers/content-media'

test('echo does not show peer message while Logs filter is active', async ({ browser }) => {
    test.setTimeout(90_000)

    const message = `e2e-echo-logs-${Date.now()}`

    const viewerContext = await browser.newContext()
    const senderContext = await browser.newContext()
    const viewer = await viewerContext.newPage()
    const sender = await senderContext.newPage()

    try {
        await loginAsE2EUser(viewer)
        const projectId = await createE2EProject(viewer)

        await loginAsE2EUser(sender)

        await openProjectOverview(viewer, projectId)
        await openProjectOverview(sender, projectId)

        await setContentFilter(viewer, 'logs')
        await setContentFilter(sender, 'content')

        await viewer.waitForTimeout(1000)

        await sendMediaMessage(sender, message)
        await expect(sender.locator('#project_media_content').getByText(message)).toBeVisible({
            timeout: 10_000,
        })

        const viewerFeed = viewer.locator('#project_media_content')
        await requireLogsFilterHidesMessage(viewerFeed, message, 2_000)
        await expect(viewerFeed.getByText(message)).toHaveCount(0)
    } finally {
        await viewerContext.close()
        await senderContext.close()
    }
})
