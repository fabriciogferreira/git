import { type Page, type Route, expect } from '@playwright/test'
import { loginAsDoctor } from './doctor'

/** Ended consultation with PENDING signature (seed scripts/seed-pending-prescription-signature.sh). */
export function signatureRealtimeConsultationId(): string {
    const id = process.env.E2E_TV189_CONSULTATION_ID
    if (!id) {
        throw new Error(
            'E2E_TV189_CONSULTATION_ID is required (seed scripts/seed-pending-prescription-signature.sh)'
        )
    }
    return id
}

export function signatureRealtimePrescriptionId(): string {
    const id = process.env.E2E_TV189_PRESCRIPTION_ID
    if (!id) {
        throw new Error(
            'E2E_TV189_PRESCRIPTION_ID is required (seed scripts/seed-pending-prescription-signature.sh)'
        )
    }
    return id
}

export const SIGNATURE_PROVIDER_SHORT_LINK =
    'https://example.com/e2e-tv-189-sign'

type SignatureFixture = {
    id: string
    prescription_id: string
    status: 'PENDING' | 'SENT' | 'SIGNED' | 'CANCELLED' | 'FAILED' | 'EXPIRED'
    updated_at: string
    signed_at?: string | null
    signed_document_url?: string | null
}

function isCurrentSignatureUrl(url: string, prescriptionId: string): boolean {
    return url.includes(`/prescriptions/${prescriptionId}/signatures/current`)
}

function isStoreSignatureUrl(url: string, prescriptionId: string): boolean {
    return (
        url.includes(`/prescriptions/${prescriptionId}/signatures`) &&
        !url.includes('/signatures/current')
    )
}

/**
 * Mock store + current signature so Assinar can finish without Autentique.
 * Call `flipToSigned()` after the waiting UI is asserted to drive the success toast
 * via the observe/poll path (same notifier as the websocket handler).
 */
export async function mockPrescriptionSignatureRealtimeFlow(
    page: Page,
    prescriptionId: string
) {
    const signatureId = crypto.randomUUID()
    let status: SignatureFixture['status'] = 'PENDING'
    let signedAt: string | null = null
    let updatedAt = new Date().toISOString()
    let started = false

    function currentSignature(): SignatureFixture {
        return {
            id: signatureId,
            prescription_id: prescriptionId,
            status,
            updated_at: updatedAt,
            signed_at: signedAt,
            signed_document_url:
                status === 'SIGNED'
                    ? 'https://example.com/e2e-tv-189-signed.pdf'
                    : null,
        }
    }

    await page.route(
        url => isCurrentSignatureUrl(url.href, prescriptionId),
        async (route: Route) => {
            if (!started) {
                await route.continue()
                return
            }

            await route.fulfill({
                status: 200,
                contentType: 'application/json',
                body: JSON.stringify({ signature: currentSignature() }),
            })
        }
    )

    await page.route(
        url => isStoreSignatureUrl(url.href, prescriptionId),
        async (route: Route) => {
            if (route.request().method() !== 'POST') {
                await route.continue()
                return
            }

            started = true
            status = 'SENT'
            updatedAt = new Date().toISOString()
            await route.fulfill({
                status: 200,
                contentType: 'application/json',
                body: JSON.stringify({
                    message: 'Assinatura iniciada.',
                    signature: currentSignature(),
                    signing: {
                        short_link: SIGNATURE_PROVIDER_SHORT_LINK,
                        provider_document_id: crypto.randomUUID(),
                        provider_signer_id: 'e2e-signer',
                    },
                }),
            })
        }
    )

    return {
        signatureId,
        flipToSigned() {
            status = 'SIGNED'
            signedAt = new Date().toISOString()
            updatedAt = signedAt
        },
    }
}

export async function openPendingSignatureConsultation(
    page: Page,
    consultationId: string
) {
    await loginAsDoctor(page)
    await page.goto(`/dashboard/consultations/view/${consultationId}`)
    await expect(
        page.getByText(/Exame ocular|Dados do paciente|Paciente/i).first()
    ).toBeVisible({ timeout: 30_000 })
}

export function prescriptionSignButton(page: Page, prescriptionId: string) {
    return page.locator(
        `[data-test="view-consultation-prescription-sign-${prescriptionId}"]`
    )
}

export function signatureWaitingStatus(page: Page) {
    return page.getByRole('status').filter({
        hasText: /aguardamos a confirmação|Enviando solicitação/i,
    })
}

export async function closeSignatureDialog(page: Page) {
    const close = page.locator('[data-slot="dialog-close"]')
    if (await close.isVisible().catch(() => false)) {
        await close.click()
    } else {
        await page.keyboard.press('Escape')
    }
    await expect(page.getByRole('dialog')).toHaveCount(0, { timeout: 10_000 })
}
