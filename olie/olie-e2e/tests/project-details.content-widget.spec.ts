import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from './helpers/auth'
import { createE2EProject } from './helpers/project'
import { openProjectOverview } from './helpers/content-media'

test('opens project details with ContentWidget', async ({ page }) => {
    await loginAsE2EUser(page)
    const projectId = await createE2EProject(page)
    await openProjectOverview(page, projectId)

    await expect(page).toHaveURL(new RegExp(`/projects/${projectId}/details/overview`))
    await expect(page.locator('#project_media_content')).toBeVisible()
})
