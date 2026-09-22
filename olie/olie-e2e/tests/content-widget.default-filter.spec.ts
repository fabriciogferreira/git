import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from './helpers/auth'
import { createE2EProject } from './helpers/project'
import {
    openProjectOverview,
    sendMediaMessage,
    setContentFilter,
} from './helpers/content-media'

test('shows sent message while Content and Logs filter is active', async ({ page }) => {
    const message = `e2e-default-filter-${Date.now()}`

    await loginAsE2EUser(page)
    const projectId = await createE2EProject(page)
    await openProjectOverview(page, projectId)
    await setContentFilter(page, 'default')

    const feed = page.locator('#project_media_content')
    await sendMediaMessage(page, message)

    await expect(feed.getByText(message)).toBeVisible({ timeout: 10_000 })
})
