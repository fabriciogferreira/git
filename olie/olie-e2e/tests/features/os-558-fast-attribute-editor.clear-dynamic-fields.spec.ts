import { test, expect, type Locator } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { createE2EProject, openProjectDetailsTab } from '../helpers/project'
import {
    createE2EContact,
    createE2ECustomer,
    createE2EDynamicForm,
    fastAttributeClearButton,
    fastAttributeEditor,
    getFirstAssignableUser,
    openDynamicFormFastAttributeEditor,
    requireFastAttributeClearButton,
    richTextAnswerDoc,
    type E2EFormEdge,
} from '../helpers/fast-attribute-editor'

/**
 * OS-558 — Limpar must stick for dynamic-form edge types that previously bounced
 * (rich_text TipTap + entity autocompletes: user/customer/contact/project).
 *
 * Opens the shared FastAttributeEditor via store dispatch (same DynamicInputPreview
 * path as kanban/list), seeds a value, Limpar, then waits to assert it does not return.
 */
test.describe('OS-558 FastAttributeEditor Limpar — dynamic form fields', () => {
    test.describe.configure({ timeout: 120_000 })

    let edgesByType: Record<string, E2EFormEdge> = {}

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
        // Internal layout mounts FastAttributeEditor.
        const projectId = await createE2EProject(page, {
            name: `e2e-os558-dyn-shell-${Date.now()}`,
        })
        await openProjectDetailsTab(page, projectId, 'overview')

        const { edges } = await createE2EDynamicForm(page, {
            title: `e2e-os558-dyn-${Date.now()}`,
            edges: [
                { label: 'E2E Rich', type: 'rich_text', index: 0 },
                { label: 'E2E User', type: 'user', index: 1, is_multiple: false },
                { label: 'E2E Customer', type: 'customer', index: 2, is_multiple: false },
                { label: 'E2E Contact', type: 'contact', index: 3, is_multiple: false },
                { label: 'E2E Project', type: 'project', index: 4, is_multiple: false },
            ],
        })

        edgesByType = Object.fromEntries(edges.map(e => [e.type, e]))
    })

    /** Avoid pointer interception / Popover dismiss from synthetic overlay coords. */
    async function clickLimpar(editor: Locator) {
        await fastAttributeClearButton(editor).evaluate((el: HTMLElement) => el.click())
    }

    /** Single-select entity inputs put the label in the autocomplete <input>, not a text node. */
    function entitySearchInput(editor: Locator) {
        return editor.locator('input').first()
    }

    test('rich_text: Limpar clears TipTap and does not bounce back', async ({ page }) => {
        const edge = edgesByType.rich_text
        const seed = `e2e-rich-${Date.now()}`
        const editor = await openDynamicFormFastAttributeEditor(
            page,
            edge,
            richTextAnswerDoc(seed)
        )
        await requireFastAttributeClearButton(page, editor)

        const prose = editor.locator('.ProseMirror')
        await expect(prose).toContainText(seed, { timeout: 10_000 })

        await clickLimpar(editor)
        await expect(editor).toBeVisible()
        await expect(prose).toBeVisible({ timeout: 5_000 })
        await expect(prose).not.toContainText(seed)

        // Bounce regression: TipTap onUpdate used to restore the old JSON.
        await page.waitForTimeout(800)
        await expect(editor).toBeVisible()
        await expect(prose).not.toContainText(seed)
        await expect(fastAttributeEditor(page)).toBeVisible()
    })

    test('user: Limpar clears autocomplete selection and does not bounce back', async ({
        page,
    }) => {
        const edge = edgesByType.user
        const user = await getFirstAssignableUser(page)
        const editor = await openDynamicFormFastAttributeEditor(page, edge, [
            { id: user.id, name: user.name },
        ])
        await requireFastAttributeClearButton(page, editor)

        const input = entitySearchInput(editor)
        await expect(input).toHaveValue(user.name, { timeout: 10_000 })

        await clickLimpar(editor)
        await expect(editor).toBeVisible()
        await expect(input).toHaveValue('', { timeout: 5_000 })

        await page.waitForTimeout(800)
        await expect(editor).toBeVisible()
        await expect(input).toHaveValue('')
    })

    test('customer: Limpar clears autocomplete selection and does not bounce back', async ({
        page,
    }) => {
        const edge = edgesByType.customer
        const customer = await createE2ECustomer(page, `e2e-os558-dyn-cust-${Date.now()}`)
        const editor = await openDynamicFormFastAttributeEditor(page, edge, [
            { id: customer.id, name: customer.name },
        ])
        await requireFastAttributeClearButton(page, editor)

        const input = entitySearchInput(editor)
        await expect(input).toHaveValue(customer.name, { timeout: 10_000 })

        await clickLimpar(editor)
        await expect(editor).toBeVisible()
        await expect(input).toHaveValue('', { timeout: 5_000 })

        await page.waitForTimeout(800)
        await expect(editor).toBeVisible()
        await expect(input).toHaveValue('')
    })

    test('contact: Limpar clears autocomplete selection and does not bounce back', async ({
        page,
    }) => {
        const edge = edgesByType.contact
        const customer = await createE2ECustomer(page, `e2e-os558-dyn-cust2-${Date.now()}`)
        const contact = await createE2EContact(page, {
            name: `e2e-os558-dyn-cont-${Date.now()}`,
            customerId: customer.id,
        })
        const editor = await openDynamicFormFastAttributeEditor(page, edge, [
            { id: contact.id, name: contact.name },
        ])
        await requireFastAttributeClearButton(page, editor)

        const input = entitySearchInput(editor)
        await expect(input).toHaveValue(contact.name, { timeout: 10_000 })

        await clickLimpar(editor)
        await expect(editor).toBeVisible()
        await expect(input).toHaveValue('', { timeout: 5_000 })

        await page.waitForTimeout(800)
        await expect(editor).toBeVisible()
        await expect(input).toHaveValue('')
    })

    test('project: Limpar clears autocomplete selection and does not bounce back', async ({
        page,
    }) => {
        const edge = edgesByType.project
        const linkedName = `e2e-os558-dyn-linked-${Date.now()}`
        const linkedId = await createE2EProject(page, { name: linkedName })
        const editor = await openDynamicFormFastAttributeEditor(page, edge, [
            { id: linkedId, name: linkedName, code: 'E2E' },
        ])
        await requireFastAttributeClearButton(page, editor)

        const input = entitySearchInput(editor)
        await expect(input).toHaveValue(linkedName, { timeout: 10_000 })

        await clickLimpar(editor)
        await expect(editor).toBeVisible()
        await expect(input).toHaveValue('', { timeout: 5_000 })

        await page.waitForTimeout(800)
        await expect(editor).toBeVisible()
        await expect(input).toHaveValue('')
    })
})
