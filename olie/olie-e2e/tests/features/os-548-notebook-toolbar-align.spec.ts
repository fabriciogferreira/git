import { test, expect, type Page } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { createE2EProject, openProjectDetailsTab } from '../helpers/project'

/**
 * OS-548 — Caderno title and TipTap Bold icon must share the same left edge.
 * Resting toolbar buttons are transparent `btn-icon`; align the glyph, not the box.
 * Header uses Metronic `padding: 0 2.25rem`; toolbar uses `ps-5 pe-9` on BaseForum.
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

    test('title and first Bold icon share the same left edge', async ({ page }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-os548-align-${Date.now()}`,
        })
        await openOrCreateNotebook(page, projectId)

        const title = page.locator('.card-header .card-title').first()
        const boldIcon = page
            .locator('.toolbar-menu__items .floating-button-container button i.fa-bold')
            .first()

        await expect(title).toBeVisible()
        await expect(boldIcon).toBeVisible()

        const titleBox = await title.boundingBox()
        const iconBox = await boldIcon.boundingBox()

        expect(titleBox, 'OS-548: card title must have a layout box').not.toBeNull()
        expect(iconBox, 'OS-548: Bold icon must have a layout box').not.toBeNull()

        const delta = Math.abs((titleBox?.x ?? 0) - (iconBox?.x ?? 0))
        expect(
            delta,
            `OS-548: title left (${titleBox?.x}) and Bold icon left (${iconBox?.x}) should align (delta=${delta})`
        ).toBeLessThanOrEqual(2)
    })
})
