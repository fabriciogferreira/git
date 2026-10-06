import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { createE2EProject } from '../helpers/project'
import { openProjectOverview } from '../helpers/content-media'
import {
    descriptionHeaderItem,
    fastAttributeCancelButton,
    fastAttributeClearButton,
    fastAttributeEditor,
    fastAttributeSaveButton,
    openDescriptionFastAttributeEditor,
    requireFastAttributeClearButton,
    setProjectDescriptionViaApi,
} from '../helpers/fast-attribute-editor'

/**
 * OS-558 — Limpar on FastAttributeEditor (option A: clear draft, Salvar persists).
 *
 * Skips via requireVisible when Limpar is absent on the front under test.
 */
test.describe('OS-558 FastAttributeEditor Limpar', () => {
    test.describe.configure({ timeout: 90_000 })

    test('shows Limpar and clears the draft without closing', async ({ page }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-os558-clear-draft-${Date.now()}`,
        })
        const initial = `e2e-os558-clear-draft-${Date.now()}`
        await setProjectDescriptionViaApi(page, projectId, initial)

        const editor = await openDescriptionFastAttributeEditor(page, projectId)
        await requireFastAttributeClearButton(page, editor)

        const field = editor.locator('textarea, input').first()
        await expect(field).toHaveValue(initial)

        await fastAttributeClearButton(editor).click()
        await expect(field).toHaveValue('')
        await expect(editor).toBeVisible()
        await expect(fastAttributeCancelButton(editor)).toBeVisible()
        await expect(fastAttributeSaveButton(editor)).toBeVisible()
    })

    test('Limpar + Cancelar keeps the persisted description', async ({ page }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-os558-clear-cancel-${Date.now()}`,
        })
        const initial = `e2e-os558-clear-cancel-${Date.now()}`
        await setProjectDescriptionViaApi(page, projectId, initial)

        const editor = await openDescriptionFastAttributeEditor(page, projectId)
        await requireFastAttributeClearButton(page, editor)

        await fastAttributeClearButton(editor).click()
        await expect(editor.locator('textarea, input').first()).toHaveValue('')

        await fastAttributeCancelButton(editor).click()
        await expect(fastAttributeEditor(page)).toHaveCount(0, { timeout: 10_000 })

        const headerItem = descriptionHeaderItem(page)
        await expect(headerItem).toContainText(initial)
    })

    test('Limpar + Salvar persists empty description via PUT', async ({ page }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-os558-clear-save-${Date.now()}`,
        })
        const initial = `e2e-os558-clear-save-${Date.now()}`
        await setProjectDescriptionViaApi(page, projectId, initial)

        const editor = await openDescriptionFastAttributeEditor(page, projectId)
        await requireFastAttributeClearButton(page, editor)

        await fastAttributeClearButton(editor).click()
        await expect(editor.locator('textarea, input').first()).toHaveValue('')

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

        const body = response.request().postDataJSON() as {
            description?: string | null
        } | null
        // OS-558 clears free-text to '' (API description is string, not nullable).
        expect(body?.description === '' || body?.description === null).toBe(true)

        await expect(fastAttributeEditor(page)).toHaveCount(0, { timeout: 10_000 })

        const headerItem = descriptionHeaderItem(page)
        await expect(headerItem).not.toContainText(initial, { timeout: 15_000 })

        // Soft reload check — overview feed can flake under rate-limit; header already updated.
        try {
            await openProjectOverview(page, projectId)
            await expect(descriptionHeaderItem(page)).not.toContainText(initial, {
                timeout: 20_000,
            })
        } catch {
            await page.reload({ waitUntil: 'domcontentloaded' })
            await expect(descriptionHeaderItem(page)).not.toContainText(initial, {
                timeout: 20_000,
            })
        }
    })
})
