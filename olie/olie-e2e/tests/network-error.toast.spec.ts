import { test, expect, type Page } from '@playwright/test'
import { loginAsE2EUser } from './helpers/auth'
import { createE2EProject, openProjectDetailsTab } from './helpers/project'

/**
 * OS-549 — notebook must NOT toast `network_error` on `save-thread-data`
 * CORS/network-looking blips (Chrome empty response / `ERR_FAILED` /
 * `ERR_NETWORK`; Axios: no `response`).
 *
 * Call decision (2026-09-29): do NOT touch global axios interceptors/retry.
 * Fix is local to notebook save: retry once, never FireErrorMessage for
 * network/CORS failures (draft stays "Não salvo").
 *
 * Playwright cannot synthesize a true CORS console code, but
 * `route.abort('failed')` hits the same Axios path as a blocked cross-origin
 * response (no body, `ERR_NETWORK` / Network Error).
 */

const NETWORK_TOAST =
    /Houve uma falha na conexão, verifique sua rede\.|There was a connection failure, please check your network\./i

async function openOrCreateNotebook(page: Page, projectId: string) {
    await openProjectDetailsTab(page, projectId, 'forum')

    const createBtn = page.getByRole('button', { name: /Criar caderno|Create notebook/i })
    if (await createBtn.isVisible({ timeout: 5_000 }).catch(() => false)) {
        await createBtn.click()
    }

    await expect(page.locator('.ProseMirror').last()).toBeVisible({ timeout: 30_000 })
}

async function typeNotebookDraft(page: Page, text: string) {
    const prose = page.locator('.ProseMirror').last()
    await prose.click()
    await page.keyboard.type(text, { delay: 10 })
    await expect(prose).toContainText(text)
}

async function clickNotebookSave(page: Page) {
    const save = page.getByRole('button', { name: /Salvar|Save/i }).filter({
        hasNot: page.locator('.fa-paper-plane'),
    })
    await expect(save.first()).toBeEnabled({ timeout: 10_000 })
    await save.first().click()
}

test.describe('OS-549 notebook save-thread-data', () => {
    test.describe.configure({ timeout: 120_000 })

    test('retries once when save-thread-data fails with a CORS-like network abort', async ({
        page,
    }) => {
        let armed = false
        let attempts = 0

        await page.route('**/save-thread-data/**', async route => {
            if (!armed || route.request().method() !== 'POST') {
                await route.continue()
                return
            }

            attempts += 1
            if (attempts === 1) {
                // Same class of failure as intermittent CORS / CF block: no response body.
                await route.abort('failed')
                return
            }
            await route.continue()
        })

        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-os549-save-${Date.now()}`,
        })
        await openOrCreateNotebook(page, projectId)

        armed = true
        attempts = 0

        await typeNotebookDraft(page, `os549-retry-${Date.now()}`)
        await clickNotebookSave(page)

        await expect
            .poll(() => attempts, {
                timeout: 15_000,
                message:
                    'OS-549: one Save click must POST save-thread-data twice (fail + retry). Without notebook-local retry this stays 1.',
            })
            .toBe(2)

        await expect(page.getByText(NETWORK_TOAST)).toHaveCount(0)
        await expect(page.getByText(/Salvo|Saved/i).first()).toBeVisible({ timeout: 10_000 })
    })

    test('does not toast when save-thread-data keeps failing — stays unsaved', async ({
        page,
    }) => {
        let armed = false

        await page.route('**/save-thread-data/**', async route => {
            if (!armed || route.request().method() !== 'POST') {
                await route.continue()
                return
            }
            await route.abort('failed')
        })

        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-os549-fail-${Date.now()}`,
        })
        await openOrCreateNotebook(page, projectId)

        armed = true
        await typeNotebookDraft(page, `os549-fail-${Date.now()}`)
        await clickNotebookSave(page)

        // Must fail fast: default toHaveCount(0) can wait until a toast timer hides it.
        const toastAppeared = await page
            .getByText(NETWORK_TOAST)
            .waitFor({ state: 'visible', timeout: 3_000 })
            .then(() => true)
            .catch(() => false)

        expect(toastAppeared, 'OS-549: notebook save must not toast network_error').toBe(false)
        await expect(page.getByText(/Não salvo|Unsaved/i).first()).toBeVisible({ timeout: 5_000 })
    })
})
