import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from './helpers/auth'

/**
 * Smoke: login against local management (seeded tester@olie.ai / password).
 */
test('logs into management', async ({ page }) => {
    await loginAsE2EUser(page)
    await expect(page).not.toHaveURL(/\/auth/)
})
