import { test, expect } from '@playwright/test'
import { openGuestMeetRoom } from './helpers/meet'

test.describe('televisao-meet-front smoke', () => {
    test.describe.configure({ timeout: 90_000 })

    test('loads app shell with theme toggle', async ({ page }) => {
        await page.goto('/')
        await expect(page.locator('#toggle-theme-button')).toBeVisible({ timeout: 30_000 })
    })

    test('shows guest meet join UI for a room id', async ({ page }) => {
        await openGuestMeetRoom(page)
        await expect(page.getByText(/Nome do Paciente/i)).toBeVisible()
        await expect(page.getByPlaceholder('Nome')).toBeVisible()
    })

    test('accepts participant name on the join form', async ({ page }) => {
        await openGuestMeetRoom(page)
        await page.locator('#participant-name').fill('E2E Guest')
        await expect(page.locator('#participant-name')).toHaveValue('E2E Guest')
        await expect(page.locator('#toggle-preview-video-button')).toBeEnabled()
        await expect(page.locator('#toggle-preview-audio-button')).toBeEnabled()
    })
})
