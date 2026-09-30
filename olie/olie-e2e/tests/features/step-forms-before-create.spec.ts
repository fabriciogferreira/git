import { test, expect, type Page, type Response } from '@playwright/test'
import { requireFeature } from '../helpers/feature'
import { loginAsIsolatedE2EUser } from '../helpers/isolated-user'
import {
    createE2EFunnelWithStepFormFlags,
    openProjectFunnelKanban,
} from '../helpers/project'

/**
 * Step customer/contact forms must run BEFORE quick-store when creating into a step.
 *
 * Uses an isolated user + work frame per worker so the file can run with --workers>1
 * without thrashing the shared tester@olie.ai / devframe seed.
 *
 * Regression: Opções → Criar created the project first, then LinkProject opened
 * StepCustomerLinkModal / StepContactLinkModal and raced project-step-sort.
 */

const CUSTOMER_MODAL_TITLE = /Vincular cliente|Link customer/i
const CONTACT_MODAL_TITLE = /Vincular contato|Link contact/i
const SKIP_BTN = /^(Pular|Skip)$/i
const CREATE_BTN = /Criar novo|Create new|^Criar$|^Create$/i
const OPTIONS_BTN = /^(Opções|Options)$/i
const PROJECT_SEARCH_PLACEHOLDER = /Pesquisar projetos|Search projects/i

function isQuickStore(response: Response) {
    if (response.request().method() !== 'POST') return false
    try {
        return new URL(response.url()).pathname.endsWith('/projects/quick-store')
    } catch {
        return false
    }
}

function isProjectStepSort(response: Response) {
    if (response.request().method() !== 'POST') return false
    try {
        return new URL(response.url()).pathname.endsWith('/project-step-sort')
    } catch {
        return false
    }
}

async function waitForKanbanReady(page: Page, stepName: string) {
    await expect(page.getByText(stepName, { exact: false }).first()).toBeVisible({
        timeout: 30_000,
    })
    await requireFeature(page, {
        id: 'step-link-forms-before-create',
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

async function openOptionsPopover(page: Page) {
    await page.getByRole('button', { name: OPTIONS_BTN }).first().click()
    await expect(page.getByRole('button', { name: CREATE_BTN })).toBeVisible({
        timeout: 15_000,
    })
    await expect(page.getByPlaceholder(PROJECT_SEARCH_PLACEHOLDER)).toBeVisible({
        timeout: 10_000,
    })
}

test.describe('Step customer/contact forms before project create', () => {
    test.describe.configure({ mode: 'parallel', timeout: 180_000 })

    test.beforeEach(async ({ page, request }, testInfo) => {
        await loginAsIsolatedE2EUser(page, request, {
            workerIndex: testInfo.parallelIndex,
        })
    })

    test('Opções → Criar: customer modal before quick-store; no sort error', async ({
        page,
    }) => {
        const { funnelId, funnelName, stepName } = await createE2EFunnelWithStepFormFlags(page, {
            name: `e2e-forms-create-${Date.now()}`,
            stepName: `e2e-forms-step-${Date.now()}`,
            show_customer_form: true,
            show_contact_form: false,
        })

        await openProjectFunnelKanban(page, funnelId, funnelName)
        await waitForKanbanReady(page, stepName)

        const sortFailures: number[] = []
        page.on('response', response => {
            if (isProjectStepSort(response) && !response.ok()) {
                sortFailures.push(response.status())
            }
        })

        await openOptionsPopover(page)

        const projectName = `e2e-criar-${Date.now()}`
        await page.getByPlaceholder(PROJECT_SEARCH_PLACEHOLDER).fill(projectName)

        const createBtn = page.getByRole('button', { name: CREATE_BTN })
        await expect(createBtn).toBeEnabled()

        const quickStorePromise = page.waitForResponse(isQuickStore, { timeout: 60_000 })

        await createBtn.click()

        const customerDialog = page.locator('.p-dialog').filter({
            has: page.getByRole('heading', { name: CUSTOMER_MODAL_TITLE }),
        })
        await expect(customerDialog).toBeVisible({ timeout: 15_000 })

        const prematureStore = await Promise.race([
            quickStorePromise.then(() => 'store' as const),
            customerDialog.waitFor({ state: 'visible' }).then(() => 'modal' as const),
        ])
        expect(
            prematureStore,
            'quick-store must not finish before the customer link modal is shown'
        ).toBe('modal')

        await customerDialog.getByRole('button', { name: SKIP_BTN }).click()

        const storeResponse = await quickStorePromise
        expect(
            [200, 402].includes(storeResponse.status()),
            `unexpected quick-store status=${storeResponse.status()}`
        ).toBeTruthy()

        if (storeResponse.ok()) {
            const body = (await storeResponse.json()) as {
                project?: { name?: string }
            }
            expect(body.project?.name).toContain('e2e-criar-')
            await expect(customerDialog).toHaveCount(0, { timeout: 10_000 })
        }

        await page.waitForTimeout(1_500)
        expect(
            sortFailures,
            'project-step-sort must not fail during forms-before-create'
        ).toEqual([])
    })

    test('Opções → Criar: customer then contact modals before quick-store', async ({
        page,
    }) => {
        const { funnelId, funnelName, stepName } = await createE2EFunnelWithStepFormFlags(page, {
            name: `e2e-forms-both-${Date.now()}`,
            stepName: `e2e-forms-both-step-${Date.now()}`,
            show_customer_form: true,
            show_contact_form: true,
        })

        await openProjectFunnelKanban(page, funnelId, funnelName)
        await waitForKanbanReady(page, stepName)
        await openOptionsPopover(page)

        const projectName = `e2e-both-${Date.now()}`
        await page.getByPlaceholder(PROJECT_SEARCH_PLACEHOLDER).fill(projectName)

        const quickStorePromise = page.waitForResponse(isQuickStore, { timeout: 60_000 })

        await page.getByRole('button', { name: CREATE_BTN }).click()

        const customerDialog = page.locator('.p-dialog').filter({
            has: page.getByRole('heading', { name: CUSTOMER_MODAL_TITLE }),
        })
        await expect(customerDialog).toBeVisible({ timeout: 15_000 })

        let storeSeen = false
        void quickStorePromise.then(() => {
            storeSeen = true
        })
        expect(storeSeen).toBe(false)

        await customerDialog.getByRole('button', { name: SKIP_BTN }).click()

        const contactDialog = page.locator('.p-dialog').filter({
            has: page.getByRole('heading', { name: CONTACT_MODAL_TITLE }),
        })
        await expect(contactDialog).toBeVisible({ timeout: 15_000 })
        expect(storeSeen).toBe(false)

        await contactDialog.getByRole('button', { name: SKIP_BTN }).click()

        const storeResponse = await quickStorePromise
        expect([200, 402].includes(storeResponse.status())).toBeTruthy()
        expect(storeSeen).toBe(true)
    })

    test('inline + create: customer modal before quick-store', async ({ page }) => {
        const { funnelId, funnelName, stepName } = await createE2EFunnelWithStepFormFlags(page, {
            name: `e2e-forms-inline-${Date.now()}`,
            stepName: `e2e-forms-inline-step-${Date.now()}`,
            show_customer_form: true,
            show_contact_form: false,
        })

        await openProjectFunnelKanban(page, funnelId, funnelName)
        await waitForKanbanReady(page, stepName)

        const plusBtn = page
            .locator('button.btn-icon')
            .filter({ has: page.locator('.fa-plus') })
            .first()
        await plusBtn.click()

        const quickInput = page.locator('input[id^="quickProjectInput_"]').first()
        await expect(quickInput).toBeVisible({ timeout: 10_000 })

        const projectName = `e2e-inline-${Date.now()}`
        await quickInput.fill(projectName)

        const quickStorePromise = page.waitForResponse(isQuickStore, { timeout: 60_000 })
        await quickInput.press('Enter')

        const customerDialog = page.locator('.p-dialog').filter({
            has: page.getByRole('heading', { name: CUSTOMER_MODAL_TITLE }),
        })
        await expect(customerDialog).toBeVisible({ timeout: 15_000 })

        const prematureStore = await Promise.race([
            quickStorePromise.then(() => 'store' as const),
            customerDialog.waitFor({ state: 'visible' }).then(() => 'modal' as const),
        ])
        expect(prematureStore).toBe('modal')

        await customerDialog.getByRole('button', { name: SKIP_BTN }).click()

        const storeResponse = await quickStorePromise
        expect(storeResponse.status()).toBeGreaterThanOrEqual(200)
        expect(storeResponse.status()).toBeLessThan(500)
    })
})
