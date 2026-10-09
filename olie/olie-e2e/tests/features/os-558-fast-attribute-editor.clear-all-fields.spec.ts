import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { createE2EProject } from '../helpers/project'
import { openProjectOverview } from '../helpers/content-media'
import {
    HEADER_FIELD_LABEL,
    createE2EContact,
    createE2ECustomer,
    createE2EProjectGroup,
    ensureEditableHeaderFieldsVisible,
    fastAttributeCancelButton,
    fastAttributeClearButton,
    fastAttributeEditor,
    fastAttributeSaveButton,
    getFirstAssignableUserId,
    headerItemByLabel,
    openHeaderFastAttributeEditor,
    requireFastAttributeClearButton,
    updateProjectViaApi,
    waitForProjectPut,
} from '../helpers/fast-attribute-editor'

/**
 * OS-558 — Limpar draft clear across every non-watch FastAttributeEditor header field.
 *
 * Option A: Limpar clears the draft without closing; Cancelar discards; Salvar persists
 * only for attributes the API accepts as empty/null.
 *
 * Watch-mode fields (tags) must NOT show Limpar.
 */
test.describe('OS-558 FastAttributeEditor Limpar — all fields', () => {
    test.describe.configure({ timeout: 120_000 })

    test('description: Limpar clears draft; Cancelar restores', async ({ page }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-os558-all-desc-${Date.now()}`,
        })
        const initial = `e2e-os558-all-desc-${Date.now()}`
        await updateProjectViaApi(page, projectId, { description: initial })

        const editor = await openHeaderFastAttributeEditor(
            page,
            projectId,
            HEADER_FIELD_LABEL.description
        )
        await requireFastAttributeClearButton(page, editor)

        const field = editor.locator('textarea').first()
        await expect(field).toHaveValue(initial)

        await fastAttributeClearButton(editor).click()
        await expect(field).toHaveValue('')
        await expect(editor).toBeVisible()

        await fastAttributeCancelButton(editor).click()
        await expect(fastAttributeEditor(page)).toHaveCount(0, { timeout: 10_000 })
        await expect(headerItemByLabel(page, HEADER_FIELD_LABEL.description)).toContainText(
            initial
        )
    })

    test('impact: Limpar clears draft; Cancelar restores', async ({ page }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-os558-all-impact-${Date.now()}`,
        })
        await updateProjectViaApi(page, projectId, { impact: 5 })

        const editor = await openHeaderFastAttributeEditor(
            page,
            projectId,
            HEADER_FIELD_LABEL.impact
        )
        await requireFastAttributeClearButton(page, editor)

        const select = editor.locator('select').first()
        await expect(select).toHaveValue('5')

        await fastAttributeClearButton(editor).click()
        await expect(select).not.toHaveValue('5')
        await expect(editor).toBeVisible()

        await fastAttributeCancelButton(editor).click()
        await expect(fastAttributeEditor(page)).toHaveCount(0, { timeout: 10_000 })
        await expect(headerItemByLabel(page, HEADER_FIELD_LABEL.impact)).toContainText('5')
    })

    test('budget: Limpar clears draft; Limpar+Salvar persists 0', async ({ page }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-os558-all-budget-${Date.now()}`,
        })
        await updateProjectViaApi(page, projectId, { budget: 1234.56 })

        const editor = await openHeaderFastAttributeEditor(
            page,
            projectId,
            HEADER_FIELD_LABEL.budget
        )
        await requireFastAttributeClearButton(page, editor)

        const moneyInput = editor.locator('input').first()
        await expect(moneyInput).not.toHaveValue('', { timeout: 5_000 })

        await fastAttributeClearButton(editor).click()
        // Budget clears to 0 (DB NOT NULL); MoneyInput shows 0,00 / R$ 0,00.
        const cleared = (await moneyInput.inputValue()).replace(/\s/g, '')
        expect(/0/.test(cleared)).toBe(true)
        await expect(editor).toBeVisible()

        const response = await waitForProjectPut(page, projectId, async () => {
            await fastAttributeSaveButton(editor).click()
        })
        expect(response.status()).toBe(200)

        const body = response.request().postDataJSON() as { budget?: number | null } | null
        expect(body?.budget === 0 || body?.budget === null).toBe(true)

        await expect(fastAttributeEditor(page)).toHaveCount(0, { timeout: 10_000 })
    })

    test('status: Limpar clears draft; Cancelar restores', async ({ page }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-os558-all-status-${Date.now()}`,
        })
        // Seed a known status so Cancelar restore is assertable even if overview is slow.
        await updateProjectViaApi(page, projectId, { status: 1 })

        const editor = await openHeaderFastAttributeEditor(
            page,
            projectId,
            HEADER_FIELD_LABEL.status
        )
        await requireFastAttributeClearButton(page, editor)

        const selectLabel = editor.locator('.p-select-label, .p-dropdown-label').first()
        await expect(selectLabel).toBeVisible({ timeout: 5_000 })
        const before = (await selectLabel.innerText()).trim()
        expect(before.length).toBeGreaterThan(0)

        await fastAttributeClearButton(editor).click()
        await expect(editor).toBeVisible()
        await expect(fastAttributeClearButton(editor)).toBeVisible()
        // Draft cleared: label empty / placeholder, or no longer the previous value.
        const after = (await selectLabel.innerText()).trim()
        expect(after === '' || after !== before || /selecion|select|choose/i.test(after)).toBe(
            true
        )

        await fastAttributeCancelButton(editor).click()
        await expect(fastAttributeEditor(page)).toHaveCount(0, { timeout: 10_000 })
        await expect(headerItemByLabel(page, HEADER_FIELD_LABEL.status)).toContainText(before)
    })

    test('customer: Limpar clears draft; Limpar+Salvar unlinks', async ({ page }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-os558-all-customer-${Date.now()}`,
        })
        const customer = await createE2ECustomer(page, `e2e-os558-cust-${Date.now()}`)
        await updateProjectViaApi(page, projectId, { customer_id: customer.id })

        const editor = await openHeaderFastAttributeEditor(
            page,
            projectId,
            HEADER_FIELD_LABEL.customer
        )
        await requireFastAttributeClearButton(page, editor)

        await expect(editor.getByText(customer.name).first()).toBeVisible({ timeout: 5_000 })

        await fastAttributeClearButton(editor).click()
        await expect(editor.getByText(customer.name)).toHaveCount(0)
        await expect(editor).toBeVisible()

        const response = await waitForProjectPut(page, projectId, async () => {
            await fastAttributeSaveButton(editor).click()
        })
        expect(response.status()).toBe(200)

        const body = response.request().postDataJSON() as {
            customer_id?: string | null
        } | null
        expect(body?.customer_id).toBeNull()

        await expect(fastAttributeEditor(page)).toHaveCount(0, { timeout: 10_000 })
        await expect(headerItemByLabel(page, HEADER_FIELD_LABEL.customer)).not.toContainText(
            customer.name,
            { timeout: 15_000 }
        )
    })

    test('contact: Limpar clears draft; Limpar+Salvar unlinks', async ({ page }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-os558-all-contact-${Date.now()}`,
        })
        const customer = await createE2ECustomer(page, `e2e-os558-cust2-${Date.now()}`)
        const contact = await createE2EContact(page, {
            name: `e2e-os558-cont-${Date.now()}`,
            customerId: customer.id,
        })
        await updateProjectViaApi(page, projectId, {
            customer_id: customer.id,
            contact_id: contact.id,
        })

        const editor = await openHeaderFastAttributeEditor(
            page,
            projectId,
            HEADER_FIELD_LABEL.contact
        )
        await requireFastAttributeClearButton(page, editor)

        await expect(editor.getByText(contact.name).first()).toBeVisible({ timeout: 5_000 })

        await fastAttributeClearButton(editor).click()
        await expect(editor.getByText(contact.name)).toHaveCount(0)
        await expect(editor).toBeVisible()

        const response = await waitForProjectPut(page, projectId, async () => {
            await fastAttributeSaveButton(editor).click()
        })
        expect(response.status()).toBe(200)

        const body = response.request().postDataJSON() as {
            contact_id?: string | null
        } | null
        expect(body?.contact_id).toBeNull()

        await expect(fastAttributeEditor(page)).toHaveCount(0, { timeout: 10_000 })
        await expect(headerItemByLabel(page, HEADER_FIELD_LABEL.contact)).not.toContainText(
            contact.name,
            { timeout: 15_000 }
        )
    })

    test('assignees: Limpar marks users for removal in draft; Cancelar restores', async ({
        page,
    }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-os558-all-assignees-${Date.now()}`,
        })
        const userId = await getFirstAssignableUserId(page)
        await updateProjectViaApi(page, projectId, {
            users: [{ user_id: userId, role: 'assignee', action: 'add' }],
        })

        const editor = await openHeaderFastAttributeEditor(
            page,
            projectId,
            HEADER_FIELD_LABEL.assignees
        )
        await requireFastAttributeClearButton(page, editor)

        const removeButtons = editor.locator('button[aria-label^="Remover"]')
        await expect(removeButtons.first()).toBeVisible({ timeout: 10_000 })
        const beforeCount = await removeButtons.count()
        expect(beforeCount).toBeGreaterThan(0)

        await fastAttributeClearButton(editor).click()
        await expect(removeButtons).toHaveCount(0)
        await expect(editor).toBeVisible()

        await fastAttributeCancelButton(editor).click()
        await expect(fastAttributeEditor(page)).toHaveCount(0, { timeout: 10_000 })

        // Header should still show an assignee name (not only "-").
        const header = headerItemByLabel(page, HEADER_FIELD_LABEL.assignees)
        await expect(header.locator('.fw-bold')).not.toHaveText(/^-$/, { timeout: 10_000 })
    })

    test('groups: Limpar clears MultiSelect draft; Cancelar restores', async ({ page }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-os558-all-groups-${Date.now()}`,
        })
        const group = await createE2EProjectGroup(page, `e2e-os558-grp-${Date.now()}`)
        await updateProjectViaApi(page, projectId, {
            groups: { to_add: [group.id], to_rem: [] },
        })

        const editor = await openHeaderFastAttributeEditor(
            page,
            projectId,
            HEADER_FIELD_LABEL.groups
        )
        await requireFastAttributeClearButton(page, editor)

        const multi = editor.locator('.p-multiselect').first()
        await expect(multi).toBeVisible({ timeout: 10_000 })
        await expect(editor.getByText(group.name).first()).toBeVisible({ timeout: 10_000 })

        await fastAttributeClearButton(editor).click()
        await expect(editor).toBeVisible()
        // Cleared selection: chip gone from MultiSelect label; unlink preview lists the group.
        await expect(multi.getByText(group.name)).toHaveCount(0)
        await expect(
            editor.getByText(/Desvincular|Unlink|to unlink|desvincular/i).first()
        ).toBeVisible({ timeout: 5_000 })
        await expect(editor.getByText(group.name).first()).toBeVisible()

        await fastAttributeCancelButton(editor).click()
        await expect(fastAttributeEditor(page)).toHaveCount(0, { timeout: 10_000 })
        await expect(headerItemByLabel(page, HEADER_FIELD_LABEL.groups)).toContainText(
            group.name
        )
    })

    test('groups: Limpar+Salvar persists unlink via groups.to_rem', async ({ page }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-os558-all-groups-save-${Date.now()}`,
        })
        const group = await createE2EProjectGroup(page, `e2e-os558-grp-save-${Date.now()}`)
        await updateProjectViaApi(page, projectId, {
            groups: { to_add: [group.id], to_rem: [] },
        })

        const editor = await openHeaderFastAttributeEditor(
            page,
            projectId,
            HEADER_FIELD_LABEL.groups
        )
        await requireFastAttributeClearButton(page, editor)

        await expect(editor.getByText(group.name).first()).toBeVisible({ timeout: 10_000 })

        await fastAttributeClearButton(editor).click()
        await expect(editor.locator('.p-multiselect').first().getByText(group.name)).toHaveCount(
            0
        )
        await expect(
            editor.getByText(/Desvincular|Unlink|to unlink|desvincular/i).first()
        ).toBeVisible({ timeout: 5_000 })

        const response = await waitForProjectPut(page, projectId, async () => {
            await fastAttributeSaveButton(editor).click()
        })
        expect(response.status()).toBe(200)

        const body = response.request().postDataJSON() as {
            groups?: { to_add?: number[]; to_rem?: number[] }
        } | null
        expect(body?.groups).toBeTruthy()
        expect(body?.groups?.to_rem ?? []).toContain(group.id)
        expect(body?.groups?.to_add ?? []).not.toContain(group.id)

        await expect(fastAttributeEditor(page)).toHaveCount(0, { timeout: 10_000 })
        await expect(headerItemByLabel(page, HEADER_FIELD_LABEL.groups)).not.toContainText(
            group.name,
            { timeout: 15_000 }
        )
    })

    test('tags (watch): Limpar is not shown', async ({ page }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-os558-all-tags-${Date.now()}`,
        })

        await openProjectOverview(page, projectId)
        await expect(page.locator('.project-header-item, .fa-columns').first()).toBeVisible({
            timeout: 40_000,
        })
        await ensureEditableHeaderFieldsVisible(page)

        const tagsItem = headerItemByLabel(page, HEADER_FIELD_LABEL.tags)
        await expect(tagsItem).toBeVisible({ timeout: 20_000 })

        // Click target is the tags body (watch editor), not the fw-light label.
        const editBtn = tagsItem.getByRole('button').first()
        if ((await editBtn.count()) > 0) {
            await editBtn.click()
        } else {
            await tagsItem.locator('.fw-bold, .d-flex.flex-wrap').first().click()
        }

        const editor = fastAttributeEditor(page)
        await expect(editor).toBeVisible({ timeout: 10_000 })

        // Watch mode: Cancelar/Salvar/Limpar footer hidden.
        await expect(fastAttributeClearButton(editor)).toHaveCount(0)
        await expect(fastAttributeCancelButton(editor)).toHaveCount(0)
        await expect(fastAttributeSaveButton(editor)).toHaveCount(0)
    })
})
