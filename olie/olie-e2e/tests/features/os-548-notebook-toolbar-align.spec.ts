import { test, expect, type Page } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { createE2EProject, openProjectDetailsTab } from '../helpers/project'

/**
 * OS-548 — Caderno title and TipTap toolbar options must share the same left edge.
 * Header uses Metronic `padding: 0 2.25rem`; toolbar previously used `0.25rem`.
 */

async function openOrCreateNotebook(page: Page, projectId: string) {
    // Same retry pattern as DOP-1262: transient get-forum blips show error_loading_forum.
    for (let attempt = 1; attempt <= 3; attempt++) {
        await openProjectDetailsTab(page, projectId, 'forum')

        const loadError = page.getByText(/error_loading_forum|Erro ao carregar o caderno/i)
        if (await loadError.isVisible({ timeout: 1_500 }).catch(() => false)) {
            if (attempt === 3) break
            await page.waitForTimeout(2_000 * attempt)
            continue
        }

        const createBtn = page.getByRole('button', { name: /Criar caderno|Create notebook/i })
        if (await createBtn.isVisible({ timeout: 5_000 }).catch(() => false)) {
            await createBtn.click()
        }

        try {
            await expect(page.locator('.toolbar-menu').first()).toBeVisible({ timeout: 30_000 })
            return
        } catch (error) {
            if (attempt === 3) throw error
            await page.waitForTimeout(2_000 * attempt)
        }
    }

    throw new Error('OS-548: could not open or create notebook after retries')
}

test.describe('OS-548 notebook title/toolbar alignment', () => {
    test.describe.configure({ timeout: 120_000 })

    test('title and first toolbar option share the same left edge', async ({ page }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-os548-align-${Date.now()}`,
        })
        await openOrCreateNotebook(page, projectId)

        const title = page.locator('.card-header .card-title').first()
        const firstToolbarBtn = page
            .locator('.toolbar-menu__items .floating-button-container button')
            .first()

        await expect(title).toBeVisible()
        await expect(firstToolbarBtn).toBeVisible()

        const titleBox = await title.boundingBox()
        const btnBox = await firstToolbarBtn.boundingBox()

        expect(titleBox, 'OS-548: card title must have a layout box').not.toBeNull()
        expect(btnBox, 'OS-548: first toolbar button must have a layout box').not.toBeNull()

        const delta = Math.abs((titleBox?.x ?? 0) - (btnBox?.x ?? 0))
        expect(
            delta,
            `OS-548: title left (${titleBox?.x}) and toolbar button left (${btnBox?.x}) should align (delta=${delta})`
        ).toBeLessThanOrEqual(2)
    })
})
