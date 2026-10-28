import { expect, type Page, test } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { requireFeature, requireVisible } from '../helpers/feature'
import { resolvePageOrigin } from '../helpers/navigation'

/**
 * DOP-1233 — company executions screen (3rd review return).
 *
 * - Menu must not show a redirect stub labeled "undefined".
 * - Início / Fim filters use datetime-local so search does not 422 on "22".
 *
 * Real login. Local RECAPTCHA_SECRET must be Google's test secret
 * (see ~/git/olie/prompts/workflow-policy.md / correction.md).
 *
 *   docker compose exec e2e npx playwright test --project=chromium --workers=1 \
 *     tests/features/dop-1233-project-executions-filters.spec.ts
 */

async function dismissBlockingSwal(page: Page) {
    const swal = page.locator('.swal2-container.swal2-backdrop-show, .swal2-container:visible')
    if (!(await swal.first().isVisible().catch(() => false))) {
        return
    }

    const ok = page.locator('.swal2-confirm')
    if (await ok.isVisible().catch(() => false)) {
        await ok.click({ force: true })
    } else {
        await page.keyboard.press('Escape')
    }
    await expect(swal.first()).toBeHidden({ timeout: 5_000 }).catch(() => undefined)
}

async function openCompanyExecutions(page: Page) {
    const searchPromise = page.waitForResponse(
        r =>
            r.request().method() === 'POST' &&
            /\/project-executions\/search\b/.test(r.url()),
        { timeout: 30_000 }
    )

    await page.goto(`${resolvePageOrigin(page)}/frame/project-executions`)
    await expect(page).toHaveURL(/\/frame\/project-executions/, { timeout: 20_000 })

    await requireVisible(
        page,
        'DOP-1233',
        page.getByText(/Histórico Detalhado de Execuções|Detailed execution history/i),
        15_000
    )

    await dismissBlockingSwal(page)

    return searchPromise
}

test.describe('DOP-1233 company project executions', () => {
    test.describe.configure({ timeout: 120_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
    })

    test('opens with is_running and no undefined Ajustes menu label', async ({ page }) => {
        const firstSearch = await openCompanyExecutions(page)
        const body = firstSearch.request().postDataJSON() as {
            filters?: Array<{ field?: string; value?: unknown }>
        }

        const running = body.filters?.find(f => f.field === 'is_running')
        expect(running?.value).toBe(true)
        expect(firstSearch.status()).toBeLessThan(400)

        // FrameIndex already shows FrameMenu beside this screen — no need to leave it.
        const menu = page.locator('nav.frame-menu-nav')
        await requireVisible(page, 'DOP-1233', menu, 15_000)

        await expect(menu.getByRole('link', { name: /^undefined$/i })).toHaveCount(0)
        await expect(
            menu.getByRole('link', { name: /Execuções de projetos|Project executions/i })
        ).toBeVisible()
        // FrameUsers redirects to the first tab; the menu must still show Usuários.
        await expect(
            menu.getByRole('link', { name: /^Usuários$|^Users$/i })
        ).toBeVisible()
    })

    test('Início filter with the date picker does not 422', async ({ page }) => {
        await openCompanyExecutions(page)

        const filterBtn = page.locator('button').filter({ has: page.locator('.fa-filter') }).first()
        await expect(filterBtn).toBeVisible()
        await dismissBlockingSwal(page)
        await filterBtn.click()

        const filterPanel = page.locator('.p-popover, [data-pc-name="popover"]').last()
        await expect(filterPanel).toBeVisible({ timeout: 10_000 })

        // Field select (PrimeVue Select) — first select in the filter row
        const fieldSelect = filterPanel.locator('.p-select, .p-dropdown').first()
        await fieldSelect.click()
        await page.getByRole('option', { name: /^Início$|^Start$/i }).click()

        const operatorSelect = filterPanel.locator('.p-select, .p-dropdown').nth(1)
        await operatorSelect.click()
        await page
            .getByRole('option', {
                name: /maior ou igual|greater than or equal|>=/i,
            })
            .first()
            .click()

        const dateInput = filterPanel.locator('.p-datepicker input, input.p-inputtext').first()
        await expect(dateInput).toBeVisible({ timeout: 10_000 })
        await dateInput.click()

        // Pick a day cell in the open calendar (avoid empty placeholders).
        const day = page.locator('.p-datepicker-calendar td:not(.p-datepicker-other-month) span').filter({
            hasText: /^22$/,
        }).first()
        await expect(day).toBeVisible({ timeout: 10_000 })

        const searchPromise = page.waitForResponse(
            r =>
                r.request().method() === 'POST' &&
                /\/project-executions\/search\b/.test(r.url()),
            { timeout: 30_000 }
        )
        await day.click()

        const response = await searchPromise
        expect(response.status(), await response.text()).toBeLessThan(400)

        const payload = response.request().postDataJSON() as {
            filters?: Array<{ field?: string; value?: unknown }>
        }
        const started = payload.filters?.find(f => f.field === 'started_at')
        expect(started).toBeTruthy()
        expect(String(started?.value)).not.toBe('22')
    })
})
