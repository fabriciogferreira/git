import { type Page, expect } from '@playwright/test'

/** Unique body marker for a clinic→super support flow (set by seed or test). */
export function supportChatIsolationMarker(): string {
    const marker = process.env.E2E_SUPPORT_CHAT_ISOLATION_MARKER
    if (!marker) {
        throw new Error(
            'E2E_SUPPORT_CHAT_ISOLATION_MARKER is required (scripts/seed-support-chat-reset.sh)'
        )
    }
    return marker
}

export async function openClinicSupportChat(page: Page) {
    await page.goto('/dashboard/support-chat')
    await expect(page.locator('#support-chat-page, #support-chat-empty, #support-chat-thread').first()).toBeVisible({
        timeout: 30_000,
    })
}

export async function openSuperSupportInbox(page: Page) {
    await page.goto('/dashboard/support-chat')
    await expect(page.locator('#support-chat-inbox')).toBeVisible({ timeout: 30_000 })
}

export async function sendSupportChatMessage(page: Page, body: string) {
    const input = page.locator('#support-chat-composer-input')
    await expect(input).toBeVisible({ timeout: 15_000 })
    await input.fill(body)

    await Promise.all([
        page.waitForResponse(
            (r) =>
                /\/support-chats\/messages\b/.test(r.url()) &&
                r.request().method() === 'POST' &&
                r.ok(),
            { timeout: 30_000 }
        ),
        page.locator('#support-chat-composer-send').click(),
    ])
}
