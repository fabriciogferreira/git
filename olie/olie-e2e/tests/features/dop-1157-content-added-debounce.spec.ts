import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import {
    businessRulesCard,
    contentAddedDebounceCard,
    contentAddedDebounceInput,
    openFrameSettings,
    requireContentAddedDebounceSettings,
    setContentAddedDebounceSeconds,
} from '../helpers/frame-settings'

/**
 * DOP-1157 — content_added_debounce_seconds on company settings.
 *
 * Skips via requireVisible when the card is absent on the front under test.
 */
test.describe('DOP-1157 content added debounce settings', () => {
    test.describe.configure({ timeout: 90_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
        await openFrameSettings(page)
        await requireContentAddedDebounceSettings(page)
    })

    test('shows field, dual-effect warning and no-response warning', async ({ page }) => {
        const card = contentAddedDebounceCard(page)
        await expect(card).toBeVisible()
        await expect(contentAddedDebounceInput(page)).toBeVisible()

        await expect(
            card.getByText(/Um número, dois efeitos|One number, two effects/i)
        ).toBeVisible()
        await expect(
            card.getByText(/rodar mais vezes|run more often/i)
        ).toBeVisible()
        await expect(
            card.getByText(
                /contato fica sem resposta|contact goes without a response/i
            )
        ).toBeVisible()
    })

    test('loads an integer within the allowed range', async ({ page }) => {
        const input = contentAddedDebounceInput(page)
        await expect(input).toBeVisible()

        const raw = await input.inputValue()
        const value = Number(raw)
        expect(Number.isInteger(value)).toBe(true)
        expect(value).toBeGreaterThanOrEqual(3)
        expect(value).toBeLessThanOrEqual(120)
    })

    test('blocks values outside 3–120 without posting', async ({ page }) => {
        const card = contentAddedDebounceCard(page)

        let posted = false
        page.on('request', request => {
            if (
                /frame-configurations/.test(request.url()) &&
                request.method() === 'POST'
            ) {
                posted = true
            }
        })

        await setContentAddedDebounceSeconds(page, '2')
        await card.getByRole('button', { name: /Salvar|Save/i }).click()

        await expect(
            page.getByText(
                /Informe um número inteiro entre 3 e 120|Enter a whole number between 3 and 120/i
            ).first()
        ).toBeVisible({ timeout: 10_000 })

        await page.waitForTimeout(500)
        expect(posted).toBe(false)
    })

    test('saves a valid value and keeps it after reload', async ({ page }) => {
        const card = contentAddedDebounceCard(page)
        const input = contentAddedDebounceInput(page)

        const original = await input.inputValue()
        const target = original === '9' ? '11' : '9'

        await setContentAddedDebounceSeconds(page, target)

        await page.keyboard.press('Escape')

        const saveResponse = page.waitForResponse(
            r =>
                /frame-configurations/.test(r.url()) &&
                r.request().method() === 'POST' &&
                (r.status() === 200 || r.status() === 422),
            { timeout: 30_000 }
        )
        await card.getByRole('button', { name: /Salvar|Save/i }).click({ force: true })
        const response = await saveResponse
        expect(response.status()).toBe(200)
        const posted = response.request().postDataJSON() as {
            content_added_debounce_seconds?: number
        }
        expect(posted.content_added_debounce_seconds).toBe(Number(target))

        await expect(
            page.getByText(
                /Tempo de espera salvo com sucesso|Wait time saved successfully/i
            ).first()
        ).toBeVisible({ timeout: 15_000 })

        await openFrameSettings(page)
        await requireContentAddedDebounceSettings(page)
        await expect(contentAddedDebounceInput(page)).toHaveValue(target)

        // Restore so the seed frame stays stable across runs.
        await setContentAddedDebounceSeconds(page, original)
        await page.keyboard.press('Escape')
        const restoreResponse = page.waitForResponse(
            r =>
                /frame-configurations/.test(r.url()) &&
                r.request().method() === 'POST' &&
                r.status() === 200,
            { timeout: 30_000 }
        )
        await contentAddedDebounceCard(page)
            .getByRole('button', { name: /Salvar|Save/i })
            .click({ force: true })
        await restoreResponse
    })

    test('coexists with business rules on the same page', async ({ page }) => {
        await expect(contentAddedDebounceCard(page)).toBeVisible()
        await expect(businessRulesCard(page)).toBeVisible()
    })
})
