import { test, expect, type Page, type Request } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import {
    createE2EProject,
    openProjectFunnelKanban,
    purgeE2EProjects,
} from '../helpers/project'

/**
 * DOP-1239 — visual sort on a kanban column was dropped on lazy scroll.
 *
 * The column id comes from dataset.stepId (string). The in-memory sort stores
 * a numeric step_id. Strict equality made the next page post sorting: null,
 * so the API ignored the order the user had just chosen.
 *
 * Real login against api-main. The local RECAPTCHA_SECRET must be Google's
 * test secret (see ~/git/olie/prompts/workflow-policy.md). Shared seed:
 *   docker compose exec e2e npx playwright test --project=chromium --workers=1 \
 *     tests/features/dop-1239-manual-step-sort-scroll.spec.ts
 */

const API = process.env.E2E_API_URL || 'http://api.olie.localhost'
const PROJECT_PREFIX = 'e2e-dop-1239-'

type StepPayload = {
    id: number | string
    offset?: number
    sorting?: { field?: string; direction?: string } | null
}

function stepFromRequest(request: Request, stepId: number): StepPayload | null {
    if (request.method() !== 'POST' || !request.url().includes('/get-step-data')) {
        return null
    }

    let body: { steps?: StepPayload[] }
    try {
        body = request.postDataJSON()
    } catch {
        return null
    }

    return body.steps?.find(step => Number(step.id) === stepId) ?? null
}

async function firstFunnelStep(
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

        for (const funnel of funnels.slice(0, 8)) {
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
                project_funnel?: { steps?: Array<{ id?: number }> }
            } | null
            const stepId = detail?.project_funnel?.steps?.find(
                step => typeof step.id === 'number'
            )?.id

            if (typeof stepId === 'number') {
                return { funnelId: funnel.id, stepId }
            }
        }

        return null
    }, API)
}

test('kanban scroll keeps the visual step sort', async ({ page }) => {
    test.setTimeout(120_000)

    const projectName = `${PROJECT_PREFIX}${Date.now()}`
    let created = false

    try {
        await loginAsE2EUser(page)

        const target = await firstFunnelStep(page)
        test.skip(!target, 'DOP-1239 no funnel step on this frame — skipped')
        if (!target) return

        await createE2EProject(page, {
            name: projectName,
            prefix: 'E2E',
            funnel_step_id: target.stepId,
        })
        created = true

        await openProjectFunnelKanban(page, target.funnelId)

        const column = page.locator(`[data-step-id="${target.stepId}"]`)
        await column.waitFor({ state: 'attached', timeout: 20_000 })
        // The list is height: calc(100% - 50px). A collapsed board parent makes that 0,
        // so the scroll listener never sees a bottom.
        await column.evaluate(el => {
            const root = el.closest('.kanban-column') as HTMLElement | null
            if (root) {
                root.style.height = '420px'
                root.style.minHeight = '420px'
            }
            el.style.height = '320px'
            el.style.minHeight = '320px'
        })

        await expect(column.getByText(projectName).first()).toBeVisible({ timeout: 20_000 })

        const columnRoot = page.locator('.kanban-column').filter({ has: column })
        await columnRoot.hover()
        await columnRoot.locator('.sort-btn button').click()
        // Each column keeps the label in the DOM. Only the open menu is visible.
        await page
            .getByText('Ordenar etapa', { exact: true })
            .filter({ visible: true })
            .click()

        const propertySelect = page
            .locator('.p-select')
            .filter({ hasText: 'Selecione a propriedade', visible: true })
        await expect(propertySelect).toBeVisible({ timeout: 10_000 })
        await propertySelect.click()
        await page.getByRole('option', { name: 'Nome', exact: true }).click()

        await page.waitForRequest(
            request => {
                const step = stepFromRequest(request, target.stepId)
                return step?.sorting?.field === 'name' && Number(step.offset) === 0
            },
            { timeout: 20_000 }
        )

        const lazyRequest = page.waitForRequest(
            request => {
                const step = stepFromRequest(request, target.stepId)
                return Boolean(step && Number(step.offset) > 0)
            },
            { timeout: 20_000 }
        )

        await column.evaluate(el => {
            el.style.maxHeight = '80px'
            el.scrollTop = el.scrollHeight
            el.dispatchEvent(new Event('scroll'))
        })

        const step = stepFromRequest(await lazyRequest, target.stepId)
        expect(step, 'lazy get-step-data for the sorted column').toBeTruthy()
        expect(typeof step?.id).toBe('number')
        expect(step?.id).toBe(target.stepId)
        expect(step?.offset).toBeGreaterThan(0)
        expect(step?.sorting).toMatchObject({ field: 'name', direction: 'asc' })
    } finally {
        if (created) {
            await purgeE2EProjects(page, projectName).catch(() => undefined)
        }
    }
})
