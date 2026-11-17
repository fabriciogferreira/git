import { test, expect } from '@playwright/test'
import { expectToast } from './helpers/auth'
import {
    closeSignatureDialog,
    mockPrescriptionSignatureRealtimeFlow,
    openPendingSignatureConsultation,
    prescriptionSignButton,
    signatureRealtimeConsultationId,
    signatureRealtimePrescriptionId,
    signatureWaitingStatus,
} from './helpers/signature-realtime'
import { expectReadableContrast, setResolvedTheme } from './helpers/theme'

/**
 * TV-189 — after sending a prescription to Autentique, the UI shows a waiting
 * state; when confirmation arrives (same notifier as websocket), a success toast
 * appears. Autentique itself is mocked; seed provides PENDING so Assinar is enabled.
 */
test.describe('TV-189 prescription signature realtime waiting UI', () => {
    test.describe.configure({ timeout: 120_000 })

    let consultationId: string
    let prescriptionId: string

    test.beforeAll(() => {
        consultationId = signatureRealtimeConsultationId()
        prescriptionId = signatureRealtimePrescriptionId()
    })

    test('shows waiting state after Assinar and toasts on confirmation', async ({
        page,
    }) => {
        const flow = await mockPrescriptionSignatureRealtimeFlow(
            page,
            prescriptionId
        )
        await openPendingSignatureConsultation(page, consultationId)

        const signButton = prescriptionSignButton(page, prescriptionId)
        await expect(signButton).toBeEnabled({ timeout: 20_000 })

        await Promise.all([
            page.waitForResponse(
                response =>
                    response.request().method() === 'POST' &&
                    response.url().includes(
                        `/prescriptions/${prescriptionId}/signatures`
                    ) &&
                    !response.url().includes('/signatures/current') &&
                    response.ok(),
                { timeout: 30_000 }
            ),
            signButton.click(),
        ])

        await expectToast(
            page,
            /Solicitação enviada\. Aguardando confirmação do provedor\./i
        )
        await expect(page.getByRole('dialog')).toBeVisible({ timeout: 15_000 })
        await expect(
            page.getByText(
                /Conclua a assinatura abaixo\. Avisaremos assim que o provedor confirmar\./i
            )
        ).toBeVisible()

        await closeSignatureDialog(page)
        await expect(page.getByText(/Aguardando assinatura/i)).toBeVisible({
            timeout: 15_000,
        })
        await expect(signatureWaitingStatus(page)).toBeVisible({
            timeout: 15_000,
        })

        flow.flipToSigned()
        await page.evaluate(() => {
            window.dispatchEvent(new Event('focus'))
            document.dispatchEvent(new Event('visibilitychange'))
        })
        await expectToast(page, /Receita assinada com sucesso\./i, 25_000)
    })

    for (const theme of ['light', 'dark'] as const) {
        test(`waiting status contrast is readable in ${theme} theme`, async ({
            page,
        }) => {
            await mockPrescriptionSignatureRealtimeFlow(page, prescriptionId)
            await openPendingSignatureConsultation(page, consultationId)

            const signButton = prescriptionSignButton(page, prescriptionId)
            await expect(signButton).toBeEnabled({ timeout: 20_000 })

            await Promise.all([
                page.waitForResponse(
                    response =>
                        response.request().method() === 'POST' &&
                        response.url().includes(
                            `/prescriptions/${prescriptionId}/signatures`
                        ) &&
                        !response.url().includes('/signatures/current') &&
                        response.ok(),
                    { timeout: 30_000 }
                ),
                signButton.click(),
            ])

            await expect(page.getByRole('dialog')).toBeVisible({
                timeout: 15_000,
            })
            await closeSignatureDialog(page)

            const waiting = signatureWaitingStatus(page)
            await expect(waiting).toBeVisible({ timeout: 15_000 })
            await setResolvedTheme(page, theme)
            await expectReadableContrast(
                waiting,
                `${theme} signature waiting status`
            )
        })
    }
})
