import { test, expect } from '@playwright/test'
import { checkoutConsultationId, loginAsDoctor } from './helpers/doctor'
import { expectReadableContrast, setResolvedTheme } from './helpers/theme'

/**
 * TV-205 — unify nova receita / post-consultation checkout.
 * Requires an ended consultation for doctor1 (see helpers/doctor.ts).
 */
test.describe('TV-205 post-consultation checkout', () => {
    test.describe.configure({ timeout: 120_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsDoctor(page)
    })

    test('shows unified checkout with prescription form and actions', async ({
        page,
    }) => {
        const consultationId = checkoutConsultationId()
        await page.goto(
            `/dashboard/consultations/${consultationId}/post-consultation`
        )

        await expect(
            page.getByText(/Checkout da receita|Prepare a receita/i).first()
        ).toBeVisible({ timeout: 30_000 })

        await expect(
            page.getByRole('heading', { name: /Receita da consulta|Nova receita/i })
        ).toBeVisible({ timeout: 20_000 })

        await expect(
            page.locator('#prescription-checkout-edit-consultation-button')
        ).toBeVisible()
        await expect(page.locator('#prescription-form-submit-button')).toBeVisible()
        await expect(page.locator('#checkout-conclude-button')).toBeVisible()

        await expect(
            page.getByRole('heading', { name: /Visão de longe/i })
        ).toBeVisible()
        await expect(
            page.getByRole('heading', { name: /Visão de perto/i })
        ).toBeVisible()
        await expect(
            page.getByRole('heading', { name: /^Prévia da receita$/i })
        ).toBeVisible()
        await expect(
            page.locator('[data-prescription-document]')
        ).toBeVisible()
    })

    test('edit consultation from checkout returns with returnTo=checkout', async ({
        page,
    }) => {
        const consultationId = checkoutConsultationId()
        await page.goto(
            `/dashboard/consultations/${consultationId}/post-consultation`
        )

        await expect(
            page.locator('#prescription-checkout-edit-consultation-button')
        ).toBeVisible({ timeout: 30_000 })
        await page.locator('#prescription-checkout-edit-consultation-button').click()

        await expect(page).toHaveURL(
            new RegExp(
                `/dashboard/consultations/edit/${consultationId}\\?returnTo=checkout`
            ),
            { timeout: 20_000 }
        )
    })

    for (const theme of ['light', 'dark'] as const) {
        test(`checkout chrome contrast is readable in ${theme} theme`, async ({
            page,
        }) => {
            const consultationId = checkoutConsultationId()
            await page.goto(
                `/dashboard/consultations/${consultationId}/post-consultation`
            )

            await expect(
                page.getByText(/Checkout da receita/i).first()
            ).toBeVisible({ timeout: 30_000 })

            await setResolvedTheme(page, theme)

            await expectReadableContrast(
                page.getByText(/Checkout da receita/i).first(),
                `${theme} checkout eyebrow`
            )
            await expectReadableContrast(
                page.getByRole('heading', {
                    name: /Prepare a receita antes de concluir/i,
                }),
                `${theme} checkout title`
            )
            await expectReadableContrast(
                page.getByText(/Confira os dados e emita a receita/i).first(),
                `${theme} checkout description`
            )
            await expectReadableContrast(
                page.getByRole('heading', { name: /Visão de longe/i }),
                `${theme} vision section`
            )
            await expectReadableContrast(
                page.getByRole('heading', { name: /^Prévia da receita$/i }),
                `${theme} preview label`
            )

            // Paper preview is intentionally light-themed (document mock); assert
            // it stays high-contrast on white regardless of app theme.
            const preview = page.locator('[data-prescription-document]')
            await expect(preview).toBeVisible()
            await expectReadableContrast(
                preview.getByText(/Receita oftalmológica/i),
                `${theme} prescription document title`
            )
        })
    }
})
