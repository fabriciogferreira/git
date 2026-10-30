import { test, expect } from '@playwright/test'
import {
    AUTENTIQUE_SIGNED_DOCUMENT_URL,
    autentiqueLinkConsultationId,
    autentiqueLinkPrescriptionId,
    autentiqueProviderLink,
    mockSignedDocumentUrlOnCurrentSignature,
    openSignedPrescriptionConsultation,
} from './helpers/autentique-link'
import { expectReadableContrast, setResolvedTheme } from './helpers/theme'

/**
 * TV-190 — clickable Autentique link for a signed prescription.
 * Seed: `scripts/seed-signed-prescription-autentique.sh` (wired in run.sh).
 * Route mock supplies signed_document_url when the DB column is not migrated yet.
 */
test.describe('TV-190 Autentique signed document link', () => {
    test.describe.configure({ timeout: 120_000 })

    test('shows Ver no Autentique linking to the provider URL', async ({
        page,
    }) => {
        const consultationId = autentiqueLinkConsultationId()
        const prescriptionId = autentiqueLinkPrescriptionId()

        await mockSignedDocumentUrlOnCurrentSignature(page, prescriptionId)
        await openSignedPrescriptionConsultation(page, consultationId)

        const link = autentiqueProviderLink(page, prescriptionId)
        await expect(link).toBeVisible({ timeout: 20_000 })
        await expect(link).toContainText(/Ver no Autentique/i)
        await expect(link).toHaveAttribute('href', AUTENTIQUE_SIGNED_DOCUMENT_URL)
        await expect(link).toHaveAttribute('target', '_blank')
        await expect(link).toHaveAttribute('rel', /noopener/)
    })

    for (const theme of ['light', 'dark'] as const) {
        test(`Ver no Autentique contrast is readable in ${theme} theme`, async ({
            page,
        }) => {
            const consultationId = autentiqueLinkConsultationId()
            const prescriptionId = autentiqueLinkPrescriptionId()

            await mockSignedDocumentUrlOnCurrentSignature(page, prescriptionId)
            await openSignedPrescriptionConsultation(page, consultationId)

            const link = autentiqueProviderLink(page, prescriptionId)
            await expect(link).toBeVisible({ timeout: 20_000 })
            await setResolvedTheme(page, theme)
            await expectReadableContrast(
                link,
                `${theme} Ver no Autentique`
            )
        })
    }
})
