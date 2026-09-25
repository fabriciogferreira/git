import { test, expect, type Page } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import {
    createE2EProject,
    getFirstFunnelStepId,
    openProjectFunnelTab,
    spaNavigateToProjectFunnel,
    EMPTY_FUNNELS_ALERT,
} from '../helpers/project'

/**
 * DOP-1145 — funis vazios nos detalhes após "Criar e ver".
 *
 * #652 (KeepAlive exclude + loadRequestId) mitigou; residual vinha do
 * ProjectFormModal emitindo `updateProjectHandler` após force_redirect,
 * correndo com o load do ProjectDetails (HeaderButtons ainda montado).
 *
 * Não usar `/overview` como base — a overview faz `replace` de query e aborta pushes.
 */

async function assertProjectShowsFunnel(page: Page, funnelName: string) {
    await expect(
        page.getByText(EMPTY_FUNNELS_ALERT),
        'DOP-1145: empty-funnels alert must not show'
    ).toHaveCount(0)

    await expect(page.getByText(funnelName, { exact: false }).first()).toBeVisible({
        timeout: 20_000,
    })
}

/** Hold the first GET of a project find so a later navigation races it. */
async function delayProjectFind(page: Page, projectId: string, delayMs: number) {
    let held = false
    await page.route(`**/api/management/projects/${projectId}**`, async route => {
        if (route.request().method() !== 'GET') {
            await route.continue()
            return
        }
        if (!held) {
            held = true
            await new Promise(r => setTimeout(r, delayMs))
        }
        await route.continue()
    })
}

/**
 * Pre-fix FormModal race: after redirect, HeaderButtons.UpdateProject did
 * `router.replace({ query })` then `loadProject()` without skeleton — in parallel
 * with ProjectDetails' own load for the new id.
 */
async function simulatePostRedirectQueryReplace(page: Page) {
    await page.evaluate(() => {
        const el = document.querySelector('#app') as {
            __vue_app__?: {
                config: {
                    globalProperties: {
                        $router?: {
                            replace: (loc: { query: Record<string, unknown> }) => Promise<unknown>
                        }
                    }
                }
            }
        } | null
        const router = el?.__vue_app__?.config?.globalProperties?.$router
        if (!router) return
        void router.replace({ query: { is_template: false } })
    })
}

test.describe('DOP-1145 project details funnels after SPA navigation', () => {
    test.describe.configure({ timeout: 180_000, mode: 'serial' })

    test('Criar e ver: create while on details then SPA redirect shows funnels', async ({
        page,
    }) => {
        await loginAsE2EUser(page)
        const { stepId, funnelName } = await getFirstFunnelStepId(page)

        const projectWarm = await createE2EProject(page, {
            name: `e2e-1145-warm-${Date.now()}`,
            funnel_step_id: stepId,
        })
        await openProjectFunnelTab(page, projectWarm)
        await assertProjectShowsFunnel(page, funnelName)

        const projectNew = await createE2EProject(page, {
            name: `e2e-1145-criar-ver-${Date.now()}`,
            funnel_step_id: stepId,
        })
        await spaNavigateToProjectFunnel(page, projectNew)
        await assertProjectShowsFunnel(page, funnelName)
    })

    test('stress: many create+redirect cycles still show funnels', async ({ page }) => {
        await loginAsE2EUser(page)
        const { stepId, funnelName } = await getFirstFunnelStepId(page)

        const projectWarm = await createE2EProject(page, {
            name: `e2e-1145-stress-warm-${Date.now()}`,
            funnel_step_id: stepId,
        })
        await openProjectFunnelTab(page, projectWarm)
        await assertProjectShowsFunnel(page, funnelName)

        for (let i = 0; i < 12; i++) {
            const projectId = await createE2EProject(page, {
                name: `e2e-1145-stress-${i}-${Date.now()}`,
                funnel_step_id: stepId,
            })
            await spaNavigateToProjectFunnel(page, projectId)
            await simulatePostRedirectQueryReplace(page)
            await assertProjectShowsFunnel(page, funnelName)
        }
    })

    test('SPA A→B while A find is still in flight still shows B funnels', async ({ page }) => {
        await loginAsE2EUser(page)
        const { stepId, funnelName } = await getFirstFunnelStepId(page)

        const projectA = await createE2EProject(page, {
            name: `e2e-1145-race-a-${Date.now()}`,
            funnel_step_id: stepId,
        })
        const projectB = await createE2EProject(page, {
            name: `e2e-1145-race-b-${Date.now()}`,
            funnel_step_id: stepId,
        })

        await delayProjectFind(page, projectA, 2_500)

        await page.goto(`/projects/${projectA}/details/funnel`)
        await spaNavigateToProjectFunnel(page, projectB)

        await assertProjectShowsFunnel(page, funnelName)
        await expect(page).toHaveURL(new RegExp(`/projects/${projectB}/details/funnel`))
    })
})
