import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import {
    expectCallingCodeShown,
    expectPhoneCountryBorder,
    openBillingDataPhoneInput,
    openContactCreatePhoneInput,
    openCustomerCreatePhoneInput,
    phoneCountrySelect,
    phoneInputRoot,
    phoneNationalInput,
    PHONE_INPUT_COMPACT_MAX_PX,
    setPhoneInputWidth,
} from '../helpers/phone-input'

/**
 * OS-557 — shared PhoneInput after country border + compact (flag-only) layout.
 *
 * Contact create is the stable probe (always mounted via InternalContainer).
 * Customer create covers the same widget with `form-control-solid`.
 * Billing data is the ticket screenshot; skipped when the user cannot open it.
 *
 * WhatsApp `PhoneTargetField` still types into `input[type=tel]` in DOP-1158;
 * this file does not duplicate that integration fixture.
 *
 * Uses the seeded `tester@olie.ai` frame (same as other baselines). Isolated
 * signup is currently blocked by RecaptchaValidate on this stack.
 */
test.describe('OS-557 phone input', () => {
    test.describe.configure({ timeout: 120_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
    })

    test('contact create: border, DDI when wide, tel mask, country overlay', async ({
        page,
    }) => {
        const modal = await openContactCreatePhoneInput(page)
        const root = phoneInputRoot(modal)
        const country = phoneCountrySelect(modal)
        const national = phoneNationalInput(modal)

        await expect(country).toBeVisible()
        await expect(root).not.toHaveClass(/phone-input--compact/)
        await expectCallingCodeShown(modal, true)
        await expect(country.locator('.fa-chevron-down')).toBeVisible()
        await expectPhoneCountryBorder(country)
        await expect(national).toBeVisible()

        await national.click()
        await national.pressSequentially('11987654321', { delay: 20 })
        await expect(national).toHaveValue(/\(11\)\s*98765-4321/)

        await country.click()
        const overlay = page.locator('.phone-input-country-overlay').first()
        await expect(overlay).toBeVisible({ timeout: 10_000 })
        await expect(overlay.getByPlaceholder(/Buscar país|Search country/i)).toBeVisible()
    })

    test('contact create: compact width hides DDI and keeps flag + tel', async ({
        page,
    }) => {
        const modal = await openContactCreatePhoneInput(page)
        const root = phoneInputRoot(modal)
        const country = phoneCountrySelect(modal)
        const national = phoneNationalInput(modal)
        const flag = root.locator('.phone-input__flag')

        await setPhoneInputWidth(root, PHONE_INPUT_COMPACT_MAX_PX - 40)
        await expect(root).toHaveClass(/phone-input--compact/, { timeout: 5_000 })
        await expectCallingCodeShown(modal, false)
        await expect(country.locator('.fa-chevron-down')).toBeHidden()
        await expect(flag).toBeVisible()
        await expect(national).toBeVisible()
        await expectPhoneCountryBorder(country)

        await setPhoneInputWidth(root, PHONE_INPUT_COMPACT_MAX_PX + 80)
        await expect(root).not.toHaveClass(/phone-input--compact/, { timeout: 5_000 })
        await expectCallingCodeShown(modal, true)
        await expect(country.locator('.fa-chevron-down')).toBeVisible()
    })

    test('customer create: solid PhoneInput still has country border and DDI', async ({
        page,
    }) => {
        const modal = await openCustomerCreatePhoneInput(page)
        const country = phoneCountrySelect(modal)

        await expect(country).toHaveClass(/phone-input__country--solid/)
        await expectCallingCodeShown(modal, true)
        await expectPhoneCountryBorder(country)
        await expect(phoneNationalInput(modal)).toBeVisible()
    })

    test('billing data: PhoneInput is present with a country border', async ({
        page,
    }) => {
        const root = await openBillingDataPhoneInput(page)
        const country = phoneCountrySelect(root)
        const national = phoneNationalInput(root)

        await expect(country).toBeVisible()
        await expect(national).toBeVisible()
        await expectPhoneCountryBorder(country)
        await expect(country.locator('.phone-input__flag')).toBeVisible()
    })
})
