import { test, expect, type Page, type Route } from '@playwright/test'
import { requireFeature } from '../helpers/feature'
import {
    expectReadableContrast,
    measureContrastRatio,
    setResolvedTheme,
} from '../helpers/theme'

/**
 * DOP-1260 — public pivot-accessor form must keep in-progress answers after
 * tab/window focus, and must not treat empty required fields as a successful submit.
 *
 * Mocks decode/reply so the suite does not need a live signed accessor URL.
 * On a front without PublicFormPivotAccessor (or without the Enviar button),
 * requireFeature skips instead of failing develop.
 */

const FORM_TITLE = 'E2E DOP-1260 Public Form'
const FIELD_LABEL = 'E2E Campo obrigatório'
const FIELD_ID = 91260

const DECODE_PATH = /\/dynamic-forms\/pivot-accessor\/decode/
const REPLY_PATH = /\/dynamic-forms\/pivot-accessor\/reply/

function mockDecodePayload(answer: string | null = null) {
    return {
        response: true,
        form: {
            id: 1260,
            title: FORM_TITLE,
            edges: [
                {
                    id: FIELD_ID,
                    label: FIELD_LABEL,
                    type: 'short_text',
                    required: true,
                    index: 1,
                    options: [],
                    help_text: null,
                    description: null,
                    initial_value: null,
                    custom_validation: null,
                    conditional: null,
                    is_multiple: false,
                    logical_operator: 'and',
                    conditionals: [],
                },
            ],
        },
        form_answers: [
            {
                id: FIELD_ID,
                label: FIELD_LABEL,
                answer,
                model: 'Project',
            },
        ],
        reply_url:
            'http://api.olie.localhost/api/management/dynamic-forms/pivot-accessor/reply?accessor=e2e&signature=e2e',
        upload_url:
            'http://api.olie.localhost/api/management/dynamic-forms/pivot-accessor/upload-file?accessor=e2e&signature=e2e',
    }
}

async function stubPivotAccessorApis(page: Page) {
    let decodeCount = 0
    const replyBodies: unknown[] = []

    await page.route(DECODE_PATH, async (route: Route) => {
        if (route.request().method() !== 'GET') {
            await route.continue()
            return
        }
        decodeCount += 1
        await route.fulfill({
            status: 200,
            contentType: 'application/json',
            body: JSON.stringify(mockDecodePayload(null)),
        })
    })

    await page.route(REPLY_PATH, async (route: Route) => {
        if (route.request().method() !== 'POST') {
            await route.continue()
            return
        }
        let body: unknown = null
        try {
            body = route.request().postDataJSON()
        } catch {
            body = route.request().postData()
        }
        replyBodies.push(body)
        await route.fulfill({
            status: 200,
            contentType: 'application/json',
            body: JSON.stringify({ response: true, form_answers: [] }),
        })
    })

    return {
        getDecodeCount: () => decodeCount,
        getReplyBodies: () => replyBodies,
    }
}

async function openPublicAccessorForm(page: Page) {
    await page.goto('/public-form/accessor?accessor=e2e&signature=e2e')

    await requireFeature(page, {
        id: 'DOP-1260',
        probe: async () => {
            try {
                await page
                    .getByRole('button', { name: /^(Enviar|Send)$/i })
                    .waitFor({ state: 'visible', timeout: 12_000 })
                return true
            } catch {
                return false
            }
        },
    })

    await expect(page.getByText(FIELD_LABEL).first()).toBeVisible({ timeout: 15_000 })
}

async function simulateTabReturn(page: Page) {
    await page.evaluate(() => {
        Object.defineProperty(document, 'hidden', {
            configurable: true,
            get: () => true,
        })
        document.dispatchEvent(new Event('visibilitychange'))
        window.dispatchEvent(new Event('blur'))
    })
    await page.waitForTimeout(200)
    await page.evaluate(() => {
        Object.defineProperty(document, 'hidden', {
            configurable: true,
            get: () => false,
        })
        document.dispatchEvent(new Event('visibilitychange'))
        window.dispatchEvent(new Event('focus'))
    })
    await page.waitForTimeout(500)
}

test.describe('DOP-1260 public form empty answers after tab switch', () => {
    test.describe.configure({ timeout: 90_000 })

    test('keeps filled answers after window focus and does not refetch wipe', async ({
        page,
    }) => {
        const api = await stubPivotAccessorApis(page)
        await openPublicAccessorForm(page)

        const input = page.locator('input.form-control').first()
        await expect(input).toBeVisible()
        await input.fill('resposta-e2e-dop-1260')
        await expect(input).toHaveValue('resposta-e2e-dop-1260')

        const decodeBeforeFocus = api.getDecodeCount()
        expect(decodeBeforeFocus).toBeGreaterThanOrEqual(1)

        await simulateTabReturn(page)

        await expect(input).toHaveValue('resposta-e2e-dop-1260')
        expect(api.getDecodeCount()).toBe(decodeBeforeFocus)

        await page.getByRole('button', { name: /^(Enviar|Send)$/i }).click()

        await expect(
            page.getByText(/Formulário enviado com sucesso|Form submitted successfully/i)
        ).toBeVisible({ timeout: 10_000 })

        await expect
            .poll(() => api.getReplyBodies().length, { timeout: 10_000 })
            .toBe(1)

        const body = api.getReplyBodies()[0] as {
            form_answers?: Array<{ id: number; answer: unknown }>
        }
        const answers = body?.form_answers ?? []
        const field = answers.find(a => a.id === FIELD_ID)
        expect(field?.answer).toBe('resposta-e2e-dop-1260')
    })

    test('blocks submit when required field is empty', async ({ page }) => {
        const api = await stubPivotAccessorApis(page)
        await openPublicAccessorForm(page)

        await page.getByRole('button', { name: /^(Enviar|Send)$/i }).click()

        await expect(
            page.getByText(/não está completo|is not complete|incomplete/i)
        ).toBeVisible({ timeout: 10_000 })

        await expect(
            page.getByText(/Formulário enviado com sucesso|Form submitted successfully/i)
        ).toHaveCount(0)

        expect(api.getReplyBodies()).toHaveLength(0)
    })

    test('light and dark contrast on public form labels', async ({ page }) => {
        await stubPivotAccessorApis(page)
        await openPublicAccessorForm(page)

        const label = page.getByText(FIELD_LABEL).first()
        const send = page.getByRole('button', { name: /^(Enviar|Send)$/i })

        for (const theme of ['light', 'dark'] as const) {
            await setResolvedTheme(page, theme)
            // Assert body/label copy (changed surface). Primary Enviar is brand
            // orange + white — sample only; same non-blocking pattern as DOP-1154.
            await expectReadableContrast(label, `DOP-1260 ${theme} field label`)
            const { ratio, fg, bg } = await measureContrastRatio(send)
            test.info().annotations.push({
                type: 'contrast-sample',
                description: `DOP-1260 ${theme} Enviar ${ratio.toFixed(2)}:1 fg=${fg} bg=${bg}`,
            })
        }
    })
})
