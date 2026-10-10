import { type Page, expect } from '@playwright/test'

export function e2eMeetRoom() {
    return process.env.E2E_MEET_ROOM || 'e2e-smoke'
}

/** Open a guest meet room without consultation token (join form path). */
export async function openGuestMeetRoom(page: Page, room = e2eMeetRoom()) {
    await page.context().clearPermissions()
    await page.goto(`/meet/${room}`)
    await expect(page.locator('#participant-name')).toBeVisible({ timeout: 45_000 })
    await expect(page.locator('#toggle-preview-video-button')).toBeVisible()
    await expect(page.locator('#toggle-preview-audio-button')).toBeVisible()
}
