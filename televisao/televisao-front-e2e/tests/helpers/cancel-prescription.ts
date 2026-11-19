import { type Page, expect } from '@playwright/test'
import { loginAsDoctor } from './doctor'

/** Ended consultation + active prescription for TV-255 cancel UI. */
export function cancelPrescriptionConsultationId(): string {
    const id = process.env.E2E_CANCEL_PRESCRIPTION_CONSULTATION_ID
    if (!id) {
        throw new Error(
            'E2E_CANCEL_PRESCRIPTION_CONSULTATION_ID is required (seed-cancel-prescription.sh)'
        )
    }
    return id
}

export function cancelPrescriptionId(): string {
    const id = process.env.E2E_CANCEL_PRESCRIPTION_ID
    if (!id) {
        throw new Error(
            'E2E_CANCEL_PRESCRIPTION_ID is required (seed-cancel-prescription.sh)'
        )
    }
    return id
}

export async function openCancelPrescriptionConsultation(
    page: Page,
    consultationId: string
) {
    await loginAsDoctor(page)
    await page.goto(`/dashboard/consultations/view/${consultationId}`)
    await expect(
        page.getByText(/Exame ocular|Dados do paciente|Paciente|Receitas/i).first()
    ).toBeVisible({ timeout: 30_000 })
}
