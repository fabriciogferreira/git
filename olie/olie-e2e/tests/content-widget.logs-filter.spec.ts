import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from './helpers/auth'
import { createE2EProject } from './helpers/project'
import { requireLogsFilterHidesMessage } from './helpers/feature'
import {
    openProjectOverview,
    sendMediaMessage,
    setContentFilter,
} from './helpers/content-media'

test('does not show sent message while Logs filter is active', async ({ page }) => {
    const message = `e2e-logs-filter-${Date.now()}`

    await loginAsE2EUser(page)
    const projectId = await createE2EProject(page)
    await openProjectOverview(page, projectId)
    await setContentFilter(page, 'logs')

    const feed = page.locator('#project_media_content')
    await sendMediaMessage(page, message)

    await requireLogsFilterHidesMessage(feed, message)
    await expect(feed.getByText(message)).toHaveCount(0)
})
