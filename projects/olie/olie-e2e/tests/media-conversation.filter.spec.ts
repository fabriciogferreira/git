import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from './helpers/auth'
import { createE2EProject } from './helpers/project'
import { requireLogsFilterHidesMessage } from './helpers/feature'
import {
    openProjectContentTab,
    sendMediaMessage,
    setContentFilter,
} from './helpers/content-media'

test.describe.configure({ timeout: 90_000 })

test('content tab: does not show sent message while Logs filter is active', async ({ page }) => {
    const message = `e2e-conversation-logs-${Date.now()}`

    await loginAsE2EUser(page)
    const projectId = await createE2EProject(page)
    await openProjectContentTab(page, projectId)
    await setContentFilter(page, 'logs')

    const feed = page.locator('#media_conversation_content')
    await sendMediaMessage(page, message)

    await requireLogsFilterHidesMessage(feed, message)
    await expect(feed.getByText(message)).toHaveCount(0)
})

test('content tab: shows sent message while Content filter is active', async ({ page }) => {
    const message = `e2e-conversation-content-${Date.now()}`

    await loginAsE2EUser(page)
    const projectId = await createE2EProject(page)
    await openProjectContentTab(page, projectId)
    await setContentFilter(page, 'content')

    const feed = page.locator('#media_conversation_content')
    await sendMediaMessage(page, message)

    await expect(feed.getByText(message)).toBeVisible({ timeout: 10_000 })
})
