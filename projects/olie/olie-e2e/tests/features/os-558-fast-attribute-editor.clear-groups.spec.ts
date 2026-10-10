import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { createE2EProject } from '../helpers/project'
import {
    HEADER_FIELD_LABEL,
    createE2EProjectGroup,
    fastAttributeClearButton,
    fastAttributeEditor,
    fastAttributeSaveButton,
    headerItemByLabel,
    openHeaderFastAttributeEditor,
    requireFastAttributeClearButton,
    updateProjectViaApi,
    waitForProjectPut,
} from '../helpers/fast-attribute-editor'

/**
 * OS-558 — Groups Limpar must mark linked groups for removal (to_rem), not only
 * clear the MultiSelect UI. Regression for emptyValueForClear / Diffs xor skip.
 */
test.describe('OS-558 FastAttributeEditor Limpar — groups', () => {
    test.describe.configure({ timeout: 120_000 })

    test('Limpar+Salvar sends groups.to_rem with the linked group id', async ({ page }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-os558-groups-to-rem-${Date.now()}`,
        })
        const group = await createE2EProjectGroup(
            page,
            `e2e-os558-groups-to-rem-${Date.now()}`
        )
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
        await expect(multi.getByText(group.name)).toHaveCount(0)
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
})
