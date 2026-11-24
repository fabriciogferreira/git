import { test, expect, type Page, type Response } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import {
    createE2EFunnelWithStepFormFlags,
    createE2ETemplate,
    openProjectFunnelKanban,
} from '../helpers/project'

/**
 * DOP-1264 — nome com variáveis no modelo não pode voltar ao slug ao salvar.
 *
 * Causa: deep watch de `clone_project` re-inicializava o modal no mesmo template
 * (refetch do pai) e zerava `clone_info.name` para `projeto modelo {{nome}}`
 * enquanto o input da variável ainda mostrava o valor. O POST /clone ia com o slug.
 *
 * Fix: early-return no watcher quando o template já está carregado.
 */

const OPTIONS_BTN = /^(Opções|Options)$/i
const TEMPLATE_SEARCH_PLACEHOLDER = /Pesquisar templates|Search templates/i
const CLONE_MODAL_CREATE_BTN = /^(Criar|Create)$/i
const VARIABLE_VALUE = 'texto do nome do projeto'

function isProjectClone(response: Response) {
    if (response.request().method() !== 'POST') return false
    try {
        return /\/projects\/[^/]+\/clone$/.test(new URL(response.url()).pathname)
    } catch {
        return false
    }
}

async function waitForKanbanReady(page: Page, stepName: string) {
    await expect(page.getByText(stepName, { exact: false }).first()).toBeVisible({
        timeout: 30_000,
    })
    await expect(page.getByRole('button', { name: OPTIONS_BTN }).first()).toBeVisible({
        timeout: 20_000,
    })
}

async function openOptionsPopover(page: Page) {
    await page.getByRole('button', { name: OPTIONS_BTN }).first().click()
    await expect(page.getByPlaceholder(TEMPLATE_SEARCH_PLACEHOLDER)).toBeVisible({
        timeout: 15_000,
    })
}

/** Re-dispatch the same clone payload (new object) — simulates parent refetch / deep watch. */
async function redispatchSameCloneProject(page: Page) {
    const ok = await page.evaluate(() => {
        const el = document.querySelector('#app') as {
            __vue_app__?: {
                config: {
                    globalProperties: {
                        $store?: {
                            getters: Record<string, unknown>
                            dispatch: (type: string, payload: unknown) => unknown
                        }
                    }
                }
            }
        } | null
        const store = el?.__vue_app__?.config?.globalProperties?.$store
        if (!store) return false
        const current = store.getters['project/clone_project'] as Record<string, unknown> | null
        if (!current?.project) return false
        store.dispatch('project/ShowProjectCloneModal', { ...current })
        return true
    })
    expect(ok, 'Vuex store / clone_project must be reachable to simulate refetch').toBe(true)
}

test.describe('DOP-1264 template name variables survive modal re-init', () => {
    test.describe.configure({ timeout: 180_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
    })

    test('filled {{nome}} is kept after clone_project re-dispatch and saved on clone', async ({
        page,
    }) => {
        const stamp = Date.now()
        const templateName = `e2e-1264-tpl-{{nome}}-${stamp}`
        const expectedName = `e2e-1264-tpl-${VARIABLE_VALUE}-${stamp}`

        const templateId = await createE2ETemplate(page, {
            name: templateName,
            description: 'e2e DOP-1264 template with name variable',
        })

        const { funnelId, funnelName, stepName } = await createE2EFunnelWithStepFormFlags(page, {
            name: `e2e-1264-funnel-${stamp}`,
            stepName: `e2e-1264-step-${stamp}`,
            show_customer_form: false,
            show_contact_form: false,
            template_project_ids: [templateId],
        })

        await openProjectFunnelKanban(page, funnelId, funnelName)
        await waitForKanbanReady(page, stepName)
        await openOptionsPopover(page)

        const templateSearch = page.getByPlaceholder(TEMPLATE_SEARCH_PLACEHOLDER)
        await templateSearch.fill(templateName)

        const templateRow = page.locator('.project').filter({ hasText: templateName }).first()
        await expect(templateRow).toBeVisible({ timeout: 20_000 })
        await templateRow.click()

        const cloneModal = page.locator('#project_clone_modal')
        await expect(cloneModal).toBeVisible({ timeout: 15_000 })

        // Variable input under ProjectNameWithVariables (label = "nome" from {{nome}}).
        const variableInput = cloneModal.locator('input.form-control').first()
        await expect(variableInput).toBeVisible({ timeout: 10_000 })
        await variableInput.fill(VARIABLE_VALUE)

        await expect(cloneModal.locator('#project_clone_name')).toHaveValue(expectedName, {
            timeout: 10_000,
        })

        // Parent refetch / deep watch must not wipe the resolved name.
        await redispatchSameCloneProject(page)
        await page.waitForTimeout(300)

        await expect(
            cloneModal.locator('#project_clone_name'),
            'DOP-1264: resolved name must survive clone_project re-dispatch'
        ).toHaveValue(expectedName, { timeout: 10_000 })

        // Name uses PrimeVue Textarea (disabled when variables exist); description is a plain textarea.
        const description = cloneModal.locator('textarea:not([disabled]):not(#project_clone_name)').first()
        await expect(description).toBeVisible({ timeout: 10_000 })
        await description.fill('e2e DOP-1264 cloned description')

        const clonePromise = page.waitForResponse(isProjectClone, { timeout: 60_000 })
        await cloneModal.getByRole('button', { name: CLONE_MODAL_CREATE_BTN }).click()

        const cloneResponse = await clonePromise
        expect(
            [200, 402].includes(cloneResponse.status()),
            `unexpected clone status=${cloneResponse.status()}`
        ).toBeTruthy()

        if (!cloneResponse.ok()) {
            return
        }

        const requestBody = cloneResponse.request().postDataJSON() as { name?: string }
        expect(
            requestBody.name,
            'clone payload must send the resolved name, not the {{slug}}'
        ).toBe(expectedName)
        expect(requestBody.name).not.toContain('{{')

        const body = (await cloneResponse.json()) as {
            project?: { name?: string }
        }
        expect(body.project?.name).toBe(expectedName)
    })
})
