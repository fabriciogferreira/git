import { test, expect } from '@playwright/test'
import { checkoutConsultationId, loginAsDoctor } from './helpers/doctor'
import {
    concludeCheckout,
    createPrescriptionFromCheckout,
    fillCheckoutPrescription,
    openCheckout,
    prescriptionCard,
} from './helpers/checkout'
import { expectReadableContrast, setResolvedTheme } from './helpers/theme'

/**
 * TV-205 — end-to-end checkout after leaving a consultation.
 *
 * Seed: `scripts/seed-ended-consultation.sh` (wired in run.sh) sets
 * E2E_CHECKOUT_CONSULTATION_ID to an ended consultation for doctor1.
 * Landing on /post-consultation is the same destination meet-front uses
 * after the doctor leaves the room.
 */
test.describe('TV-205 checkout flow', () => {
    test.describe.configure({ mode: 'serial', timeout: 180_000 })

    let consultationId: string
    const prescriptionName = `Receita E2E TV-205 ${Date.now()}`

    test.beforeAll(() => {
        consultationId = checkoutConsultationId()
    })

    test('doctor lands on unified checkout after consultation end', async ({
        page,
    }) => {
        await loginAsDoctor(page)
        await openCheckout(page, consultationId)

        await expect(
            page.getByRole('heading', { name: /Receita da consulta|Nova receita/i })
        ).toBeVisible()
        await expect(page.locator('#prescription-form-submit-button')).toBeVisible()
        await expect(
            page.locator('#prescription-checkout-edit-consultation-button')
        ).toBeVisible()
        await expect(page.locator('#checkout-conclude-button')).toBeVisible()
        await expect(
            page.getByRole('heading', { name: /^Prévia da receita$/i })
        ).toBeVisible()
    })

    test('edit consultation from checkout and return with saved note', async ({
        page,
    }) => {
        await loginAsDoctor(page)
        await openCheckout(page, consultationId)

        await page.locator('#prescription-checkout-edit-consultation-button').click()
        await expect(page).toHaveURL(
            new RegExp(
                `/dashboard/consultations/edit/${consultationId}\\?returnTo=checkout`
            ),
            { timeout: 20_000 }
        )

        const note = `Nota checkout TV-205 ${Date.now()}`
        const noteField = page
            .locator('#consultation-data-section')
            .getByRole('textbox', { name: /Observações/i })
        await expect(noteField).toBeVisible({ timeout: 20_000 })
        await noteField.fill(note)

        const saveResponsePromise = page.waitForResponse(
            r =>
                r.url().includes(`/consultations/${consultationId}`) &&
                r.request().method() === 'PUT',
            { timeout: 30_000 }
        )
        await page
            .locator(`#update-consultation-submit-button-${consultationId}`)
            .click()
        const saveResponse = await saveResponsePromise
        expect(
            saveResponse.ok(),
            `PUT /consultations → ${saveResponse.status()} ${await saveResponse
                .text()
                .catch(() => '')}`
        ).toBeTruthy()

        await expect(page).toHaveURL(
            new RegExp(`/dashboard/consultations/${consultationId}/post-consultation`),
            { timeout: 20_000 }
        )
        await expect(
            page.getByText(/Checkout da receita|Prepare a receita/i).first()
        ).toBeVisible()
    })

    test('create prescription on checkout then conclude', async ({ page }) => {
        await loginAsDoctor(page)
        await openCheckout(page, consultationId)

        // Form open when there are no prescriptions yet
        await fillCheckoutPrescription(page, {
            name: prescriptionName,
            sphereOd: -1.25,
            observations: 'Uso contínuo — E2E TV-205',
        })

        // Preview mirrors filled name
        await expect(
            page.locator('[data-prescription-document]').getByText(prescriptionName)
        ).toBeVisible()

        await createPrescriptionFromCheckout(page)

        // After save, form collapses; prescription appears in the list
        await expect(prescriptionCard(page, prescriptionName)).toBeVisible({
            timeout: 20_000,
        })
        await expect(page.locator('#checkout-new-prescription-button')).toBeVisible()
        await expect(page.locator('#checkout-conclude-button')).toHaveText(
            /Concluir checkout/i
        )

        await concludeCheckout(page)
    })

    test('reopening checkout shows saved prescription and allows conclude again', async ({
        page,
    }) => {
        await loginAsDoctor(page)
        await openCheckout(page, consultationId)

        await expect(prescriptionCard(page, prescriptionName)).toBeVisible({
            timeout: 20_000,
        })
        await expect(page.locator('#checkout-new-prescription-button')).toBeVisible()
        await expect(page.locator('#prescription-form-submit-button')).toHaveCount(0)

        await concludeCheckout(page)
    })

    for (const theme of ['light', 'dark'] as const) {
        test(`checkout text contrast holds in ${theme} theme`, async ({ page }) => {
            await loginAsDoctor(page)
            await openCheckout(page, consultationId)
            await setResolvedTheme(page, theme)

            await expectReadableContrast(
                page.getByRole('heading', {
                    name: /Prepare a receita antes de concluir/i,
                }),
                `${theme} title`
            )
            await expectReadableContrast(
                page.getByText(/Confira os dados e emita a receita/i).first(),
                `${theme} description`
            )
        })
    }
})
