import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from './helpers/auth'
import { createE2EProject } from './helpers/project'
import {
    openProjectOverview,
    sendMediaMessage,
    setContentFilter,
} from './helpers/content-media'

test('shows sent message while Content filter is active', async ({ page }) => {
    const message = `e2e-content-filter-${Date.now()}`

    await loginAsE2EUser(page)
    const projectId = await createE2EProject(page)
    await openProjectOverview(page, projectId)
    await setContentFilter(page, 'content')

    const feed = page.locator('#project_media_content')
    await sendMediaMessage(page, message)

    await expect(feed.getByText(message)).toBeVisible({ timeout: 10_000 })
})
