import { type Page, expect } from '@playwright/test'
import { loginAsDoctor } from './doctor'

/** Ended consultation with a SIGNED prescription (seed scripts/seed-signed-prescription-autentique.sh). */
export function autentiqueLinkConsultationId(): string {
    const id = process.env.E2E_AUTENTIQUE_LINK_CONSULTATION_ID
    if (!id) {
        throw new Error(
            'E2E_AUTENTIQUE_LINK_CONSULTATION_ID is required (seed scripts/seed-signed-prescription-autentique.sh)'
        )
    }
    return id
}

export function autentiqueLinkPrescriptionId(): string {
    const id = process.env.E2E_AUTENTIQUE_LINK_PRESCRIPTION_ID
    if (!id) {
        throw new Error(
            'E2E_AUTENTIQUE_LINK_PRESCRIPTION_ID is required (seed scripts/seed-signed-prescription-autentique.sh)'
        )
    }
    return id
}

/** Stub Autentique provider URL used when the live DB has no signed_document_url column yet. */
export const AUTENTIQUE_SIGNED_DOCUMENT_URL =
    'https://painel.autentique.com.br/documentos/e2e-tv-190/assinado.pdf'

export function autentiqueProviderLink(page: Page, prescriptionId: string) {
    return page.locator(
        `#view-consultation-prescription-provider-link-${prescriptionId}`
    )
}

/**
 * Inject signed_document_url into signatures/current so the front can show
 * "Ver no Autentique" even when the column is missing from the live schema.
 */
export async function mockSignedDocumentUrlOnCurrentSignature(
    page: Page,
    prescriptionId: string,
    url: string = AUTENTIQUE_SIGNED_DOCUMENT_URL
) {
    await page.route(
        new RegExp(`/prescriptions/${prescriptionId}/signatures/current\\b`),
        async route => {
            const response = await route.fetch()
            const body = (await response.json()) as {
                signature?: Record<string, unknown> | null
            }
            if (body.signature && typeof body.signature === 'object') {
                body.signature = {
                    ...body.signature,
                    signed_document_url: url,
                    status: body.signature.status ?? 'SIGNED',
                }
            } else {
                body.signature = {
                    id: prescriptionId,
                    prescription_id: prescriptionId,
                    status: 'SIGNED',
                    signed_document_url: url,
                }
            }
            await route.fulfill({
                status: response.status(),
                contentType: 'application/json',
                body: JSON.stringify(body),
            })
        }
    )
}

export async function openSignedPrescriptionConsultation(
    page: Page,
    consultationId: string
) {
    await loginAsDoctor(page)
    await page.goto(`/dashboard/consultations/view/${consultationId}`)
    await expect(
        page.getByText(/Exame ocular|Dados do paciente|Paciente/i).first()
    ).toBeVisible({ timeout: 30_000 })
}
