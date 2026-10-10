import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import {
    fieldsMultiSelect,
    formSelect,
    locationModeSelect,
    openUpdateDynamicFormAction,
    pickFirstFilteredSelectOption,
    selectLocationMode,
} from '../helpers/automation'

/**
 * DOP-1121 — ação de automação "Preencher formulário dinâmico".
 *
 * On a front without the feature (e.g. develop), requireFeature skips.
 * On feature/DOP-1121-*, the action is selectable and location / fields UI works.
 */
test.describe('DOP-1121 update dynamic form action', () => {
    test.describe.configure({ timeout: 90_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
        await openUpdateDynamicFormAction(page)
    })

    test('lists and opens Preencher formulário dinâmico action', async ({ page }) => {
        await expect(
            page.getByText(/Formulário do projeto|Project form/i).first()
        ).toBeVisible()

        await expect(
            page.getByText(
                /Nenhum formulário do projeto está configurado|Campos a atualizar|No project form|Fields to update/i
            ).first()
        ).toBeVisible()
    })

    test('location mode options cover funnel, step, loose and advanced', async ({ page }) => {
        const select = locationModeSelect(page)
        await select.click()

        for (const name of [
            /Formulário do projeto|Project form/i,
            /Formulário de um funil|Funnel form/i,
            /Formulário de uma etapa|Step form/i,
            /Formulário avulso|Loose form/i,
            /Sintaxe avançada|Advanced syntax/i,
        ]) {
            await expect(page.getByRole('option', { name }).first()).toBeVisible()
        }

        // Close overlay without changing selection
        await page.keyboard.press('Escape')
    })

    test('funnel location asks which funnel', async ({ page }) => {
        await selectLocationMode(page, /Formulário de um funil|Funnel form/i)

        await expect(
            page.getByText(/Qual funil\?|Which funnel\?/i).first()
        ).toBeVisible({ timeout: 10_000 })
        await expect(
            page.getByText(/Selecione o funil|Select the funnel/i).first()
        ).toBeVisible()
    })

    test('step location asks which step', async ({ page }) => {
        await selectLocationMode(page, /Formulário de uma etapa|Step form/i)

        await expect(
            page.getByText(/Qual etapa\?|Which step\?/i).first()
        ).toBeVisible({ timeout: 10_000 })
        await expect(
            page.getByText(/Selecione a etapa|Select the step/i).first()
        ).toBeVisible()
    })

    test('loose form shows duplicate warning and form picker', async ({ page }) => {
        await selectLocationMode(page, /Formulário avulso|Loose form/i)

        await expect(
            page.getByText(/Formulários avulsos duplicados|Duplicate loose forms/i)
        ).toBeVisible({ timeout: 10_000 })
        await expect(
            page.getByText(
                /mais de um formulário avulso|more than one loose form/i
            )
        ).toBeVisible()
        await expect(
            page.getByText(/Qual formulário\?|Which form\?/i).first()
        ).toBeVisible()
    })

    test('advanced syntax shows form picker and pivot textarea', async ({ page }) => {
        await selectLocationMode(page, /Sintaxe avançada|Advanced syntax/i)

        await expect(
            page.getByText(/Qual formulário\?|Which form\?/i).first()
        ).toBeVisible({ timeout: 10_000 })

        // AdvancedSyntaxText footer (other hidden textareas exist on the page).
        await expect(
            page.getByText(/Aplicar variável|Apply variable/i).first()
        ).toBeVisible({ timeout: 10_000 })
        await expect(
            page.getByText(/Testar sintaxe|Test syntax/i).first()
        ).toBeVisible()
        await expect(
            page.locator('textarea').filter({ visible: true }).first()
        ).toBeVisible()
    })

    test('selecting a form field shows answer card with overwrite switch', async ({ page }) => {
        // Prefer project form fields; fall back to loose form if the frame has no project model form.
        let fields = fieldsMultiSelect(page)
        const projectHasFields = await fields
            .waitFor({ state: 'visible', timeout: 5_000 })
            .then(() => true)
            .catch(() => false)

        if (!projectHasFields) {
            await selectLocationMode(page, /Formulário avulso|Loose form/i)
            await expect(formSelect(page)).toBeVisible({ timeout: 10_000 })

            try {
                await pickFirstFilteredSelectOption(page, formSelect(page))
            } catch {
                test.skip(true, 'DOP-1121: no forms in frame to pick fields — skipped')
            }

            fields = fieldsMultiSelect(page)
            await expect(fields).toBeVisible({ timeout: 15_000 })
        }

        // Form selection may auto-open the fields MultiSelect — reopen if needed.
        await page.keyboard.press('Escape')
        await fields.click()
        const firstField = page
            .locator('.p-multiselect-overlay [role="option"], .p-multiselect-list [role="option"]')
            .first()
        await expect(firstField).toBeVisible({ timeout: 10_000 })
        const fieldLabel = (await firstField.innerText()).trim().split('\n')[0].trim()
        await firstField.click()
        await page.keyboard.press('Escape')
        await expect(page.locator('.p-multiselect-overlay')).toHaveCount(0)

        await expect(
            page.getByText(/Sobrescrever se já houver resposta|Overwrite if already answered/i)
        ).toBeVisible({ timeout: 15_000 })

        if (fieldLabel) {
            await expect(page.getByText(fieldLabel, { exact: false }).first()).toBeVisible()
        }

        await expect(
            page.getByRole('button', { name: /Remover|Remove/i }).first()
        ).toBeVisible()
    })

    test('switching location modes clears secondary selects appropriately', async ({ page }) => {
        await selectLocationMode(page, /Formulário de um funil|Funnel form/i)
        await expect(page.getByText(/Qual funil\?|Which funnel\?/i).first()).toBeVisible()

        await selectLocationMode(page, /Formulário de uma etapa|Step form/i)
        await expect(page.getByText(/Qual etapa\?|Which step\?/i).first()).toBeVisible()
        await expect(page.getByText(/Qual funil\?|Which funnel\?/i)).toHaveCount(0)

        await selectLocationMode(page, /Formulário do projeto|Project form/i)
        await expect(page.getByText(/Qual etapa\?|Which step\?/i)).toHaveCount(0)
        await expect(
            page.getByText(
                /Nenhum formulário do projeto está configurado|Campos a atualizar|No project form|Fields to update/i
            ).first()
        ).toBeVisible()
    })
})
