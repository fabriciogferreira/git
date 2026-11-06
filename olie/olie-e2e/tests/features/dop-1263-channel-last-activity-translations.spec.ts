import { test, expect, type Page } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { openProjectFunnelKanban } from '../helpers/project'
import { expectReadableContrast, setResolvedTheme } from '../helpers/theme'

/**
 * DOP-1263 — missing i18n for channel_last_activity_at in filters and step sort.
 *
 * Card evidence (media ids):
 * - 01a1a1c7-8ba5-7390-b7a6-fdbfca06b593 — auto_sort showed raw key
 * - 01a1a1c7-cb77-70bd-a05b-3253f56296aa — filter field select showed raw key
 *
 * Real login against api-main. Local RECAPTCHA_SECRET must be Google's test
 * secret (see ~/git/olie/prompts/workflow-policy.md).
 *
 *   docker compose exec e2e npx playwright test --project=chromium --workers=1 \
 *     tests/features/dop-1263-channel-last-activity-translations.spec.ts
 */

const API = process.env.E2E_API_URL || 'http://api.olie.localhost'
const LABEL = 'Data da última mensagem do canal'
const RAW_FILTER_KEY = 'ui.filter.fields_names.channel_last_activity_at'
const RAW_SORT_KEY = 'ui.components.auto_sort.project.channel_last_activity_at'

async function firstFunnel(page: Page): Promise<{ funnelId: number; stepId: number } | null> {
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

async function openStepSortPropertySelect(page: Page, stepId: number) {
    const column = page.locator(`[data-step-id="${stepId}"]`)
    await column.waitFor({ state: 'attached', timeout: 20_000 })

    const columnRoot = page.locator('.kanban-column').filter({ has: column })
    await columnRoot.hover()
    await columnRoot.locator('.sort-btn button').click()
    await page
        .getByText('Ordenar etapa', { exact: true })
        .filter({ visible: true })
        .click()

    const propertySelect = page
        .locator('.p-select')
        .filter({ hasText: 'Selecione a propriedade', visible: true })
    await expect(propertySelect).toBeVisible({ timeout: 10_000 })
    await propertySelect.click()
}

async function openAdvancedFilterFieldSelect(page: Page) {
    const filterBtn = page.locator(
        'button[aria-label="Filtros avançados"], button:has-text("Filtros avançados")'
    )
    await expect(filterBtn.first()).toBeVisible({ timeout: 15_000 })
    await filterBtn.first().click()

    const addFilter = page.getByRole('button', { name: /Adicionar filtro/i })
    await expect(addFilter).toBeVisible({ timeout: 10_000 })
    await addFilter.click()

    const fieldSelect = page
        .locator('.p-select')
        .filter({ hasText: 'Selecione um campo', visible: true })
    await expect(fieldSelect).toBeVisible({ timeout: 10_000 })
    await fieldSelect.click()
}

test.describe('DOP-1263 channel last activity translations', () => {
    test.describe.configure({ timeout: 120_000 })

    test('filter and step-sort show translated label, not raw keys', async ({ page }) => {
        await loginAsE2EUser(page)

        const target = await firstFunnel(page)
        test.skip(!target, 'DOP-1263 no funnel step on this frame — skipped')
        if (!target) return

        await openProjectFunnelKanban(page, target.funnelId)

        // --- Step auto-sort (card media 01a1a1c7-8ba5-…) ---
        await openStepSortPropertySelect(page, target.stepId)

        const sortOption = page.getByRole('option', { name: LABEL, exact: true })
        await expect(sortOption).toBeVisible({ timeout: 10_000 })
        await expect(page.getByText(RAW_SORT_KEY, { exact: true })).toHaveCount(0)

        await setResolvedTheme(page, 'light')
        await expectReadableContrast(sortOption, 'sort label light')
        await setResolvedTheme(page, 'dark')
        await expectReadableContrast(sortOption, 'sort label dark')

        await page.keyboard.press('Escape')
        await page.keyboard.press('Escape')

        // --- Advanced filters field list (card media 01a1a1c7-cb77-…) ---
        await openAdvancedFilterFieldSelect(page)

        const filterOption = page.getByRole('option', { name: LABEL, exact: true })
        await expect(filterOption).toBeVisible({ timeout: 10_000 })
        await expect(page.getByText(RAW_FILTER_KEY, { exact: true })).toHaveCount(0)

        await setResolvedTheme(page, 'light')
        await expectReadableContrast(filterOption, 'filter label light')
        await setResolvedTheme(page, 'dark')
        await expectReadableContrast(filterOption, 'filter label dark')
    })
})
