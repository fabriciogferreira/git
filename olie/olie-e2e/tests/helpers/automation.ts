import { type Page, expect } from '@playwright/test'
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
