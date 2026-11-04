import { test, expect, type Page } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { createE2EProject, openProjectDetailsTab } from '../helpers/project'
import { requireVisible } from '../helpers/feature'

/**
 * DOP-1262 — Caderno pages stored as DB revisions with conflict handling.
 *
 * Covers: last-updated stamp + history list, concurrent-save conflict
 * (keep local edits), restore from history, and waiting for an in-flight save.
 *
 * Skips when the Histórico control is missing (front without this branch).
 */

const CONFLICT_TITLE =
    /A página foi alterada por outra pessoa|The page was changed by someone else/i
const KEEP_EDITS_BTN = /Sobrescrever|Overwrite|Manter minhas edições|Keep my edits/i
const RELOAD_BTN = /Recarregar|Reload|descartar minhas alterações|discard/i
const HISTORY_BTN = /Histórico|History/i
const RESTORE_BTN = /Restaurar esta versão|Restore this version/i
const SAVE_BTN = /Salvar|Save/i

function apiHostFromPage(page: Page) {
    return page.evaluate(() => {
        const hostParts = window.location.hostname.split('.')
        return `api.${hostParts.slice(-2).join('.')}`
    })
}

async function openOrCreateNotebook(page: Page, projectId: string) {
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
            await expect(page.locator('.ProseMirror').last()).toBeVisible({ timeout: 30_000 })
            return
        } catch (error) {
            if (attempt === 3) throw error
            await page.waitForTimeout(2_000 * attempt)
        }
    }

    await expect(page.locator('.ProseMirror').last()).toBeVisible({ timeout: 30_000 })
}

async function requireNotebookRevisionUi(page: Page) {
    await requireVisible(page, 'DOP-1262', page.getByRole('button', { name: HISTORY_BTN }), 12_000)
}

async function typeNotebookDraft(page: Page, text: string) {
    const prose = page.locator('.ProseMirror').last()
    await prose.click()
    await page.keyboard.press('Control+A')
    await page.keyboard.type(text, { delay: 8 })
    await expect(prose).toContainText(text)
}

async function clickNotebookSave(page: Page) {
    const save = page.getByRole('button', { name: SAVE_BTN }).filter({
        hasNot: page.locator('.fa-paper-plane'),
    })
    await expect(save.first()).toBeEnabled({ timeout: 10_000 })
    await save.first().click()
}

async function waitUntilSaved(page: Page) {
    await expect(page.getByText(/Salvo|Saved/i).first()).toBeVisible({ timeout: 15_000 })
}

async function notebookIds(page: Page) {
    const apiHost = await apiHostFromPage(page)
    return page.evaluate(async apiHost => {
        const token = localStorage.getItem('token')
        const projectId = window.location.pathname.match(/\/projects\/([^/]+)/)?.[1]
        const forumRes = await fetch(`${window.location.protocol}//${apiHost}/api/management/get-forum`, {
            method: 'POST',
            headers: {
                Authorization: `Bearer ${token}`,
                'Content-Type': 'application/json',
                Accept: 'application/json',
            },
            body: JSON.stringify({
                model_class: 'App\\Models\\Project',
                model_id: projectId,
            }),
        })
        const forumData = await forumRes.json()
        const forum = forumData.forum
        const threadId = forum?.default_thread_id ?? forum?.threads?.[0]?.id
        const contentRes = await fetch(
            `${window.location.protocol}//${apiHost}/api/management/forums/${forum.id}/threads/${threadId}/content`,
            {
                headers: {
                    Authorization: `Bearer ${token}`,
                    Accept: 'application/json',
                },
            }
        )
        const contentData = await contentRes.json()
        return {
            forumId: forum.id as string,
            threadId: String(threadId),
            revision: Number(contentData.content.revision),
        }
    }, apiHost)
}

/** PUT full doc (management save always uses source=ui). */
async function putNotebookDoc(
    page: Page,
    args: { forumId: string; threadId: string; baseRevision: number; text: string }
) {
    const apiHost = await apiHostFromPage(page)
    return page.evaluate(
        async ({ apiHost, forumId, threadId, baseRevision, text }) => {
            const token = localStorage.getItem('token')
            const res = await fetch(
                `${window.location.protocol}//${apiHost}/api/management/forums/${forumId}/threads/${threadId}/content`,
                {
                    method: 'PUT',
                    headers: {
                        Authorization: `Bearer ${token}`,
                        'Content-Type': 'application/json',
                        Accept: 'application/json',
                    },
                    body: JSON.stringify({
                        base_revision: baseRevision,
                        doc: {
                            type: 'doc',
                            content: [
                                {
                                    type: 'paragraph',
                                    content: [{ type: 'text', text }],
                                },
                            ],
                        },
                    }),
                }
            )
            return { status: res.status, body: await res.json().catch(() => null) }
        },
        { apiHost, ...args }
    )
}

/**
 * PATCH insert uses source=api, so it does not coalesce with a prior UI save
 * and leaves a second history entry for restore tests.
 */
async function patchInsertEnd(
    page: Page,
    args: { forumId: string; threadId: string; baseRevision: number; markdown: string }
) {
    const apiHost = await apiHostFromPage(page)
    return page.evaluate(
        async ({ apiHost, forumId, threadId, baseRevision, markdown }) => {
            const token = localStorage.getItem('token')
            const res = await fetch(
                `${window.location.protocol}//${apiHost}/api/management/forums/${forumId}/threads/${threadId}/content`,
                {
                    method: 'PATCH',
                    headers: {
                        Authorization: `Bearer ${token}`,
                        'Content-Type': 'application/json',
                        Accept: 'application/json',
                    },
                    body: JSON.stringify({
                        base_revision: baseRevision,
                        operations: [{ type: 'insert_blocks', position: 'end', markdown }],
                    }),
                }
            )
            return { status: res.status, body: await res.json().catch(() => null) }
        },
        { apiHost, ...args }
    )
}

function historyMenu(page: Page) {
    return page.locator('.dropstart').filter({
        has: page.getByRole('button', { name: HISTORY_BTN }),
    })
}

test.describe('DOP-1262 notebook revisions', () => {
    // Forum create + save is sensitive to parallel API pressure on this VM.
    test.describe.configure({ timeout: 180_000, mode: 'serial' })

    test('shows last-updated stamp and lists revisions after save', async ({ page }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-dop1262-stamp-${Date.now()}`,
        })
        await openOrCreateNotebook(page, projectId)
        await requireNotebookRevisionUi(page)

        const marker = `dop1262-stamp-${Date.now()}`
        await typeNotebookDraft(page, marker)
        await clickNotebookSave(page)
        await waitUntilSaved(page)

        await expect(page.locator('.ProseMirror').last()).toContainText(marker)
        // Toolbar stamp (moment.fromNow) — avoid matching hidden dates inside the history menu.
        await expect(
            page
                .locator('.card .card-body')
                .locator('small.text-muted')
                .filter({ hasText: /há |ago|segundo|minut|hora|few|just now|agora/i })
                .first()
        ).toBeVisible({ timeout: 10_000 })

        await page.getByRole('button', { name: HISTORY_BTN }).click()
        await expect(historyMenu(page).getByText(/Histórico de versões|Version history/i)).toBeVisible()
        await expect(historyMenu(page).locator('.dropdown-item').first()).toBeVisible({
            timeout: 10_000,
        })
    })

    test('conflict dialog lets the user keep local edits', async ({ page }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-dop1262-conflict-${Date.now()}`,
        })
        await openOrCreateNotebook(page, projectId)
        await requireNotebookRevisionUi(page)

        const first = `dop1262-a-${Date.now()}`
        await typeNotebookDraft(page, first)
        await clickNotebookSave(page)
        await waitUntilSaved(page)

        const ids = await notebookIds(page)
        const foreign = `dop1262-foreign-${Date.now()}`
        const putForeign = await putNotebookDoc(page, {
            forumId: ids.forumId,
            threadId: ids.threadId,
            baseRevision: ids.revision,
            text: foreign,
        })
        expect(putForeign.status, JSON.stringify(putForeign.body)).toBe(200)

        // Tab still holds the pre-foreign base_revision in memory.
        const local = `dop1262-local-${Date.now()}`
        await typeNotebookDraft(page, local)
        await clickNotebookSave(page)

        const dialog = page.locator('.swal2-popup')
        await expect(dialog.getByText(CONFLICT_TITLE)).toBeVisible({ timeout: 15_000 })
        await expect(dialog.getByRole('button', { name: KEEP_EDITS_BTN })).toBeVisible()
        await expect(dialog.getByRole('button', { name: RELOAD_BTN })).toBeVisible()

        await dialog.getByRole('button', { name: KEEP_EDITS_BTN }).click()
        await waitUntilSaved(page)
        await expect(page.locator('.ProseMirror').last()).toContainText(local)
    })

    test('history restore brings back an older revision', async ({ page }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-dop1262-restore-${Date.now()}`,
        })
        await openOrCreateNotebook(page, projectId)
        await requireNotebookRevisionUi(page)

        const v1 = `dop1262-v1-${Date.now()}`
        await typeNotebookDraft(page, v1)
        await clickNotebookSave(page)
        await waitUntilSaved(page)

        const ids = await notebookIds(page)
        const v2 = `dop1262-v2-${Date.now()}`
        const patched = await patchInsertEnd(page, {
            forumId: ids.forumId,
            threadId: ids.threadId,
            baseRevision: ids.revision,
            markdown: v2,
        })
        expect(patched.status, JSON.stringify(patched.body)).toBe(200)

        // Reload so the editor shows v2 and history includes UI + API snapshots.
        await openOrCreateNotebook(page, projectId)
        await requireNotebookRevisionUi(page)
        await expect(page.locator('.ProseMirror').last()).toContainText(v2, { timeout: 20_000 })

        const revisionsResponse = page.waitForResponse(
            res =>
                res.request().method() === 'GET' &&
                /\/forums\/[^/]+\/threads\/[^/]+\/revisions/.test(res.url()) &&
                res.ok()
        )
        await page.getByRole('button', { name: HISTORY_BTN }).click()
        const revBody = (await (await revisionsResponse).json()) as {
            revisions?: unknown[]
            response?: boolean
        }
        expect(revBody.response).toBe(true)
        expect(
            (revBody.revisions ?? []).length,
            `revisions payload: ${JSON.stringify(revBody)}`
        ).toBeGreaterThanOrEqual(2)

        const items = historyMenu(page).locator('.dropdown-item')
        await expect(items.first()).toBeVisible({ timeout: 10_000 })
        const count = await items.count()
        expect(count, 'expected at least two revisions after UI + API edit').toBeGreaterThanOrEqual(2)

        // Newest first — oldest listed item should restore toward v1.
        await items.nth(count - 1).click()
        await expect(
            page.getByText(/versão anterior|older version|somente leitura|read-only/i)
        ).toBeVisible({ timeout: 15_000 })

        await page.getByRole('button', { name: RESTORE_BTN }).click()
        const confirm = page.locator('.swal2-popup')
        await expect(confirm.getByRole('button', { name: RESTORE_BTN })).toBeVisible()
        await confirm.getByRole('button', { name: RESTORE_BTN }).click()

        await expect(
            page.getByText(/versão anterior|older version|somente leitura|read-only/i)
        ).toHaveCount(0, { timeout: 15_000 })
        await expect(page.locator('.ProseMirror').last()).toContainText(v1, { timeout: 15_000 })
        await expect(page.locator('.ProseMirror').last()).not.toContainText(v2)
    })

    test('leaving the page waits for an in-flight save', async ({ page }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-dop1262-inflight-${Date.now()}`,
        })
        await openOrCreateNotebook(page, projectId)
        await requireNotebookRevisionUi(page)

        let release: (() => void) | null = null
        const gate = new Promise<void>(resolve => {
            release = resolve
        })

        await page.route('**/forums/**/threads/**/content', async route => {
            if (route.request().method() !== 'PUT') {
                await route.continue()
                return
            }
            await gate
            await route.continue()
        })

        const marker = `dop1262-inflight-${Date.now()}`
        await typeNotebookDraft(page, marker)
        await clickNotebookSave(page)

        // Click the Resumo/Overview project tab (vue-router) while the PUT is held.
        const overviewTab = page.locator('.nav-line-tabs .nav-link').filter({
            hasText: /Resumo|Overview/i,
        })
        await expect(overviewTab).toBeVisible({ timeout: 10_000 })
        // Saving indicator proves the PUT is in flight (route is holding it).
        await expect(page.getByText(/Salvando alterações|Saving changes/i)).toBeVisible({
            timeout: 5_000,
        })
        const navDone = page.waitForURL(new RegExp(`/projects/${projectId}/details/overview`), {
            timeout: 30_000,
        })
        await overviewTab.click()
        await page.waitForTimeout(800)
        // In-flight-only dirty state must not open the unsaved-changes SweetAlert.
        await expect(page.getByText(/Alterações não salvas|Unsaved changes/i)).toHaveCount(0)
        release?.()
        await navDone

        await openOrCreateNotebook(page, projectId)
        await expect(page.locator('.ProseMirror').last()).toContainText(marker, { timeout: 20_000 })
    })
})



