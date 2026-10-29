import { test, expect } from '@playwright/test'
import { checkoutConsultationId, loginAsDoctor } from './helpers/doctor'
import { loginAsClinicAdmin } from './helpers/clinic'
import { openCheckout } from './helpers/checkout'
import { expectReadableContrast, setResolvedTheme } from './helpers/theme'

/**
 * TV-203 — after the consultation ends, only the assigned doctor may create a
 * new prescription; clinic staff must not.
 *
 * Seed: `scripts/seed-ended-consultation.sh` (wired in run.sh) sets
 * E2E_CHECKOUT_CONSULTATION_ID on the clinic shared with clinic-admin@clinic.com.
 */
test.describe('TV-203 prescription creation permissions', () => {
    test.describe.configure({ timeout: 120_000 })

    let consultationId: string

    test.beforeAll(() => {
        consultationId = checkoutConsultationId()
    })

    test('doctor sees Nova receita on the ended consultation view', async ({
        page,
    }) => {
        await loginAsDoctor(page)
        await page.goto(`/dashboard/consultations/view/${consultationId}`)
        await expect(
            page.getByText(/Exame ocular|Dados do paciente|Paciente/i).first()
        ).toBeVisible({ timeout: 30_000 })

        await expect(
            page.locator(`#view-consultation-prescription-button-${consultationId}`)
        ).toBeVisible({ timeout: 20_000 })
        await expect(page.getByRole('link', { name: /^Nova receita$/i })).toBeVisible()
    })

    test('clinic admin does not see Nova receita on the ended consultation view', async ({
        page,
    }) => {
        await loginAsClinicAdmin(page)
        await page.goto(`/dashboard/consultations/view/${consultationId}`)
        await expect(
            page.getByText(/Exame ocular|Dados do paciente|Paciente/i).first()
        ).toBeVisible({ timeout: 30_000 })

        await expect(
            page.locator(`#view-consultation-prescription-button-${consultationId}`)
        ).toHaveCount(0)
        await expect(page.getByRole('link', { name: /^Nova receita$/i })).toHaveCount(0)
        await expect(
            page.locator(
                `#view-consultation-prescription-locked-button-${consultationId}`
            )
        ).toHaveCount(0)
    })

    test('clinic admin checkout has no create-prescription controls', async ({
        page,
    }) => {
        await loginAsClinicAdmin(page)
        await openCheckout(page, consultationId)

        await expect(page.locator('#prescription-form-submit-button')).toHaveCount(0)
        await expect(page.locator('#checkout-new-prescription-button')).toHaveCount(0)
        await expect(page.getByRole('button', { name: /^Nova receita$/i })).toHaveCount(
            0
        )
        await expect(page.locator('#checkout-conclude-button')).toBeVisible()
    })

    test('clinic admin direct prescription route shows unauthorized state', async ({
        page,
    }) => {
        await loginAsClinicAdmin(page)
        await page.goto(`/dashboard/consultations/${consultationId}/prescription`)

        await expect(
            page.getByText(
                /Somente o médico responsável pela consulta pode criar receitas/i
            )
        ).toBeVisible({ timeout: 30_000 })
        await expect(
            page.locator('#prescription-unauthorized-back-button')
        ).toBeVisible()
        await expect(page.locator('#prescription-form-submit-button')).toHaveCount(0)
    })

    for (const theme of ['light', 'dark'] as const) {
        test(`unauthorized prescription message contrast is readable in ${theme} theme`, async ({
            page,
        }) => {
            await loginAsClinicAdmin(page)
            await page.goto(`/dashboard/consultations/${consultationId}/prescription`)

            const message = page.getByText(
                /Somente o médico responsável pela consulta pode criar receitas/i
            )
            await expect(message).toBeVisible({ timeout: 30_000 })
            await setResolvedTheme(page, theme)

            await expectReadableContrast(
                page.getByRole('heading', { name: /^Nova receita$/i }),
                `${theme} unauthorized heading`
            )
            await expectReadableContrast(
                message,
                `${theme} unauthorized prescription copy`
            )
        })
    }
})
