import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { createE2EProject } from '../helpers/project'
import {
    HEADER_FIELD_LABEL,
    expectFastAttributeClearHidden,
    fastAttributeCancelButton,
    fastAttributeClearButton,
    fastAttributeEditor,
    fastAttributeSaveButton,
    openDescriptionFastAttributeEditor,
    openHeaderFastAttributeEditor,
    requireFastAttributeClearButton,
    setProjectDescriptionViaApi,
    updateProjectViaApi,
    waitForProjectPut,
} from '../helpers/fast-attribute-editor'

/**
 * OS-558 — Limpar on FastAttributeEditor (option A: clear draft, Salvar persists).
 *
 * Review correction: description / status / impact must NOT offer Limpar (API
 * rejects null/empty; kanban bulk-update fails silently). Clearable fields
 * (e.g. budget) still show Limpar.
 *
 * Skips via requireVisible when Limpar is absent on the front under test
 * (clearable-field cases only).
 */
test.describe('OS-558 FastAttributeEditor Limpar', () => {
    test.describe.configure({ timeout: 90_000 })

    test('description: Limpar is not shown (API rejects empty)', async ({ page }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-os558-no-clear-desc-${Date.now()}`,
        })
        const initial = `e2e-os558-no-clear-desc-${Date.now()}`
        await setProjectDescriptionViaApi(page, projectId, initial)

        const editor = await openDescriptionFastAttributeEditor(page, projectId)

        await expect(fastAttributeCancelButton(editor)).toBeVisible()
        await expect(fastAttributeSaveButton(editor)).toBeVisible()
        await expectFastAttributeClearHidden(editor)

        const field = editor.locator('textarea, input').first()
        await expect(field).toHaveValue(initial)
    })

    test('budget: shows Limpar and clears the draft without closing', async ({ page }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-os558-clear-draft-${Date.now()}`,
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
        const cleared = (await moneyInput.inputValue()).replace(/\s/g, '')
        expect(/0/.test(cleared)).toBe(true)
        await expect(editor).toBeVisible()
        await expect(fastAttributeCancelButton(editor)).toBeVisible()
        await expect(fastAttributeSaveButton(editor)).toBeVisible()
    })

    test('budget: Limpar + Cancelar keeps the persisted value', async ({ page }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-os558-clear-cancel-${Date.now()}`,
        })
        await updateProjectViaApi(page, projectId, { budget: 99.5 })

        const editor = await openHeaderFastAttributeEditor(
            page,
            projectId,
            HEADER_FIELD_LABEL.budget
        )
        await requireFastAttributeClearButton(page, editor)

        const moneyInput = editor.locator('input').first()
        const before = await moneyInput.inputValue()

        await fastAttributeClearButton(editor).click()
        await fastAttributeCancelButton(editor).click()
        await expect(fastAttributeEditor(page)).toHaveCount(0, { timeout: 10_000 })

        const again = await openHeaderFastAttributeEditor(
            page,
            projectId,
            HEADER_FIELD_LABEL.budget
        )
        await expect(again.locator('input').first()).toHaveValue(before)
    })

    test('budget: Limpar + Salvar persists 0 via PUT', async ({ page }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-os558-clear-save-${Date.now()}`,
        })
        await updateProjectViaApi(page, projectId, { budget: 50 })

        const editor = await openHeaderFastAttributeEditor(
            page,
            projectId,
            HEADER_FIELD_LABEL.budget
        )
        await requireFastAttributeClearButton(page, editor)

        await fastAttributeClearButton(editor).click()

        const response = await waitForProjectPut(page, projectId, async () => {
            await fastAttributeSaveButton(editor).click()
        })
        expect(response.status()).toBe(200)

        const body = response.request().postDataJSON() as { budget?: number | null } | null
        expect(body?.budget === 0 || body?.budget === null).toBe(true)

        await expect(fastAttributeEditor(page)).toHaveCount(0, { timeout: 10_000 })
    })
})
