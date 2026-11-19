import { test, expect, type Page } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { createE2EProject, openProjectDetailsTab } from '../helpers/project'
import { requireVisible } from '../helpers/feature'

/**
 * DOP-1276 — Print a Caderno page (clean print view + browser print dialog).
 *
 * Covers: re-enabled "Imprimir página", popup route `/forum-print/...`,
 * TipTap content visible without editor chrome, and `window.print()` after load.
 *
 * Skips when the print menu item is still disabled (front without this branch).
 */

const PRINT_LABEL = /Imprimir página|Print page/i
const SAMPLE = `DOP-1276 print sample ${Date.now()}`

async function dismissBlockingUi(page: Page) {
    for (const name of [/Continuar com limitações/i, /^Fechar$/i, /^OK$/i]) {
        const btn = page.getByRole('button', { name })
        if (await btn.first().isVisible({ timeout: 500 }).catch(() => false)) {
            await btn.first().click().catch(() => undefined)
            await page.waitForTimeout(300)
        }
    }
}

async function openOrCreateNotebook(page: Page, projectId: string) {
    for (let attempt = 1; attempt <= 3; attempt++) {
        await openProjectDetailsTab(page, projectId, 'forum')
        await dismissBlockingUi(page)

        const loadError = page.getByText(/error_loading_forum|Erro ao carregar o caderno/i)
        if (await loadError.isVisible({ timeout: 1_500 }).catch(() => false)) {
            if (attempt === 3) break
            await page.waitForTimeout(2_000 * attempt)
            continue
        }

        // Empty notebook CTA — click can miss if the card is still settling.
        const createBtn = page.getByRole('button', { name: /Criar caderno|Create notebook/i })
        if (await createBtn.isVisible({ timeout: 8_000 }).catch(() => false)) {
            await createBtn.scrollIntoViewIfNeeded()
            await createBtn.click({ force: true })
            await expect(createBtn).toBeHidden({ timeout: 20_000 }).catch(() => undefined)
        }

        try {
            await expect(page.locator('.ProseMirror').last()).toBeVisible({ timeout: 30_000 })
            return
        } catch (error) {
            if (attempt === 3) throw error
            await page.waitForTimeout(2_000 * attempt)
        }
    }

    await expect(page.locator('.ProseMirror').last()).toBeVisible({ timeout: 30_000 })
}

async function openThreadOptionsMenu(page: Page) {
    const candidates = page.locator('button, a').filter({
        has: page.locator(
            '.fa-ellipsis-h, .fa-ellipsis-v, .fa-ellipsis, .bi-three-dots, .bi-three-dots-vertical'
        ),
    })

    const count = await candidates.count()
    for (let i = 0; i < count; i++) {
        const candidate = candidates.nth(i)
        if (!(await candidate.isVisible().catch(() => false))) continue

        await candidate.click()
        await page.waitForTimeout(300)

        if (await page.getByText(PRINT_LABEL).first().isVisible().catch(() => false)) {
            return
        }

        await page.keyboard.press('Escape')
    }

    throw new Error('DOP-1276: could not open thread options menu with print action')
}

test.describe('DOP-1276 notebook page print', () => {
    test.describe.configure({ timeout: 120_000 })

    test('Imprimir página opens clean print view and calls window.print', async ({
        page,
        context,
    }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-dop-1276-print-${Date.now()}`,
        })
        await openOrCreateNotebook(page, projectId)

        const prose = page.locator('.ProseMirror').last()
        await prose.click()
        await page.keyboard.press('Control+A')
        await page.keyboard.type(SAMPLE, { delay: 8 })
        await expect(prose).toContainText(SAMPLE)

        await openThreadOptionsMenu(page)

        const printItem = page.getByText(PRINT_LABEL).first()
        await requireVisible(page, 'DOP-1276', printItem, 8_000)

        const printMeta = await printItem.evaluate(el => {
            const btn = (el.closest('button') || el) as HTMLButtonElement
            const cs = getComputedStyle(btn)
            return {
                opacity: cs.opacity,
                disabled: Boolean(btn.disabled || btn.getAttribute('disabled')),
                className: btn.className,
            }
        })
        expect(printMeta.disabled, 'print menu item must be enabled').toBe(false)
        expect(Number(printMeta.opacity), 'print menu item must not look disabled').toBeGreaterThan(
            0.9
        )
        expect(printMeta.className).not.toMatch(/opacity-25/)

        await context.addInitScript(() => {
            ;(window as unknown as { __printCalls?: number }).__printCalls = 0
            const stub = () => {
                const w = window as unknown as { __printCalls?: number }
                w.__printCalls = (w.__printCalls || 0) + 1
            }
            try {
                window.print = stub
            } catch {
                /* ignore */
            }
            document.addEventListener('DOMContentLoaded', () => {
                try {
                    window.print = stub
                } catch {
                    /* ignore */
                }
            })
        })

        const popupPromise = context.waitForEvent('page', { timeout: 20_000 })
        await printItem.click()
        const popup = await popupPromise

        await expect(popup).toHaveURL(/\/forum-print\//, { timeout: 20_000 })
        await expect(popup.locator('.ProseMirror, .tiptap').last()).toBeVisible({
            timeout: 30_000,
        })
        await expect(popup.locator('body')).toContainText(SAMPLE, { timeout: 15_000 })

        await expect(popup.locator('.toolbar-menu')).toHaveCount(0)
        await expect(popup.locator('.forum-print__action')).toBeVisible()

        await expect
            .poll(async () => popup.evaluate(() => (window as unknown as { __printCalls?: number }).__printCalls || 0), {
                timeout: 15_000,
            })
            .toBeGreaterThan(0)

        const surface = await popup.evaluate(() => {
            const root = document.querySelector('.forum-print') || document.body
            const cs = getComputedStyle(root)
            return { bg: cs.backgroundColor, color: cs.color }
        })
        expect(surface.bg).toMatch(/rgb\(255,\s*255,\s*255\)/)
        expect(surface.color).toMatch(/rgb\((0|17),\s*(0|17),\s*(0|17)\)/)

        const printCss = await popup.evaluate(() => {
            let hideAction = false
            let breakInside = false
            for (const sheet of [...document.styleSheets]) {
                let rules: CSSRuleList
                try {
                    rules = sheet.cssRules
                } catch {
                    continue
                }
                for (const rule of [...rules]) {
                    if (!(rule instanceof CSSMediaRule) || !/print/i.test(rule.media.mediaText)) {
                        continue
                    }
                    for (const nested of [...rule.cssRules]) {
                        const text = nested.cssText
                        if (
                            /forum-print__action/.test((nested as CSSStyleRule).selectorText || '') &&
                            /display:\s*none/i.test(text)
                        ) {
                            hideAction = true
                        }
                        if (/break-inside:\s*avoid|page-break-inside:\s*avoid/i.test(text)) {
                            breakInside = true
                        }
                    }
                }
            }
            return { hideAction, breakInside }
        })
        expect(printCss.hideAction, '@media print must hide print action button').toBe(true)
        expect(printCss.breakInside, '@media print must avoid splitting images/tables').toBe(true)
    })
})
