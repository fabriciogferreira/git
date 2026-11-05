import { test, expect } from '@playwright/test'
import {
    checkoutConsultationId,
    loginAsDoctor,
    openConsultationId,
} from './helpers/doctor'
import { expectReadableContrast, setResolvedTheme } from './helpers/theme'

/**
 * TV-232 — after the consultation ends, the assigned doctor can create a
 * prescription; the action stays available after reload; it stays locked while
 * ended_at is still null.
 *
 * Seeds (run.sh): E2E_CHECKOUT_CONSULTATION_ID (ended) and
 * E2E_OPEN_CONSULTATION_ID (in progress).
 */
test.describe('TV-232 prescription after consultation end', () => {
    test.describe.configure({ timeout: 120_000 })

    let endedId: string
    let openId: string

    test.beforeAll(() => {
        endedId = checkoutConsultationId()
        openId = openConsultationId()
    })

    test('doctor gets Nova receita on an ended consultation and can open the form', async ({
        page,
    }) => {
        await loginAsDoctor(page)
        await page.goto(`/dashboard/consultations/view/${endedId}`)
        await expect(
            page.getByText(/Exame ocular|Dados do paciente|Paciente/i).first()
        ).toBeVisible({ timeout: 30_000 })

        const createLink = page.locator(
            `[data-test="view-consultation-prescription-link-${endedId}"]`
        )
        await expect(createLink).toBeVisible({ timeout: 20_000 })
        await expect(
            page.locator(
                `#view-consultation-prescription-locked-button-${endedId}`
            )
        ).toHaveCount(0)

        await createLink.click()
        await expect(page).toHaveURL(
            new RegExp(`/dashboard/consultations/${endedId}/prescription`),
            { timeout: 20_000 }
        )
        await expect(page.locator('#prescription-form-submit-button')).toBeVisible({
            timeout: 20_000,
        })
        await expect(page.getByRole('button', { name: /^Criar receita$/i })).toBeVisible()
    })

    test('Nova receita stays available after reloading the ended consultation', async ({
        page,
    }) => {
        await loginAsDoctor(page)
        await page.goto(`/dashboard/consultations/view/${endedId}`)
        await expect(
            page.locator(
                `[data-test="view-consultation-prescription-link-${endedId}"]`
            )
        ).toBeVisible({ timeout: 30_000 })

        await page.reload()
        await expect(
            page.locator(
                `[data-test="view-consultation-prescription-link-${endedId}"]`
            )
        ).toBeVisible({ timeout: 30_000 })
        await expect(
            page.locator(
                `#view-consultation-prescription-locked-button-${endedId}`
            )
        ).toHaveCount(0)
    })

    test('keeps Nova receita locked while the consultation has no ended_at', async ({
        page,
    }) => {
        await loginAsDoctor(page)
        await page.goto(`/dashboard/consultations/view/${openId}`)
        await expect(
            page.getByText(/Ainda não finalizada|Exame ocular|Paciente/i).first()
        ).toBeVisible({ timeout: 30_000 })

        const locked = page.locator(
            `#view-consultation-prescription-locked-button-${openId}`
        )
        await expect(locked).toBeVisible({ timeout: 20_000 })
        await expect(locked).toBeDisabled()
        await expect(
            page.locator(
                `[data-test="view-consultation-prescription-link-${openId}"]`
            )
        ).toHaveCount(0)
        await expect(
            page.getByRole('link', { name: /^Nova receita$/i })
        ).toHaveCount(0)
    })

    for (const theme of ['light', 'dark'] as const) {
        test(`enabled Nova receita contrast is readable in ${theme} theme`, async ({
            page,
        }) => {
            await loginAsDoctor(page)
            await page.goto(`/dashboard/consultations/view/${endedId}`)
            const createLink = page.locator(
                `[data-test="view-consultation-prescription-link-${endedId}"]`
            )
            await expect(createLink).toBeVisible({ timeout: 30_000 })
            await setResolvedTheme(page, theme)
            await expectReadableContrast(
                createLink,
                `${theme} Nova receita link after consultation end`
            )
        })
    }
})
