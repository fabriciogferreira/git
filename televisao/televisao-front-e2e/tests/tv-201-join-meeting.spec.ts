import { test, expect } from '@playwright/test'
import {
    joinMeetingButton,
    joinMeetingInsideConsultationId,
    joinMeetingOutsideConsultationId,
    openConsultationView,
} from './helpers/join-meeting'
import { expectReadableContrast, setResolvedTheme } from './helpers/theme'

/**
 * TV-201 — join call at the five-minute boundary.
 * Seed: `scripts/seed-join-meeting-window.sh` (wired in run.sh).
 */
test.describe('TV-201 join meeting window', () => {
    test.describe.configure({ timeout: 120_000 })

    test('shows join button and issues meeting-token at the five-minute boundary', async ({
        page,
    }) => {
        const consultationId = joinMeetingInsideConsultationId()
        await openConsultationView(page, consultationId)

        const button = joinMeetingButton(page, consultationId)
        await expect(button).toBeVisible({ timeout: 20_000 })
        await expect(button).toContainText(/Chamada de vídeo disponível/i)

        const tokenResponsePromise = page.waitForResponse(
            r =>
                new RegExp(`/consultations/${consultationId}/meeting-token\\b`).test(
                    r.url()
                ) &&
                r.request().method() === 'POST',
            { timeout: 30_000 }
        )

        await button.click()
        const tokenResponse = await tokenResponsePromise
        expect(
            tokenResponse.ok(),
            `meeting-token status ${tokenResponse.status()}`
        ).toBeTruthy()

        await expect(page).toHaveURL(/\/meet\//, { timeout: 20_000 })
        expect(page.url()).toMatch(/token=/)
        expect(page.url()).toContain(`consultationId=${consultationId}`)
    })

    test('hides join button before the five-minute window opens', async ({ page }) => {
        const consultationId = joinMeetingOutsideConsultationId()
        await openConsultationView(page, consultationId)

        await expect(joinMeetingButton(page, consultationId)).toHaveCount(0)
        await expect(page.getByText(/Chamada de vídeo disponível/i)).toHaveCount(0)
    })

    for (const theme of ['light', 'dark'] as const) {
        test(`join screen contrast is readable in ${theme} theme`, async ({ page }) => {
            const consultationId = joinMeetingInsideConsultationId()
            await openConsultationView(page, consultationId)

            const button = joinMeetingButton(page, consultationId)
            await expect(button).toBeVisible({ timeout: 20_000 })
            await setResolvedTheme(page, theme)

            // Body/section copy on the view (AA normal text 4.5:1).
            await expectReadableContrast(
                page.getByRole('heading', { name: /Exame ocular/i }),
                `${theme} exame ocular heading`
            )

            // Primary CTA uses design-system tokens; WCAG UI component floor is 3:1.
            await expectReadableContrast(
                button.getByText(/Chamada de vídeo disponível/i),
                `${theme} join meeting CTA`,
                3
            )
        })
    }
})
