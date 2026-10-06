import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { createE2EProject } from '../helpers/project'
import { openProjectOverview } from '../helpers/content-media'
import {
    descriptionHeaderItem,
    fastAttributeCancelButton,
    fastAttributeEditor,
    fastAttributeSaveButton,
    fillFastAttributeTextarea,
    openDescriptionFastAttributeEditor,
    setProjectDescriptionViaApi,
} from '../helpers/fast-attribute-editor'

/**
 * OS-558 — baseline of FastAttributeEditor Cancelar/Salvar (shared surface).
 *
 * Uses project details header → Descrição (same `#fast_attribute_editor_container`
 * as kanban form-edge edits). Limpar presence is covered by the feature spec.
 */
test.describe('OS-558 FastAttributeEditor baseline', () => {
    test.describe.configure({ timeout: 90_000 })

    test('opens editor with Cancelar and Salvar', async ({ page }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-os558-baseline-open-${Date.now()}`,
        })
        const initial = `e2e-os558-open-${Date.now()}`
        await setProjectDescriptionViaApi(page, projectId, initial)

        const editor = await openDescriptionFastAttributeEditor(page, projectId)

        await expect(fastAttributeCancelButton(editor)).toBeVisible()
        await expect(fastAttributeSaveButton(editor)).toBeVisible()

        const field = editor.locator('textarea, input').first()
        await expect(field).toHaveValue(initial)
    })

    test('Cancelar discards edits and keeps the previous description', async ({
        page,
    }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-os558-baseline-cancel-${Date.now()}`,
        })
        const initial = `e2e-os558-cancel-keep-${Date.now()}`
        await setProjectDescriptionViaApi(page, projectId, initial)

        const editor = await openDescriptionFastAttributeEditor(page, projectId)
        const draft = `e2e-os558-cancel-draft-${Date.now()}`
        await fillFastAttributeTextarea(editor, draft)

        await fastAttributeCancelButton(editor).click()
        await expect(fastAttributeEditor(page)).toHaveCount(0, { timeout: 10_000 })

        const headerItem = descriptionHeaderItem(page)
        await expect(headerItem).toContainText(initial)
        await expect(headerItem).not.toContainText(draft)
    })

    test('Salvar persists the new description via PUT projects/{id}', async ({
        page,
    }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-os558-baseline-save-${Date.now()}`,
        })
        const initial = `e2e-os558-save-before-${Date.now()}`
        await setProjectDescriptionViaApi(page, projectId, initial)

        const editor = await openDescriptionFastAttributeEditor(page, projectId)
        const next = `e2e-os558-save-after-${Date.now()}`
        await fillFastAttributeTextarea(editor, next)

        const saveResponse = page.waitForResponse(
            r => {
                if (r.request().method() !== 'PUT') return false
                try {
                    return new URL(r.url()).pathname.endsWith(
                        `/projects/${projectId}`
                    )
                } catch {
                    return false
                }
            },
            { timeout: 30_000 }
        )

        await fastAttributeSaveButton(editor).click()
        const response = await saveResponse
        expect(response.status()).toBe(200)

        await expect(fastAttributeEditor(page)).toHaveCount(0, { timeout: 10_000 })

        const headerItem = descriptionHeaderItem(page)
        await expect(headerItem).toContainText(next, { timeout: 15_000 })
        await expect(headerItem).not.toContainText(initial)

        // Reload confirms persistence (not only optimistic UI).
        await openProjectOverview(page, projectId)
        await expect(descriptionHeaderItem(page)).toContainText(next, {
            timeout: 20_000,
        })
    })
})
