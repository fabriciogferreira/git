import { type Locator, type Page, expect } from '@playwright/test'
import { requireVisible } from './feature'

/** Opens Frame → Automations and starts a new automation modal. */
export async function openNewAutomationModal(page: Page) {
    await page.goto('/frame/automations?create=true')

    const picker = page.locator('.new-component-selector')
    const opened = await picker
        .waitFor({ state: 'visible', timeout: 15_000 })
        .then(() => true)
        .catch(() => false)

    // `?create=true` is occasionally ignored while the list is still booting — fall back to CTA.
    if (!opened) {
        await expect(
            page.getByRole('button', { name: /Nova automação|New automation/i }).first()
        ).toBeVisible({ timeout: 45_000 })
        await page
            .getByRole('button', { name: /Nova automação|New automation/i })
            .first()
            .click()
    }

    await expect(picker).toBeVisible({ timeout: 30_000 })
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

// ---------------------------------------------------------------------------
// DOP-1154 — channel management via automation (trigger / condition / action)
// ---------------------------------------------------------------------------

/** Picker title for the channel-state trigger (vue-i18n resolves project_term → projeto). */
export const DOP_1154_CHANNEL_STATE_TRIGGER =
    /Estado da conversa do projeto alterado|Project conversation state changed/i

/** Picker title for the channel-state condition. */
export const DOP_1154_CHANNEL_STATE_CONDITION =
    /Estado da conversa do projeto(?! alterado)|Project conversation state(?! changed)/i

/** Picker title for the channel-manage action. */
export const DOP_1154_CHANNEL_MANAGE_ACTION =
    /Gerenciar canal do projeto|Manage project channel/i

async function searchComponentPicker(page: Page, term: string) {
    const search = page.locator('.new-component-selector input.form-control')
    await expect(search).toBeVisible()
    await search.fill(term)
}

/** Skip unless the channel-state trigger is listed in the (trigger) palette. */
export async function requireChannelStateTrigger(page: Page) {
    await searchComponentPicker(page, 'Estado da conversa')
    await requireVisible(
        page,
        'DOP-1154',
        page
            .locator('.new-component-selector .component-layout')
            .filter({ hasText: DOP_1154_CHANNEL_STATE_TRIGGER }),
        5_000
    )
}

/** Skip unless the channel-state condition is listed after a trigger exists. */
export async function requireChannelStateCondition(page: Page) {
    await searchComponentPicker(page, 'Estado da conversa')
    await requireVisible(
        page,
        'DOP-1154',
        page
            .locator('.new-component-selector .component-layout')
            .filter({ hasText: DOP_1154_CHANNEL_STATE_CONDITION }),
        5_000
    )
}

/** Skip unless the channel-manage action is listed after a trigger exists. */
export async function requireChannelManageAction(page: Page) {
    await searchComponentPicker(page, 'Gerenciar canal')
    await requireVisible(
        page,
        'DOP-1154',
        page
            .locator('.new-component-selector .component-layout')
            .filter({ hasText: DOP_1154_CHANNEL_MANAGE_ACTION }),
        5_000
    )
}

/** New automation → open "Estado da conversa do projeto alterado" trigger. */
export async function openChannelStateTrigger(page: Page) {
    await openNewAutomationModal(page)
    await requireChannelStateTrigger(page)
    await pickFlowComponent(page, DOP_1154_CHANNEL_STATE_TRIGGER)

    await expect(
        page.getByText(/Quando disparar|When to fire|When to trigger/i).first()
    ).toBeVisible({ timeout: 15_000 })
}

/**
 * New automation → any trigger → condition palette →
 * open "Estado da conversa do projeto".
 */
export async function openChannelStateCondition(page: Page) {
    await openNewAutomationModal(page)
    await pickFlowComponent(page, /Projeto movido de etapa|Project moved/i)
    await openActionOrConditionPicker(page)
    await requireChannelStateCondition(page)
    await pickFlowComponent(page, DOP_1154_CHANNEL_STATE_CONDITION)

    await expect(
        page.getByText(/O que verificar|What to check/i).first()
    ).toBeVisible({ timeout: 15_000 })
}

/**
 * New automation → any trigger → action palette →
 * open "Gerenciar canal do projeto".
 */
export async function openChannelManageAction(page: Page) {
    await openNewAutomationModal(page)
    await pickFlowComponent(page, /Projeto movido de etapa|Project moved/i)
    await openActionOrConditionPicker(page)
    await requireChannelManageAction(page)
    await pickFlowComponent(page, DOP_1154_CHANNEL_MANAGE_ACTION)

    await expect(
        page.getByText(/Tipo de ação|Action type/i).first()
    ).toBeVisible({ timeout: 15_000 })
}

/** Label + Select block for a form-label field inside the editing panel. */
function labeledSelectBlock(page: Page, label: RegExp): Locator {
    return page
        .locator('.col-12')
        .filter({ has: page.getByText(label) })
        .first()
}

export function channelManageOperationSelect(page: Page): Locator {
    return labeledSelectBlock(page, /Tipo de ação|Action type/i).locator('.p-select').first()
}

export function channelManageAudienceSelect(page: Page): Locator {
    return labeledSelectBlock(page, /Tipo de canal|Channel type/i).locator('.p-select').first()
}

export function channelStateEventSelect(page: Page): Locator {
    return labeledSelectBlock(page, /Quando disparar|When to fire|When to trigger/i)
        .locator('.p-select')
        .first()
}

export function channelStateCheckSelect(page: Page): Locator {
    return labeledSelectBlock(page, /O que verificar|What to check/i).locator('.p-select').first()
}

/**
 * Resolve the open listbox for a PrimeVue Select (including append-to="self").
 * Prefer aria-controls so page chrome options are ignored.
 */
async function openSelectListbox(page: Page, select: Locator): Promise<Locator> {
    await expect(select).toBeVisible()
    const combobox = select.locator('[role="combobox"]').first()

    const alreadyOpen = (await combobox.getAttribute('aria-expanded')) === 'true'
    if (!alreadyOpen) {
        await combobox.click({ force: true })
    }

    await expect(combobox).toHaveAttribute('aria-expanded', 'true', { timeout: 10_000 })
    const listId = await combobox.getAttribute('aria-controls')
    if (listId) {
        return page.locator(`#${listId}`)
    }

    // append-to="self" sometimes keeps the list inside the select without aria-controls.
    return select.locator('[role="listbox"]').first()
}

/**
 * Open a PrimeVue Select (including append-to="self") and assert option texts.
 * Matches by visible text — option accessible names are often the raw object.
 */
export async function expectSelectOptions(
    page: Page,
    select: Locator,
    optionTexts: Array<string | RegExp>
) {
    const listbox = await openSelectListbox(page, select)

    for (const text of optionTexts) {
        await expect(
            listbox.locator('[role="option"]').filter({ hasText: text }).first()
        ).toBeVisible({ timeout: 10_000 })
    }

    await page.keyboard.press('Escape')
}

/** Pick a PrimeVue Select option by visible text (works with append-to="self"). */
export async function pickSelectOptionByText(
    page: Page,
    select: Locator,
    optionText: string | RegExp
) {
    const listbox = await openSelectListbox(page, select)
    const option = listbox.locator('[role="option"]').filter({ hasText: optionText }).first()
    await expect(option).toBeVisible({ timeout: 10_000 })
    await option.click({ force: true })
}
