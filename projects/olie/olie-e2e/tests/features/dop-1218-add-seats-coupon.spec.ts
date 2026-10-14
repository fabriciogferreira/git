import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { expectReadableContrast, setResolvedTheme } from '../helpers/theme'
import {
    DOP1218_COUPON_CODE,
    bumpFirstSeatQuantity,
    couponAppliedLine,
    couponCodeField,
    ensureDevframeUpgradeCouponFixture,
    openAddSeatsModal,
    upgradeModalRoot,
} from '../helpers/upgrade-coupon'

/**
 * DOP-1218 — subscription coupon with `applies_to_upgrades` on the add-seats modal.
 *
 * When the attached coupon opts in, preview returns `subscription_coupon_code`:
 * the typed-coupon field is hidden and the summary shows "Cupom {code} aplicado"
 * with the pro-rata discount. Totals come from the API preview.
 *
 * Uses the shared `devframe` seed (tester@olie.ai). Fixture seeds an active
 * subscription + permanent coupon when Docker can reach `olie-api-main`.
 */
test.describe('DOP-1218 add seats coupon', () => {
    test.describe.configure({ timeout: 120_000 })

    test.beforeAll(() => {
        ensureDevframeUpgradeCouponFixture()
    })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
    })

    test('hides coupon field and shows Cupom aplicado from the attached subscription coupon', async ({
        page,
    }) => {
        await openAddSeatsModal(page)
        await bumpFirstSeatQuantity(page)

        const applied = couponAppliedLine(page)
        await expect(applied).toBeVisible({ timeout: 20_000 })
        await expect(applied).toContainText(DOP1218_COUPON_CODE)

        await expect(couponCodeField(page)).toHaveCount(0)

        const total = upgradeModalRoot(page).getByText(/Total a pagar agora|Total due now/i)
        await expect(total).toBeVisible()
    })

    test('coupon applied line keeps readable contrast in light and dark', async ({ page }) => {
        await openAddSeatsModal(page)
        await bumpFirstSeatQuantity(page)

        const applied = couponAppliedLine(page)
        await expect(applied).toBeVisible({ timeout: 20_000 })

        for (const theme of ['light', 'dark'] as const) {
            await setResolvedTheme(page, theme)
            await expect(applied).toBeVisible()
            await expectReadableContrast(applied, `DOP-1218 coupon line (${theme})`)
            await expectReadableContrast(
                applied.locator('.upgrade-summary-line-amount'),
                `DOP-1218 coupon discount amount (${theme})`
            )
        }
    })
})
