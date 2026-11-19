import { test, expect } from '@playwright/test'
import { loginAsClinicAdmin } from './helpers/clinic'
import {
    cancelPrescriptionConsultationId,
    cancelPrescriptionId,
    openCancelPrescriptionConsultation,
} from './helpers/cancel-prescription'
import { expectReadableContrast, setResolvedTheme } from './helpers/theme'

/**
 * TV-255 — doctor cancels a prescription with justification; clinic cannot.
 * Seed: `scripts/seed-cancel-prescription.sh` (wired in run.sh).
 */
test.describe('TV-255 cancel prescription', () => {
    test.describe.configure({ timeout: 120_000, mode: 'serial' })

    test('clinic admin does not see Cancelar receita on an active prescription', async ({
        page,
    }) => {
        const consultationId = cancelPrescriptionConsultationId()
        const prescriptionId = cancelPrescriptionId()

        await loginAsClinicAdmin(page)
        await page.goto(`/dashboard/consultations/view/${consultationId}`)
        await expect(
            page.getByText(/Exame ocular|Dados do paciente|Paciente|Receitas/i).first()
        ).toBeVisible({ timeout: 30_000 })

        await expect(
            page.locator(`#view-consultation-prescription-cancel-${prescriptionId}`)
        ).toHaveCount(0)
        await expect(
            page.getByRole('button', { name: /^Cancelar receita$/i })
        ).toHaveCount(0)
    })

    test('doctor cancels via dialog and sees Cancelada + justificativa', async ({
        page,
    }) => {
        const consultationId = cancelPrescriptionConsultationId()
        const prescriptionId = cancelPrescriptionId()
        const justification =
            'E2E TV-255 justificativa de cancelamento com texto suficiente para scroll.'

        await openCancelPrescriptionConsultation(page, consultationId)

        const cancelTrigger = page.locator(
            `#view-consultation-prescription-cancel-${prescriptionId}`
        )
        await expect(cancelTrigger).toBeVisible({ timeout: 20_000 })
        await cancelTrigger.click()

        await expect(
            page.getByRole('heading', { name: /^Cancelar receita$/i })
        ).toBeVisible()
        await page
            .getByPlaceholder(/Descreva o motivo do cancelamento/i)
            .fill(justification)
        await page
            .locator(`#button-confirm-cancel-prescription-${prescriptionId}`)
            .click()

        await expect(page.getByText(/^Cancelada$/i).first()).toBeVisible({
            timeout: 20_000,
        })
        await expect(page.getByText(/^Justificativa$/i).first()).toBeVisible()
        await expect(page.getByText(justification)).toBeVisible()
        await expect(cancelTrigger).toHaveCount(0)
    })

    for (const theme of ['light', 'dark'] as const) {
        test(`cancelled badge and justification contrast readable in ${theme}`, async ({
            page,
        }) => {
            const consultationId = cancelPrescriptionConsultationId()

            await openCancelPrescriptionConsultation(page, consultationId)
            await expect(page.getByText(/^Cancelada$/i).first()).toBeVisible({
                timeout: 20_000,
            })

            await setResolvedTheme(page, theme)
            await expectReadableContrast(
                page.getByText(/^Cancelada$/i).first(),
                `${theme} Cancelada badge`
            )
            await expectReadableContrast(
                page.getByText(/^Justificativa$/i).first(),
                `${theme} Justificativa label`
            )
        })
    }
})
