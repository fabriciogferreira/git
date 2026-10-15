import { test, expect, type Page } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { resolvePageOrigin } from '../helpers/navigation'
import {
    phoneCountrySelect,
    phoneInputRoot,
    phoneNationalInput,
} from '../helpers/phone-input'
import { requireVisible } from '../helpers/feature'
import { expectReadableContrast, setResolvedTheme } from '../helpers/theme'

/**
 * DOP-1215 — optional WhatsApp/phone on the own-profile UserFormModal.
 *
 * Management only shows PhoneInput when editing yourself (`isOwnForm`).
 * Peer profiles must not show the field. Contrast is checked on the label.
 *
 * Uses the seeded `tester@olie.ai` frame. Peer is another user linked on
 * `/users` when the list exposes one.
 */
const PHONE_LABEL = /Telefone|Phone|WhatsApp/i
const EDIT_PROFILE_MODAL = '#modal_edit_profile_data'

async function currentUserId(page: Page): Promise<string> {
    const id = await page.evaluate(() => localStorage.getItem('user_id'))
    expect(id, 'session user_id after login').toBeTruthy()
    return id as string
}

async function openUserDetails(page: Page, userId: string) {
    await page.goto(`${resolvePageOrigin(page)}/users/${userId}/details`)
    await expect(page.locator('.card-body').first()).toBeVisible({ timeout: 30_000 })
}

async function openEditModal(page: Page) {
    const editBtn = page.locator('.card-body button').filter({ has: page.locator('i.fa-pen') }).first()
    await requireVisible(page, 'DOP-1215 edit profile', editBtn, 20_000)
    await editBtn.click()

    const modal = page.locator(EDIT_PROFILE_MODAL)
    await requireVisible(page, 'DOP-1215 UserFormModal', modal, 15_000)
    return modal
}

/** First user on `/users` that is not the signed-in account. */
async function findPeerUserId(page: Page, ownId: string): Promise<string | null> {
    await page.goto(`${resolvePageOrigin(page)}/users`)
    const link = page.locator(`a[href*="/users/"][href$="/details"]`).filter({
        hasNot: page.locator(`[href*="${ownId}"]`),
    }).first()

    if ((await link.count()) === 0) {
        return null
    }

    const href = await link.getAttribute('href')
    const match = href?.match(/\/users\/([^/]+)\/details/)
    return match?.[1] ?? null
}

test.describe('DOP-1215 WhatsApp signup (management profile)', () => {
    test.describe.configure({ timeout: 120_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
    })

    test('own profile edit shows optional PhoneInput', async ({ page }) => {
        const ownId = await currentUserId(page)
        await openUserDetails(page, ownId)
        const modal = await openEditModal(page)

        const label = modal.getByText(PHONE_LABEL).first()
        await requireVisible(page, 'DOP-1215 phone label', label, 10_000)
        await expect(label).toBeVisible()

        const root = phoneInputRoot(modal)
        await expect(root).toBeVisible()
        await expect(phoneCountrySelect(modal)).toBeVisible()
        await expect(phoneNationalInput(modal)).toBeVisible()

        // Optional: no required marker next to the phone label row.
        const labelRow = modal.locator('div.mb-7').filter({ hasText: PHONE_LABEL }).first()
        await expect(labelRow.locator('.required, .text-danger, span:has-text("*")')).toHaveCount(0)
    })

    test('peer profile edit hides the phone field', async ({ page }) => {
        const ownId = await currentUserId(page)
        const peerId = await findPeerUserId(page, ownId)
        test.skip(!peerId, 'DOP-1215: no peer user on /users for this frame')

        await openUserDetails(page, peerId!)
        const modal = await openEditModal(page)

        await expect(modal.getByText(PHONE_LABEL)).toHaveCount(0)
        await expect(phoneInputRoot(modal)).toHaveCount(0)
    })

    test('phone label keeps readable contrast in light and dark', async ({ page }) => {
        const ownId = await currentUserId(page)
        await openUserDetails(page, ownId)
        const modal = await openEditModal(page)
        const label = modal.getByText(PHONE_LABEL).first()
        await expect(label).toBeVisible({ timeout: 10_000 })

        for (const theme of ['light', 'dark'] as const) {
            await setResolvedTheme(page, theme)
            await expect(label).toBeVisible()
            await expectReadableContrast(label, `DOP-1215 phone label (${theme})`)
        }
    })
})
