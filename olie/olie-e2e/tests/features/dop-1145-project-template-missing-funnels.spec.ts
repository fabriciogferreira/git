import { test, expect, type Page } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import {
    createE2EProject,
    getFirstFunnelStepId,
    openProjectDetailsTab,
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

test.describe('DOP-1145 project details funnels after SPA navigation', () => {
    // Independent tests: a setup flake must not skip the rest of the suite.
    test.describe.configure({ timeout: 180_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
        // Do not purge here — search+delete of dozens of projects trips API 429.
        // createE2EProject purges only when hitting project_max_limit (402).
    })

    /**
     * Regression from skipping updateProjectHandler on force_redirect:
     * editing the *same* project on details + "Salvar e ver" pushes the same
     * route, so ProjectDetails does not reload and keeps stale data.
     */
    test('Salvar e ver while editing the open project refreshes details', async ({ page }) => {
        const originalName = `e2e-1145-same-before-${Date.now()}`
        const updatedName = `e2e-1145-same-after-${Date.now()}`
        const projectId = await createE2EProject(page, { name: originalName })

        await openProjectDetailsTab(page, projectId, 'overview')
        await expect(page.getByText(originalName, { exact: true }).first()).toBeVisible({
            timeout: 20_000,
        })

        // Accessible name includes the pen icon glyph (e.g. " Editar"), not exact "Editar".
        await page.getByRole('button', { name: /Editar|Edit/i }).first().click()

        const modal = page.locator('#project_form_modal')
        await expect(modal).toBeVisible({ timeout: 15_000 })

        const nameInput = modal.locator('input.form-control-solid').first()
        await expect(nameInput).toHaveValue(originalName, { timeout: 10_000 })
        await nameInput.fill(updatedName)

        await modal.getByRole('button', { name: /Salvar e ver|Save and view/i }).click()

        await expect(modal).toBeHidden({ timeout: 20_000 })
        await expect(page).toHaveURL(new RegExp(`/projects/${projectId}/details`))

        await expect(
            page.getByText(updatedName, { exact: true }).first(),
            'DOP-1145: Salvar e ver on the open project must refresh ProjectDetails'
        ).toBeVisible({ timeout: 20_000 })
        await expect(page.getByText(originalName, { exact: true })).toHaveCount(0)
    })

    /**
     * Hierarchy "Adicionar pai" emits updateProjectHandler. That path must soft-refresh
     * (no skeleton) — UpdateProject(true) caused a full ProjectDetails flicker.
     */
    test('attaching parent on Vínculos does not flash ProjectDetails skeleton', async ({
        page,
    }) => {
        const parentName = `e2e-1145-parent-${Date.now()}`
        const childName = `e2e-1145-child-${Date.now()}`
        await createE2EProject(page, { name: parentName })
        const childId = await createE2EProject(page, { name: childName })

        await openProjectDetailsTab(page, childId, 'hierarchy')
        await expect(page.getByText(childName, { exact: true }).first()).toBeVisible({
            timeout: 20_000,
        })

        // Hold the post-attach project find so a skeleton flash would be observable.
        let holdChildFind = false
        await page.route(`**/api/management/projects/${childId}**`, async route => {
            const url = route.request().url()
            if (route.request().method() !== 'GET' || url.includes('/hierarchy/')) {
                await route.continue()
                return
            }
            if (holdChildFind) {
                await new Promise(r => setTimeout(r, 2_000))
            }
            await route.continue()
        })

        await page.getByRole('button', { name: /Adicionar .*pai|Add parent/i }).click()

        // Card/list transition can leave two matching inputs briefly — use the visible one.
        const search = page
            .getByPlaceholder(/Buscar .*como pai|Search.*parent/i)
            .filter({ visible: true })
            .first()
        await expect(search).toBeVisible({ timeout: 10_000 })
        await search.click()
        await search.fill('')
        // Debounced server search (useMagicProjectIndexInfinite ~350ms) — type so @input fires.
        await search.pressSequentially(parentName, { delay: 20 })

        const parentOption = page
            .locator('.autocomplete-result')
            .filter({ hasText: parentName })
            .first()
        await expect(parentOption).toBeVisible({ timeout: 20_000 })

        holdChildFind = true
        await parentOption.click()

        // While soft-refresh find is in flight: header must stay, no details skeleton.
        await expect(page.getByText(childName, { exact: true }).first()).toBeVisible()
        await expect(
            page.locator('.p-skeleton'),
            'DOP-1145: hierarchy parent attach must not remount ProjectDetails with skeleton'
        ).toHaveCount(0)

        await expect(
            page.locator('.autocomplete-result').filter({ hasText: parentName })
        ).toHaveCount(0)
        await expect(page.getByText(parentName, { exact: true }).first()).toBeVisible({
            timeout: 20_000,
        })
    })

    test('Criar e ver: create while on details then SPA redirect shows funnels', async ({
        page,
    }) => {
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

    test('SPA A→B while A find is still in flight still shows B funnels', async ({ page }) => {
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

        await openProjectDetailsTab(page, projectA, 'funnel')
        await spaNavigateToProjectFunnel(page, projectB)

        await assertProjectShowsFunnel(page, funnelName)
        await expect(page).toHaveURL(new RegExp(`/projects/${projectB}/details/funnel`))
    })
})
