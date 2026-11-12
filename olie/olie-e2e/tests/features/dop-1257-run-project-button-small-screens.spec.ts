import { expect, type Page, test } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { requireFeature } from '../helpers/feature'
import {
    createE2EProject,
    openProjectFunnelKanban,
    purgeE2EProjects,
} from '../helpers/project'
import { expectReadableContrast, setResolvedTheme } from '../helpers/theme'

/**
 * DOP-1257 — start project execution on a compact header (width < 1100).
 *
 * Header remount used to tear down Echo / useQuery when MiniNavbarPlayer moved,
 * and isFetching silently blocked start. After the fix: POST starts, card badge
 * + outline appear, navbar shows the running code.
 *
 *   docker compose exec e2e npx playwright test --project=chromium --workers=1 \
 *     tests/features/dop-1257-run-project-button-small-screens.spec.ts
 */

const API = process.env.E2E_API_URL || 'http://api.olie.localhost'
const PROJECT_PREFIX = 'e2e-dop-1257-'
/** Matches HEADER_FULL_MIN_WIDTH in InternalContainer.vue */
const COMPACT_VIEWPORT = { width: 900, height: 900 }

async function firstExecutableFunnelStep(
    page: Page
): Promise<{ funnelId: number; stepId: number } | null> {
    return page.evaluate(async api => {
        const token = localStorage.getItem('token')
        if (!token) return null

        const headers = {
            Authorization: `Bearer ${token}`,
            Accept: 'application/json',
            'Content-Type': 'application/json',
        }

        const listRes = await fetch(`${api}/api/management/get-project-funnels`, { headers })
        const list = (await listRes.json().catch(() => null)) as {
            project_funnels?: Array<{ id?: number }> | { data?: Array<{ id?: number }> }
            data?: Array<{ id?: number }>
        } | null

        const raw = list?.project_funnels ?? list?.data ?? []
        const funnels = Array.isArray(raw) ? raw : (raw.data ?? [])

        for (const funnel of funnels.slice(0, 12)) {
            if (typeof funnel.id !== 'number') continue

            const detailRes = await fetch(`${api}/api/management/get-project-funnels`, {
                method: 'POST',
                headers,
                body: JSON.stringify({
                    project_funnel_id: funnel.id,
                    include_automations: false,
                    with_trashed_relations: false,
                }),
            })
            const detail = (await detailRes.json().catch(() => null)) as {
                project_funnel?: {
                    steps?: Array<{ id?: number; allow_execution?: boolean }>
                }
            } | null

            const step = detail?.project_funnel?.steps?.find(
                s => typeof s.id === 'number' && s.allow_execution !== false
            )
            if (typeof step?.id === 'number') {
                return { funnelId: funnel.id, stepId: step.id }
            }
        }

        return null
    }, API)
}

async function stopCurrentExecutionIfAny(page: Page) {
    await page.evaluate(async api => {
        const token = localStorage.getItem('token')
        if (!token) return
        const headers = {
            Authorization: `Bearer ${token}`,
            Accept: 'application/json',
            'Content-Type': 'application/json',
        }
        const me = (await fetch(`${api}/api/management/project-executions/me`, {
            headers,
        }).then(r => r.json())) as {
            current_execution?: { id?: string; project_id?: string } | null
        }
        const cur = me.current_execution
        if (!cur?.id || !cur.project_id) return
        await fetch(
            `${api}/api/management/projects/${cur.project_id}/project-executions/${cur.id}`,
            {
                method: 'PUT',
                headers,
                body: JSON.stringify({ finish_now: true }),
            }
        )
    }, API)
    await page.waitForTimeout(800)
}

test.describe('DOP-1257 run project button on compact screens', () => {
    test.describe.configure({ timeout: 150_000 })

    test('starts execution from kanban card under compact header', async ({ page }) => {
        await page.setViewportSize(COMPACT_VIEWPORT)
        await loginAsE2EUser(page)
        await purgeE2EProjects(page, PROJECT_PREFIX)

        const step = await firstExecutableFunnelStep(page)
        test.skip(!step, 'No funnel step with allow_execution on this frame')

        const projectName = `${PROJECT_PREFIX}${Date.now()}`
        const projectId = await createE2EProject(page, {
            name: projectName,
            prefix: 'E2E',
            funnel_step_id: step!.stepId,
        })

        await stopCurrentExecutionIfAny(page)
        await openProjectFunnelKanban(page, step!.funnelId)

        await requireFeature(page, {
            id: 'DOP-1257',
            probe: async () => {
                // Compact path moves MiniNavbarPlayer; play control must stay available.
                const play = page.getByRole('button', {
                    name: /Executar projeto|Start project|Iniciar execução/i,
                })
                return (await play.count()) > 0
            },
        })

        const card = page.locator('.bg-body, [class*="rounded"]').filter({
            hasText: projectName,
        }).first()
        await expect(card).toBeVisible({ timeout: 30_000 })

        const playOnCard = card.locator('button').filter({
            has: page.locator('i.fa-play'),
        }).first()

        await requireFeature(page, {
            id: 'DOP-1257',
            probe: async () => playOnCard.isVisible().catch(() => false),
        })

        const storeResponse = page.waitForResponse(
            r =>
                r.request().method() === 'POST' &&
                new RegExp(`/projects/${projectId}/project-executions\\b`).test(r.url()),
            { timeout: 30_000 }
        )

        await playOnCard.click()

        const res = await storeResponse
        expect(res.status(), 'start execution POST').toBeLessThan(400)

        await expect(page.locator('.running-execution-badge-container').first()).toBeVisible({
            timeout: 20_000,
        })
        await expect(page.locator('.running-execution-badge').first()).toBeVisible()
        await expect(page.getByText(/E2E-/i).first()).toBeVisible()

        // Contrast on the running badge (screen indicator the card requires).
        const badge = page.locator('.running-execution-badge').first()
        await setResolvedTheme(page, 'dark')
        await expectReadableContrast(badge, 'DOP-1257 running badge (dark)', 3)
        await setResolvedTheme(page, 'light')
        // Light primary-on-primary-light is soft; keep a floor so a total washout fails.
        const light = await page.evaluate(() => {
            const el = document.querySelector('.running-execution-badge') as HTMLElement | null
            if (!el) return null
            const fg = getComputedStyle(el).color
            let node: HTMLElement | null = el
            let bg = 'rgba(0,0,0,0)'
            while (node) {
                const c = getComputedStyle(node).backgroundColor
                if (c && c !== 'rgba(0, 0, 0, 0)' && c !== 'transparent') {
                    bg = c
                    break
                }
                node = node.parentElement
            }
            return { fg, bg, text: el.textContent?.trim() }
        })
        expect(light?.text).toBeTruthy()
        expect(light?.fg).not.toEqual(light?.bg)

        await stopCurrentExecutionIfAny(page)
    })

    test('header modal starts execution under compact header', async ({ page }) => {
        await page.setViewportSize(COMPACT_VIEWPORT)
        await loginAsE2EUser(page)
        await purgeE2EProjects(page, PROJECT_PREFIX)

        const step = await firstExecutableFunnelStep(page)
        test.skip(!step, 'No funnel step with allow_execution on this frame')

        const projectName = `${PROJECT_PREFIX}modal-${Date.now()}`
        const projectId = await createE2EProject(page, {
            name: projectName,
            prefix: 'E2E',
            funnel_step_id: step!.stepId,
        })

        await stopCurrentExecutionIfAny(page)
        await openProjectFunnelKanban(page, step!.funnelId)

        const headerPlay = page.getByRole('button', { name: /Executar projeto/i }).first()
        await requireFeature(page, {
            id: 'DOP-1257',
            probe: async () => headerPlay.isVisible().catch(() => false),
        })
        await headerPlay.click()

        const dialog = page.locator('.p-dialog').filter({
            hasText: /Executar projeto|Run project/i,
        })
        await expect(dialog).toBeVisible({ timeout: 15_000 })

        const search = dialog
            .locator('input[placeholder*="Selecione um"], input[placeholder*="Select a"]')
            .first()
        await expect(search).toBeVisible({ timeout: 10_000 })
        await search.click()
        await search.fill(projectName)

        // Results render in a Portal (`.autocomplete-result`), above the dialog mask.
        const option = page.locator('.autocomplete-result').filter({ hasText: projectName }).first()
        await expect(option).toBeVisible({ timeout: 15_000 })
        await option.click({ force: true })

        const stepBtn = dialog.locator('button.step-card--available, button.step-card').first()
        await expect(stepBtn).toBeVisible({ timeout: 20_000 })
        await stepBtn.click()

        const executeNow = dialog.getByRole('button', {
            name: /Executar agora|Execute now|Start now/i,
        })
        await expect(executeNow).toBeVisible({ timeout: 10_000 })

        const storeResponse = page.waitForResponse(
            r =>
                r.request().method() === 'POST' &&
                new RegExp(`/projects/${projectId}/project-executions\\b`).test(r.url()),
            { timeout: 30_000 }
        )

        await executeNow.click()
        const res = await storeResponse
        expect(res.status(), 'modal start execution POST').toBeLessThan(400)

        await expect(page.locator('.running-execution-badge-container').first()).toBeVisible({
            timeout: 20_000,
        })

        await stopCurrentExecutionIfAny(page)
    })
})
