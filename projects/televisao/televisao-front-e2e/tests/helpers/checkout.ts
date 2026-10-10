import { type Locator, type Page, expect } from '@playwright/test'

/** Open post-consultation checkout (destination after doctor leaves the meet). */
export async function openCheckout(page: Page, consultationId: string) {
    await page.goto(
        `/dashboard/consultations/${consultationId}/post-consultation`
    )
    await expect(
        page.getByText(/Checkout da receita|Prepare a receita/i).first()
    ).toBeVisible({ timeout: 30_000 })
}

/** Fill minimum valid optical prescription on the checkout form. */
export async function fillCheckoutPrescription(
    page: Page,
    opts: {
        name: string
        sphereOd: number
        cylinderOd?: number
        axisOd?: number
        observations?: string
    }
) {
    await expect(page.locator('#prescription-form-submit-button')).toBeVisible({
        timeout: 20_000,
    })

    await page.getByRole('textbox', { name: /Nome da receita/i }).fill(opts.name)

    // Lens eye schema requires esfera + cilindro + eixo together when any is set.
    const distanceSection = page.locator('section').filter({
        has: page.getByRole('heading', { name: /Visão de longe/i }),
    })
    const rightEye = distanceSection
        .locator('div')
        .filter({ has: page.getByText('Olho direito (OD)', { exact: true }) })
        .first()
    await rightEye.getByRole('spinbutton', { name: /^Esfera/i }).fill(String(opts.sphereOd))
    await rightEye
        .getByRole('spinbutton', { name: /^Cilindro/i })
        .fill(String(opts.cylinderOd ?? 0))
    await rightEye
        .getByRole('spinbutton', { name: /^Eixo/i })
        .fill(String(opts.axisOd ?? 90))

    if (opts.observations) {
        await page
            .getByRole('textbox', { name: /Observações/i })
            .fill(opts.observations)
    }
}

export async function createPrescriptionFromCheckout(page: Page) {
    const responsePromise = page.waitForResponse(
        r =>
            r.url().includes('/prescriptions') &&
            r.request().method() === 'POST',
        { timeout: 30_000 }
    )
    await page.locator('#prescription-form-submit-button').click()
    const response = await responsePromise
    expect(response.ok(), `POST /prescriptions → ${response.status()}`).toBeTruthy()
    await expect(
        page.locator('[data-sonner-toast]').getByText(/Receita criada/i)
    ).toBeVisible({ timeout: 15_000 })
}

export async function concludeCheckout(page: Page) {
    const button = page.locator('#checkout-conclude-button')
    await expect(button).toBeVisible()
    page.once('dialog', dialog => dialog.accept())
    await button.click()
    await expect(page).toHaveURL(/\/dashboard\/consultations\/?$/, {
        timeout: 20_000,
    })
}

export function prescriptionCard(page: Page, name: string): Locator {
    return page.getByText(name, { exact: true }).first()
}
