import { test, expect, type Page, type Response, type Locator } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { requireFeature } from '../helpers/feature'
import {
    createE2EProject,
    getE2EProjectFunnels,
    getTwoFunnelSteps,
    openProjectDetailsTab,
    openProjectFunnelKanban,
} from '../helpers/project'

/**
 * OS-561 — “Vincular projeto em outro funil” + “Desvincular do funil atual”.
 *
 * - Option off (default): project stays on source funnel and gains target.
 * - Option on (+ Swal confirm): project leaves source funnel, keeps target.
 * - Target === source: “Desvincular do funil atual” is hidden.
 *
 * Uses shared seed login (not isolated-user) while landing register recaptcha
 * rejects the e2e token in this docker stack. Reuses two active funnels because
 * new funnels on a full frame become INACTIVE (FrameMaxLimitException).
 */

const OPTIONS_BTN = /^(Opções|Options)$/i
const LINK_ANOTHER_FUNNEL = /Vincular .+ em outro funil|Link .+ in another funnel/i
const UNLINK_OTHERS = /Desvincular de outras etapas do funil selecionado|Unlink from other stages of the selected funnel/i
const UNLINK_CURRENT_FUNNEL = /Desvincular do funil atual|Unlink from (the )?current funnel/i
const SAVE_BTN = /^(Salvar|Save)$/i
const BULK_EDIT = /Edição em massa|Bulk editing/i

type FunnelStepRef = {
    funnelId: number
    funnelName: string
    stepId: number
    stepName: string
}

function isBulkStepMove(response: Response) {
    if (response.request().method() !== 'POST') return false
    try {
        return new URL(response.url()).pathname.endsWith('/project-bulk-step-move')
    } catch {
        return false
    }
}

function isBulkUpdateProject(response: Response) {
    if (response.request().method() !== 'POST') return false
    try {
        return new URL(response.url()).pathname.endsWith('/system/bulk-update/project')
    } catch {
        return false
    }
}

function isGetProjectFunnel(response: Response) {
    if (response.request().method() !== 'POST') return false
    try {
        return new URL(response.url()).pathname.endsWith('/get-project-funnels')
    } catch {
        return false
    }
}

async function waitForKanbanReady(page: Page, stepName: string) {
    await expect(page.getByText(stepName, { exact: false }).first()).toBeVisible({
        timeout: 30_000,
    })
    await requireFeature(page, {
        id: 'os-561-kanban-options',
        probe: async () => {
            try {
                await page.getByRole('button', { name: OPTIONS_BTN }).first().waitFor({
                    state: 'visible',
                    timeout: 8_000,
                })
                return true
            } catch {
                return false
            }
        },
    })
}

async function openCardMoreOptions(page: Page, projectName: string) {
    const card = page.locator('.funnel-card-container').filter({ hasText: projectName }).first()
    await expect(card).toBeVisible({ timeout: 20_000 })
    await card.locator('button.funnel-card-more-options').click()
}

async function openLinkAnotherFunnelModal(page: Page, projectName: string) {
    await openCardMoreOptions(page, projectName)

    const menuItem = page.getByText(LINK_ANOTHER_FUNNEL).first()
    await requireFeature(page, {
        id: 'os-561-link-another-funnel-menu',
        probe: async () => {
            try {
                await menuItem.waitFor({ state: 'visible', timeout: 8_000 })
                return true
            } catch {
                return false
            }
        },
    })
    await menuItem.click()

    const modal = page.locator('.p-dialog').filter({
        has: page.locator('.modal-title').filter({ hasText: LINK_ANOTHER_FUNNEL }),
    })
    await expect(modal).toBeVisible({ timeout: 15_000 })
    return modal
}

async function selectFunnelAndStep(
    page: Page,
    modal: Locator,
    target: FunnelStepRef
) {
    const funnelSelect = modal.locator('select').nth(0)
    const stepSelect = modal.locator('select').nth(1)

    await expect(
        funnelSelect.locator('option', { hasText: target.funnelName })
    ).toBeAttached({ timeout: 15_000 })

    await page.waitForResponse(isGetProjectFunnel, { timeout: 15_000 }).catch(() => null)

    const targetFunnelLoaded = page.waitForResponse(async response => {
        if (!isGetProjectFunnel(response) || !response.ok()) return false
        const body = (await response.json().catch(() => null)) as {
            project_funnel?: { id?: number | string; steps?: unknown[] }
        } | null
        return Number(body?.project_funnel?.id) === target.funnelId
    }, { timeout: 20_000 })

    await funnelSelect.selectOption({ label: target.funnelName })
    const funnelResponse = await targetFunnelLoaded
    const funnelBody = (await funnelResponse.json()) as {
        project_funnel?: { steps?: Array<{ id?: number; name?: string }> }
    }
    expect(
        funnelBody.project_funnel?.steps?.some(s => s.id === target.stepId),
        'GetProjectFunnel for target must include the selected step'
    ).toBeTruthy()

    await expect(
        stepSelect.locator('option', { hasText: target.stepName })
    ).toBeAttached({ timeout: 10_000 })
    await stepSelect.selectOption({ label: target.stepName })

    return { funnelSelect, stepSelect }
}

async function setupLinkedProjectOnSource(page: Page) {
    const stamp = Date.now()
    const { source, target } = await getTwoFunnelSteps(page)
    const projectName = `e2e-561-project-${stamp}`
    const projectId = await createE2EProject(page, {
        name: projectName,
        funnel_step_id: source.stepId,
    })

    const beforeFunnels = await getE2EProjectFunnels(page, projectId)
    expect(
        beforeFunnels.map(f => f.id),
        'project must start linked only to the source funnel'
    ).toEqual([source.funnelId])

    await openProjectFunnelKanban(page, source.funnelId, source.funnelName)
    await waitForKanbanReady(page, source.stepName)
    await expect(page.getByText(projectName, { exact: false }).first()).toBeVisible({
        timeout: 20_000,
    })

    return { source, target, projectName, projectId }
}

async function projectFunnelIds(page: Page, projectId: string) {
    const funnels = await getE2EProjectFunnels(page, projectId)
    return funnels.map(f => f.id).sort((a, b) => a - b)
}

async function confirmUnlinkSwal(page: Page) {
    const swal = page.locator('.swal2-popup').filter({ hasText: /histórico|history/i })
    await expect(swal).toBeVisible({ timeout: 15_000 })
    await page.locator('.swal2-confirm').click()
}

async function enableKanbanBulkEdit(page: Page) {
    const menuBtn = page
        .locator('button[data-bs-toggle="dropdown"]')
        .filter({ has: page.locator('i.fa-ellipsis-h') })
        .first()
    await menuBtn.click()
    const item = page.getByRole('button', { name: BULK_EDIT })
    await expect(item).toBeVisible({ timeout: 10_000 })
    await item.click()
}

async function selectKanbanProject(page: Page, projectName: string) {
    const card = page.locator('.funnel-card-container').filter({ hasText: projectName }).first()
    const checkbox = card.locator('input.form-check-input')
    await expect(checkbox).toBeVisible({ timeout: 10_000 })
    await checkbox.check()
    await expect(checkbox).toBeChecked()
}

async function openLinkAnotherFunnelFromDetails(page: Page, funnelId: number) {
    const trigger = page.locator(`#dropdown-${funnelId}`)
    await requireFeature(page, {
        id: 'os-561-details-funnel-dropdown',
        probe: async () => {
            try {
                await trigger.waitFor({ state: 'visible', timeout: 8_000 })
                return true
            } catch {
                return false
            }
        },
    })
    await trigger.click()

    const menuItem = page.getByText(LINK_ANOTHER_FUNNEL).first()
    await requireFeature(page, {
        id: 'os-561-link-another-funnel-menu',
        probe: async () => {
            try {
                await menuItem.waitFor({ state: 'visible', timeout: 8_000 })
                return true
            } catch {
                return false
            }
        },
    })
    await menuItem.click()

    const modal = page.locator('.p-dialog').filter({
        has: page.locator('.modal-title').filter({ hasText: LINK_ANOTHER_FUNNEL }),
    })
    await expect(modal).toBeVisible({ timeout: 15_000 })
    return modal
}

test.describe('OS-561 link to another funnel / unlink current', () => {
    test.describe.configure({ timeout: 180_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
        await page.evaluate(() => {
            localStorage.removeItem('project_funnel_fast_link_last_values')
        })
    })

    test('option off: save keeps project on source funnel', async ({ page }) => {
        const { source, target, projectName, projectId } = await setupLinkedProjectOnSource(page)

        const modal = await openLinkAnotherFunnelModal(page, projectName)

        await expect(
            modal.getByText(UNLINK_OTHERS),
            'existing unlink_others control must be present'
        ).toBeVisible()
        await expect(modal.locator('#unlink_others_checkbox')).toBeVisible()

        await selectFunnelAndStep(page, modal, target)

        await expect(modal.getByText(UNLINK_CURRENT_FUNNEL)).toBeVisible({ timeout: 10_000 })
        await expect(modal.locator('#unlink_current_funnel_checkbox')).not.toBeChecked()

        const bulkMove = page.waitForResponse(isBulkStepMove, { timeout: 60_000 })
        await modal.getByRole('button', { name: SAVE_BTN }).click()
        const moveResponse = await bulkMove
        expect(moveResponse.ok(), `bulk step move status=${moveResponse.status()}`).toBeTruthy()

        await expect(modal).toBeHidden({ timeout: 20_000 })

        await expect
            .poll(
                async () => {
                    const funnels = await getE2EProjectFunnels(page, projectId)
                    return funnels.map(f => f.id).sort((a, b) => a - b)
                },
                { timeout: 20_000 }
            )
            .toEqual([source.funnelId, target.funnelId].sort((a, b) => a - b))
    })

    test('option on: confirm then leave source funnel', async ({ page }) => {
        const { source, target, projectName, projectId } = await setupLinkedProjectOnSource(page)

        const modal = await openLinkAnotherFunnelModal(page, projectName)
        await selectFunnelAndStep(page, modal, target)

        const unlinkCurrent = modal.locator('#unlink_current_funnel_checkbox')
        await expect(modal.getByText(UNLINK_CURRENT_FUNNEL)).toBeVisible({ timeout: 10_000 })
        await unlinkCurrent.check()
        await expect(unlinkCurrent).toBeChecked()

        const bulkMove = page.waitForResponse(isBulkStepMove, { timeout: 60_000 })
        const bulkUnlink = page.waitForResponse(isBulkUpdateProject, { timeout: 60_000 })

        await modal.getByRole('button', { name: SAVE_BTN }).click()

        const swal = page.locator('.swal2-popup').filter({ hasText: /histórico|history/i })
        await expect(swal).toBeVisible({ timeout: 15_000 })
        await page.locator('.swal2-confirm').click()

        const moveResponse = await bulkMove
        expect(moveResponse.ok(), `bulk step move status=${moveResponse.status()}`).toBeTruthy()

        const unlinkResponse = await bulkUnlink
        expect(
            unlinkResponse.ok(),
            `bulk-update unlink status=${unlinkResponse.status()}`
        ).toBeTruthy()

        await expect(modal).toBeHidden({ timeout: 20_000 })

        await expect
            .poll(
                async () => {
                    const funnels = await getE2EProjectFunnels(page, projectId)
                    return funnels.map(f => f.id).sort((a, b) => a - b)
                },
                { timeout: 20_000 }
            )
            .toEqual([target.funnelId])

        expect(
            (await getE2EProjectFunnels(page, projectId)).some(f => f.id === source.funnelId),
            'source funnel must be removed when option is on'
        ).toBeFalsy()
    })

    test('target === source: unlink-current control is hidden', async ({ page }) => {
        const { source, target, projectName } = await setupLinkedProjectOnSource(page)

        const modal = await openLinkAnotherFunnelModal(page, projectName)
        const funnelSelect = modal.locator('select').nth(0)

        // Prefer asserting hide by selecting source explicitly (robust to list order).
        await page.waitForResponse(isGetProjectFunnel, { timeout: 15_000 }).catch(() => null)
        const sourceLoaded = page.waitForResponse(async response => {
            if (!isGetProjectFunnel(response) || !response.ok()) return false
            const body = (await response.json().catch(() => null)) as {
                project_funnel?: { id?: number | string }
            } | null
            return Number(body?.project_funnel?.id) === source.funnelId
        }, { timeout: 20_000 })

        await funnelSelect.selectOption({ label: source.funnelName })
        await sourceLoaded
        await expect(funnelSelect).toHaveValue(String(source.funnelId))
        await expect(modal.getByText(UNLINK_CURRENT_FUNNEL)).toHaveCount(0)
        await expect(modal.locator('#unlink_current_funnel_checkbox')).toHaveCount(0)

        await selectFunnelAndStep(page, modal, target)
        await expect(modal.getByText(UNLINK_CURRENT_FUNNEL)).toBeVisible({ timeout: 10_000 })

        const sourceReloaded = page.waitForResponse(async response => {
            if (!isGetProjectFunnel(response) || !response.ok()) return false
            const body = (await response.json().catch(() => null)) as {
                project_funnel?: { id?: number | string }
            } | null
            return Number(body?.project_funnel?.id) === source.funnelId
        }, { timeout: 20_000 })

        await funnelSelect.selectOption({ label: source.funnelName })
        await sourceReloaded

        await expect(modal.getByText(UNLINK_CURRENT_FUNNEL)).toHaveCount(0)
        await expect(modal.locator('#unlink_current_funnel_checkbox')).toHaveCount(0)
    })

    test('bulk select: option on unlinks source funnel for every selected card', async ({ page }) => {
        const stamp = Date.now()
        const { source, target } = await getTwoFunnelSteps(page)
        const projectAName = `e2e-561-bulk-a-${stamp}`
        const projectBName = `e2e-561-bulk-b-${stamp}`
        const projectAId = await createE2EProject(page, {
            name: projectAName,
            funnel_step_id: source.stepId,
        })
        const projectBId = await createE2EProject(page, {
            name: projectBName,
            funnel_step_id: source.stepId,
        })

        expect(await projectFunnelIds(page, projectAId)).toEqual([source.funnelId])
        expect(await projectFunnelIds(page, projectBId)).toEqual([source.funnelId])

        await openProjectFunnelKanban(page, source.funnelId, source.funnelName)
        await waitForKanbanReady(page, source.stepName)
        await expect(page.getByText(projectAName, { exact: false }).first()).toBeVisible({
            timeout: 20_000,
        })
        await expect(page.getByText(projectBName, { exact: false }).first()).toBeVisible({
            timeout: 20_000,
        })

        await enableKanbanBulkEdit(page)
        await selectKanbanProject(page, projectAName)
        await selectKanbanProject(page, projectBName)

        const modal = await openLinkAnotherFunnelModal(page, projectAName)
        await selectFunnelAndStep(page, modal, target)

        const unlinkCurrent = modal.locator('#unlink_current_funnel_checkbox')
        await expect(modal.getByText(UNLINK_CURRENT_FUNNEL)).toBeVisible({ timeout: 10_000 })
        await unlinkCurrent.check()

        const bulkMove = page.waitForResponse(isBulkStepMove, { timeout: 60_000 })
        const bulkUnlink = page.waitForResponse(isBulkUpdateProject, { timeout: 60_000 })

        await modal.getByRole('button', { name: SAVE_BTN }).click()
        await confirmUnlinkSwal(page)

        const moveResponse = await bulkMove
        expect(moveResponse.ok(), `bulk step move status=${moveResponse.status()}`).toBeTruthy()
        const moveBody = moveResponse.request().postDataJSON() as { project_ids?: string[] }
        expect([...((moveBody.project_ids ?? []) as string[])].sort()).toEqual(
            [projectAId, projectBId].sort()
        )

        const unlinkResponse = await bulkUnlink
        expect(
            unlinkResponse.ok(),
            `bulk-update unlink status=${unlinkResponse.status()}`
        ).toBeTruthy()
        const unlinkBody = unlinkResponse.request().postDataJSON() as {
            ids?: string[]
            funnels?: { to_rem?: Array<number | string> }
        }
        expect([...(unlinkBody.ids ?? [])].sort()).toEqual([projectAId, projectBId].sort())
        expect((unlinkBody.funnels?.to_rem ?? []).map(Number)).toEqual([source.funnelId])

        await expect(modal).toBeHidden({ timeout: 20_000 })

        await expect
            .poll(async () => projectFunnelIds(page, projectAId), { timeout: 20_000 })
            .toEqual([target.funnelId])
        await expect
            .poll(async () => projectFunnelIds(page, projectBId), { timeout: 20_000 })
            .toEqual([target.funnelId])
    })

    test('details dropdown: option on leaves source funnel for the open project only', async ({
        page,
    }) => {
        const stamp = Date.now()
        const { source, target } = await getTwoFunnelSteps(page)
        const openName = `e2e-561-details-${stamp}`
        const otherName = `e2e-561-details-other-${stamp}`
        const openId = await createE2EProject(page, {
            name: openName,
            funnel_step_id: source.stepId,
        })
        const otherId = await createE2EProject(page, {
            name: otherName,
            funnel_step_id: source.stepId,
        })

        await openProjectDetailsTab(page, openId, 'funnel')
        await expect(page.getByText(source.funnelName, { exact: false }).first()).toBeVisible({
            timeout: 20_000,
        })

        const modal = await openLinkAnotherFunnelFromDetails(page, source.funnelId)
        await selectFunnelAndStep(page, modal, target)

        const unlinkCurrent = modal.locator('#unlink_current_funnel_checkbox')
        await expect(modal.getByText(UNLINK_CURRENT_FUNNEL)).toBeVisible({ timeout: 10_000 })
        await unlinkCurrent.check()

        const bulkMove = page.waitForResponse(isBulkStepMove, { timeout: 60_000 })
        const bulkUnlink = page.waitForResponse(isBulkUpdateProject, { timeout: 60_000 })

        await modal.getByRole('button', { name: SAVE_BTN }).click()
        await confirmUnlinkSwal(page)

        const moveResponse = await bulkMove
        expect(moveResponse.ok(), `bulk step move status=${moveResponse.status()}`).toBeTruthy()
        const moveBody = moveResponse.request().postDataJSON() as { project_ids?: string[] }
        expect(moveBody.project_ids).toEqual([openId])

        const unlinkResponse = await bulkUnlink
        expect(
            unlinkResponse.ok(),
            `bulk-update unlink status=${unlinkResponse.status()}`
        ).toBeTruthy()
        const unlinkBody = unlinkResponse.request().postDataJSON() as {
            ids?: string[]
            funnels?: { to_rem?: Array<number | string> }
        }
        expect(unlinkBody.ids).toEqual([openId])
        expect((unlinkBody.funnels?.to_rem ?? []).map(Number)).toEqual([source.funnelId])

        await expect(modal).toBeHidden({ timeout: 20_000 })

        await expect
            .poll(async () => projectFunnelIds(page, openId), { timeout: 20_000 })
            .toEqual([target.funnelId])
        expect(await projectFunnelIds(page, otherId)).toEqual([source.funnelId])

        await expect(page.getByText(target.funnelName, { exact: false }).first()).toBeVisible({
            timeout: 20_000,
        })
        await expect(
            page.locator(`#dropdown-${source.funnelId}`),
            'details refresh must drop the unlinked source funnel control'
        ).toHaveCount(0)
    })
})
