import { type Locator, type Page, expect } from '@playwright/test'
import { requireVisible } from './feature'

/** Opens Frame → Automations and starts a new automation modal. */
export async function openNewAutomationModal(page: Page) {
    await page.goto('/frame/automations?create=true')
    // PrimeVue Dialog + component picker
    await expect(page.locator('.new-component-selector')).toBeVisible({ timeout: 30_000 })
}

/** Pick a flow component card by its visible label (trigger/action/condition). */
export async function pickFlowComponent(page: Page, label: string | RegExp) {
    const card = page.locator('.new-component-selector .component-layout').filter({
        hasText: label,
    })
    await expect(card.first()).toBeVisible({ timeout: 15_000 })
    await card.first().click()
}

/**
 * After a trigger is configured, reopen the component palette
 * (sidebar "Adicionar ação ou condição" — always present; footer tip may be dismissed).
 */
export async function openActionOrConditionPicker(page: Page) {
    const add = page.getByText(/Adicionar ação ou condição|Add action or condition/i).first()
    await expect(add).toBeVisible({ timeout: 15_000 })
    await add.click()
    await expect(page.locator('.new-component-selector')).toBeVisible({ timeout: 15_000 })
}

/**
 * DOP-1121 gate: after a trigger exists, the action palette must list
 * "Preencher formulário dinâmico". Skips on fronts that lack the feature.
 */
export async function requireUpdateDynamicFormAction(page: Page) {
    const search = page.locator('.new-component-selector input.form-control')
    await expect(search).toBeVisible()
    await search.fill('Preencher formulário dinâmico')

    await requireVisible(
        page,
        'DOP-1121',
        page
            .locator('.new-component-selector .component-layout')
            .filter({ hasText: /Preencher formulário dinâmico/i }),
        5_000
    )
}

/**
 * New automation → trigger → action palette → open "Preencher formulário dinâmico".
 * Skips when the action is absent on the front under test.
 */
export async function openUpdateDynamicFormAction(page: Page) {
    await openNewAutomationModal(page)
    await pickFlowComponent(page, /Projeto movido de etapa|Project moved/i)
    await openActionOrConditionPicker(page)
    await requireUpdateDynamicFormAction(page)
    await pickFlowComponent(page, /Preencher formulário dinâmico/i)

    await expect(
        page.getByText(/Onde está o formulário\?|Where is the form\?/i)
    ).toBeVisible({ timeout: 15_000 })
}

/** Block wrapping the "Onde está o formulário?" Select. */
export function locationModeBlock(page: Page): Locator {
    return page
        .locator('.mb-4')
        .filter({ has: page.getByText(/Onde está o formulário\?|Where is the form\?/i) })
        .first()
}

/** Location mode Select (project / funnel / step / loose / advanced). */
export function locationModeSelect(page: Page): Locator {
    return locationModeBlock(page).locator('.p-select').first()
}

/** Choose a PrimeVue Select option by accessible name (page-level options). */
export async function pickSelectOption(page: Page, select: Locator, optionName: string | RegExp) {
    await expect(select).toBeVisible()
    await select.click()
    const option = page.getByRole('option', { name: optionName }).first()
    await expect(option).toBeVisible({ timeout: 10_000 })
    await option.click()
}

export async function selectLocationMode(page: Page, optionName: string | RegExp) {
    await pickSelectOption(page, locationModeSelect(page), optionName)
}

/** "Qual formulário?" Select (loose / advanced modes). */
export function formSelect(page: Page): Locator {
    return page
        .locator('.mb-4')
        .filter({ has: page.getByText(/Qual formulário\?|Which form\?/i) })
        .locator('.p-select')
        .first()
}

/**
 * Pick the first option of a filtered PrimeVue Select, scoped via aria-controls
 * so page chrome options (filters, phone country, …) are ignored.
 * Prefer an already-open overlay (location change auto-opens the form Select).
 */
export async function pickFirstFilteredSelectOption(page: Page, select: Locator) {
    await expect(select).toBeVisible()
    const combobox = select.locator('[role="combobox"]').first()

    const alreadyOpen = (await combobox.getAttribute('aria-expanded')) === 'true'
    if (!alreadyOpen) {
        await combobox.click()
    }

    await expect(combobox).toHaveAttribute('aria-expanded', 'true', { timeout: 10_000 })
    const listId = await combobox.getAttribute('aria-controls')
    if (!listId) throw new Error('Select has no aria-controls listbox id')

    const listbox = page.locator(`#${listId}`)
    const filter = listbox.locator('input').first()
    if (await filter.isVisible().catch(() => false)) {
        await filter.fill('')
    }

    const option = listbox.getByRole('option').first()
    await expect(option).toBeVisible({ timeout: 10_000 })
    const label = (await option.innerText()).trim().split('\n')[0].trim()
    await option.click()
    return label
}

/** Fields MultiSelect ("Campos a atualizar") when a form is resolved. */
export function fieldsMultiSelect(page: Page): Locator {
    return page
        .locator('.mb-4')
        .filter({ has: page.getByText(/Campos a atualizar|Fields to update/i) })
        .locator('.p-multiselect')
        .first()
}
