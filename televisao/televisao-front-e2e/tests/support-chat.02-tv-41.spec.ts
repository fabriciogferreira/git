import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from './helpers/auth'
import { loginAsDoctor } from './helpers/doctor'
import {
    openDoctorSupportChat,
    openSuperSupportInbox,
    sendSupportChatMessage,
    supportChatInboxItemByPreview,
    supportChatIsolationMarker,
} from './helpers/support-chat'

/**
 * TV-41 — doctor support chat: create-on-first-message, super shared inbox reply
 * (doctor_id), soft isolation (doctor never sees another clinic's marker).
 *
 * Seed: `scripts/seed-support-chat-reset.sh` also clears doctor1's morph chat.
 *
 * Filename `02-` keeps this after TV-16 (`01-`) when both run after one seed.
 */
test.describe('TV-41 doctor support chat', () => {
    test.describe.configure({ mode: 'serial', timeout: 180_000 })

    const doctorMessage = `E2E doctor help ${Date.now()}`
    const superReply = `E2E super doctor reply ${Date.now()}`
    let isolationMarker: string

    test.beforeAll(() => {
        isolationMarker = supportChatIsolationMarker()
    })

    test('doctor opens empty support chat and creates it on first message', async ({
        page,
    }) => {
        await loginAsDoctor(page)
        await openDoctorSupportChat(page)

        await expect(page.locator('#support-chat-empty')).toBeVisible({
            timeout: 20_000,
        })
        await expect(
            page.getByText(/problemas da sua conta/i)
        ).toBeVisible()
        await expect(page.getByText(isolationMarker)).toHaveCount(0)

        const supportNav = page.locator('a[href*="support-chat"]').first()
        await expect(supportNav).toBeVisible({ timeout: 15_000 })

        await sendSupportChatMessage(page, doctorMessage)

        await expect(page.locator('#support-chat-thread')).toBeVisible({
            timeout: 20_000,
        })
        await expect(
            page.locator('#support-chat-messages').getByText(doctorMessage)
        ).toBeVisible({ timeout: 20_000 })
        await expect(page.getByText(isolationMarker)).toHaveCount(0)
    })

    test('super sees the doctor chat in the inbox and can reply', async ({
        page,
    }) => {
        await loginAsE2EUser(page)
        await openSuperSupportInbox(page)

        await page.locator('#support-chat-filter-all').click()
        await page.locator('#support-chat-type-filter-doctor').click()
        const inboxItem = supportChatInboxItemByPreview(page, doctorMessage)
        await expect(inboxItem.first()).toBeVisible({ timeout: 30_000 })
        await expect(
            inboxItem.first().locator('[id^="support-chat-inbox-type-"]')
        ).toHaveText(/Médico/i)

        await inboxItem.first().click()

        await expect(page.locator('#support-chat-thread')).toBeVisible({
            timeout: 20_000,
        })
        await expect(page.locator('#support-chat-thread-owner-type')).toHaveText(
            /Médico/i
        )
        await expect(
            page.getByText(/Chamado de suporte — médico/i)
        ).toBeVisible({ timeout: 15_000 })
        await expect(
            page.locator('#support-chat-messages').getByText(doctorMessage)
        ).toBeVisible()

        await sendSupportChatMessage(page, superReply)
        await expect(
            page.locator('#support-chat-messages').getByText(superReply)
        ).toBeVisible({ timeout: 20_000 })

        await expect(page.locator('#support-chat-resolve')).toBeVisible()
    })

    test('doctor sees the super reply and does not see the isolation marker', async ({
        page,
    }) => {
        await loginAsDoctor(page)
        await openDoctorSupportChat(page)

        await expect(page.locator('#support-chat-thread')).toBeVisible({
            timeout: 20_000,
        })
        await expect(
            page.locator('#support-chat-messages').getByText(doctorMessage)
        ).toBeVisible({ timeout: 20_000 })
        await expect(
            page.locator('#support-chat-messages').getByText(superReply)
        ).toBeVisible({ timeout: 20_000 })
        await expect(page.getByText(isolationMarker)).toHaveCount(0)
        await expect(page.locator('#support-chat-inbox')).toHaveCount(0)
    })
})
