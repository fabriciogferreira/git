import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { expectReadableContrast, setResolvedTheme } from '../helpers/theme'
import {
    DOP1179_COUPON_CODE,
    advanceWizardPrimary,
    applyCouponInSeatStep,
    ensureZeroFirstPaymentCouponFixture,
    openHireSubscriptionWizard,
    subscriptionWizardRoot,
    zeroTotalNoCardBanner,
} from '../helpers/zero-first-payment-coupon'

/**
 * DOP-1179 — activate subscription when a coupon zeroes the first charge.
 *
 * Seat step shows total R$ 0,00; payment step hides card methods and shows the
 * "no card required" banner; finalize activates without a gateway call.
 *
 * Uses the shared `devframe` seed (tester@olie.ai). Fixture resets trial +
 * billing data when Docker can reach `olie-api-main` (host/`./run.sh` before
 * the suite — the e2e container cannot docker-exec). Prefer
 * `E2E_AUTH_TOKEN` + `E2E_USER_ID` when local reCAPTCHA rejects the stub.
 *
 * Contrast is checked on the payment banner before finalize so a single seeded
 * trial covers both the flow and light/dark AA.
 */
test.describe('DOP-1179 zero first payment coupon', () => {
    test.describe.configure({ timeout: 180_000 })

    test.beforeAll(() => {
        ensureZeroFirstPaymentCouponFixture('devframe')
    })

    test.beforeEach(async ({ page }) => {
        ensureZeroFirstPaymentCouponFixture('devframe')
        await loginAsE2EUser(page)
    })

    test('hides card methods, activates without a card, and keeps banner contrast', async ({
        page,
    }) => {
        await openHireSubscriptionWizard(page)
        await applyCouponInSeatStep(page, DOP1179_COUPON_CODE)

        // Seats → billing data (seeded) → payment
        await advanceWizardPrimary(page)
        await expect(
            subscriptionWizardRoot(page)
                .getByText(/Dados de cobrança|Billing data|Billing details/i)
                .first()
        ).toBeVisible({ timeout: 15_000 })
        await advanceWizardPrimary(page)

        const banner = zeroTotalNoCardBanner(page)
        await expect(banner).toBeVisible({ timeout: 25_000 })

        // Payment method tiles stay hidden when the coupon covers the 1st charge.
        await expect(subscriptionWizardRoot(page).locator('.pay-method-grid')).toHaveCount(0)

        // Dark first so a light-theme AA miss still records the dark result in the log.
        for (const theme of ['dark', 'light'] as const) {
            await setResolvedTheme(page, theme)
            await expect(banner).toBeVisible()
            await expectReadableContrast(banner, `DOP-1179 zero-total banner (${theme})`)
        }

        const finalize = subscriptionWizardRoot(page)
            .locator('.wizard-footer')
            .getByRole('button', { name: /Finalizar e pagar|Finish and pay|Pay/i })
        await expect(finalize).toBeVisible({ timeout: 10_000 })
        await expect(finalize).toContainText(/R\$\s*0,00|\$\s*0\.00/i)
        await finalize.click()

        await expect(
            page
                .getByText(
                    /assinatura ativa|subscription is active|pagamento confirmado|Payment confirmed/i
                )
                .first()
        ).toBeVisible({ timeout: 30_000 })
    })
})
