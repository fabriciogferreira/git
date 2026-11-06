import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from './helpers/auth'
import { loginAsClinicAdmin } from './helpers/clinic'
import {
    openClinicSupportChat,
    openSuperSupportInbox,
    sendSupportChatMessage,
    supportChatIsolationMarker,
} from './helpers/support-chat'

/**
 * TV-16 — clinic support chat: create-on-first-message, super shared inbox reply,
 * soft isolation (clinic never sees another clinic's marker), mark-read on open.
 *
 * Seed: `scripts/seed-support-chat-reset.sh` (wired in run.sh) clears the
 * clinic-admin chat and creates an isolation marker on another clinic.
 */
test.describe('TV-16 clinic support chat', () => {
    test.describe.configure({ mode: 'serial', timeout: 180_000 })

    const clinicMessage = `E2E clinic help ${Date.now()}`
    const superReply = `E2E super reply ${Date.now()}`
    let isolationMarker: string

    test.beforeAll(() => {
        isolationMarker = supportChatIsolationMarker()
    })

    test('clinic opens empty support chat and creates it on first message', async ({
        page,
    }) => {
        await loginAsClinicAdmin(page)
        await openClinicSupportChat(page)

        await expect(page.locator('#support-chat-empty')).toBeVisible({
            timeout: 20_000,
        })
        await expect(page.locator('#support-chat-inbox')).toHaveCount(0)
        await expect(page.getByText(isolationMarker)).toHaveCount(0)

        await sendSupportChatMessage(page, clinicMessage)

        await expect(page.locator('#support-chat-thread')).toBeVisible({
            timeout: 20_000,
        })
        await expect(
            page.locator('#support-chat-messages').getByText(clinicMessage)
        ).toBeVisible({ timeout: 20_000 })
        await expect(page.getByText(isolationMarker)).toHaveCount(0)
    })

    test('super sees the clinic chat in the inbox and can reply', async ({
        page,
    }) => {
        await loginAsE2EUser(page)
        await openSuperSupportInbox(page)

        await page.locator('#support-chat-filter-all').click()
        const inboxItem = page.locator(
            '#support-chat-inbox-sidebar button[id^="support-chat-inbox-item-"]'
        ).filter({ hasText: /Clínica Tele\.Visão|Tele\.Visão/i })
        await expect(inboxItem.first()).toBeVisible({ timeout: 30_000 })
        await expect(inboxItem.first()).toContainText(clinicMessage)

        await inboxItem.first().click()

        await expect(page.locator('#support-chat-thread')).toBeVisible({
            timeout: 20_000,
        })
        await expect(
            page.locator('#support-chat-messages').getByText(clinicMessage)
        ).toBeVisible()

        await sendSupportChatMessage(page, superReply)
        await expect(
            page.locator('#support-chat-messages').getByText(superReply)
        ).toBeVisible({ timeout: 20_000 })

        await expect(page.locator('#support-chat-resolve')).toBeVisible()
    })

    test('clinic sees the super reply and does not see the isolation marker', async ({
        page,
    }) => {
        await loginAsClinicAdmin(page)
        await openClinicSupportChat(page)

        await expect(page.locator('#support-chat-thread')).toBeVisible({
            timeout: 20_000,
        })
        await expect(
            page.locator('#support-chat-messages').getByText(clinicMessage)
        ).toBeVisible({ timeout: 20_000 })
        await expect(
            page.locator('#support-chat-messages').getByText(superReply)
        ).toBeVisible({ timeout: 20_000 })
        await expect(page.getByText(isolationMarker)).toHaveCount(0)
        await expect(page.locator('#support-chat-inbox')).toHaveCount(0)
    })

    test('opening the thread clears the clinic unread badge after a super reply', async ({
        browser,
    }) => {
        const superContext = await browser.newContext()
        const clinicContext = await browser.newContext()
        const superPage = await superContext.newPage()
        const clinicPage = await clinicContext.newPage()

        try {
            await loginAsE2EUser(superPage)
            await openSuperSupportInbox(superPage)
            await superPage.locator('#support-chat-filter-all').click()
            const inboxItem = superPage
                .locator(
                    '#support-chat-inbox-sidebar button[id^="support-chat-inbox-item-"]'
                )
                .filter({ hasText: /Clínica Tele\.Visão|Tele\.Visão/i })
            await expect(inboxItem.first()).toBeVisible({ timeout: 30_000 })
            await inboxItem.first().click()
            await expect(superPage.locator('#support-chat-thread')).toBeVisible({
                timeout: 20_000,
            })

            const unreadProbe = `E2E unread probe ${Date.now()}`
            await sendSupportChatMessage(superPage, unreadProbe)

            await loginAsClinicAdmin(clinicPage)
            await clinicPage.goto('/dashboard')
            await expect(clinicPage.locator('#support-chat-nav-badge')).toBeVisible({
                timeout: 30_000,
            })

            await openClinicSupportChat(clinicPage)
            await expect(
                clinicPage.locator('#support-chat-messages').getByText(unreadProbe)
            ).toBeVisible({
                timeout: 20_000,
            })

            await expect(clinicPage.locator('#support-chat-nav-badge')).toHaveCount(0, {
                timeout: 30_000,
            })
        } finally {
            await superContext.close()
            await clinicContext.close()
        }
    })
})
