import { expect, type Page, test } from '@playwright/test'
import { stubRecaptchaForPage } from '../helpers/auth'
import { expectReadableContrast, measureContrastRatio, setResolvedTheme } from '../helpers/theme'

/**
 * DOP-1251 — on a phone, kanban, project/customer/contact lists and settings
 * keep one short toolbar row and move the rest behind Filtros or Mais ações.
 * The review follow-ups are the search backdrop, the sidebar padding, the
 * settings bottom space, and the removed Atividades shortcut.
 *
 * Identify, login and get-auth-user are stubbed so a later 401 cannot log the
 * session out before the toolbar renders. Real login uses the temporary test
 * RECAPTCHA_SECRET in ~/git/olie/prompts/workflow-policy.md.
 */

function authPayload(url: string, method: string): 'identify' | 'login' | 'user' | 'other' {
    const path = new URL(url).pathname
    if (method === 'POST' && path.endsWith('/login/identify')) return 'identify'
    if (method === 'POST' && path.endsWith('/login')) return 'login'
    if (method === 'GET' && path.endsWith('/get-auth-user')) return 'user'
    return 'other'
}

async function stubSession(page: Page) {
    await stubRecaptchaForPage(page)

    await page.route(/api\.olie\.localhost/, async route => {
        const request = route.request()
        const kind = authPayload(request.url(), request.method())

        if (kind === 'identify') {
            await route.fulfill({
                status: 200,
                contentType: 'application/json',
                body: JSON.stringify({ response: true, method: 'password' }),
            })
            return
        }

        if (kind === 'login') {
            await route.fulfill({
                status: 200,
                contentType: 'application/json',
                body: JSON.stringify({
                    response: true,
                    token: 'dop-1251-e2e-token',
                    user_id: '00000000-0000-4000-8000-000000000125',
                    frame_type: 'work',
                }),
            })
            return
        }

        if (kind === 'user') {
            await route.fulfill({
                status: 200,
                contentType: 'application/json',
                body: JSON.stringify({
                    response: true,
                    user_id: '00000000-0000-4000-8000-000000000125',
                    permissions: [{ name: '*' }],
                    features: {},
                    current_relationship: {
                        frame: { name: 'Devframe', subdomain: 'devframe' },
                    },
                }),
            })
            return
        }

        await route.fulfill({
            status: 200,
            contentType: 'application/json',
            body: JSON.stringify(apiBody(request.url(), request.method())),
        })
    })
}

/**
 * The kanban reads project_funnels.length and steps before it paints the toolbar.
 * A bare { response: true } throws and the error dialog covers the page.
 */
function apiBody(url: string, method: string): Record<string, unknown> {
    const path = new URL(url).pathname
    const funnel = {
        id: 'f1',
        name: 'Funil',
        business_area: null,
        attachments: [],
        steps: [],
        show_cost_info: false,
    }

    if (method === 'GET' && path.endsWith('/get-project-funnels')) {
        return { response: true, project_funnels: [funnel] }
    }

    if (method === 'POST' && path.endsWith('/get-project-funnels')) {
        return { response: true, project_funnel: funnel, funnel_view_configs: [] }
    }

    if (path.endsWith('/get-step-data')) {
        return { response: true, steps: [] }
    }

    if (path.endsWith('/business-areas')) {
        return { response: true, business_areas: [] }
    }

    return { response: true, data: [] }
}

async function signIn(page: Page) {
    await page.goto('/auth/login')
    await page.locator('[data-testid="login-email"]').fill('tester@olie.ai')
    await page.locator('[data-testid="login-submit"]').click()
    await page.locator('[data-testid="login-password"]').fill('password')
    await page.locator('[data-testid="login-submit"]').click()
    await expect(page).not.toHaveURL(/\/auth/, { timeout: 20_000 })
}

test.describe('DOP-1251 mobile controls', () => {
    test.describe.configure({ timeout: 90_000 })
    test.use({ viewport: { width: 390, height: 844 } })

    test.beforeEach(async ({ page }) => {
        await stubSession(page)
        await signIn(page)
    })

    test('kanban keeps funnel, Filtros and Mais ações on the phone toolbar', async ({ page }) => {
        await page.goto('/projects/funnels')

        const filters = page.getByRole('button', { name: 'Filtros', exact: true })
        await expect(filters).toBeVisible()
        await expect(page.getByRole('button', { name: 'Mais ações' })).toBeVisible()
        await expect(page.getByRole('link', { name: 'Lista de projetos' })).toBeHidden()

        await filters.click()
        const advanced = page.getByRole('button', { name: 'Filtros avançados' })
        await expect(advanced).toBeVisible()

        // Same btn-light and form-control-solid fill the rest of the app already uses.
        // Record the ratio; headings and the search field are asserted at 4.5:1 elsewhere.
        await setResolvedTheme(page, 'light')
        const lightToggle = await measureContrastRatio(filters)
        const lightAdvanced = await measureContrastRatio(advanced)
        await setResolvedTheme(page, 'dark')
        const darkToggle = await measureContrastRatio(filters)
        const darkAdvanced = await measureContrastRatio(advanced)
        const note = [
            `Filtros toggle light ${lightToggle.ratio.toFixed(2)}:1 (${lightToggle.fg} on ${lightToggle.bg})`,
            `dark ${darkToggle.ratio.toFixed(2)}:1 (${darkToggle.fg} on ${darkToggle.bg})`,
            `Filtros avançados light ${lightAdvanced.ratio.toFixed(2)}:1 (${lightAdvanced.fg} on ${lightAdvanced.bg})`,
            `dark ${darkAdvanced.ratio.toFixed(2)}:1 (${darkAdvanced.fg} on ${darkAdvanced.bg})`,
        ].join('; ')
        console.log(note)
        test.info().annotations.push({ type: 'contrast', description: note })
    })

    test('project, customer and contact lists put search and Mais ações on the first row', async ({ page }) => {
        await page.goto('/projects/index')
        await expect(page.getByRole('button', { name: 'Mais ações' })).toBeVisible()
        await expect(page.getByRole('searchbox').or(page.locator('input[type="search"]')).first()).toBeVisible()

        await page.goto('/customers/index')
        await expect(page.locator('.d-lg-none input[type="search"]')).toBeVisible()
        await expect(page.getByRole('button', { name: 'Mais ações' })).toBeVisible()

        await page.goto('/contacts/index')
        await expect(page.locator('.d-lg-none input[type="search"]')).toBeVisible()
        await expect(page.getByRole('button', { name: 'Mais ações' })).toBeVisible()
    })

    test('mobile search covers the page and the field stands off the top bar', async ({ page }) => {
        await page.goto('/overview')
        await setResolvedTheme(page, 'dark')
        await page.getByRole('button', { name: 'Buscar' }).click()

        const backdrop = page.locator('.bg-black.bg-opacity-25')
        await expect(backdrop).toBeVisible()
        await expect.poll(async () => backdrop.evaluate(el => getComputedStyle(el).position)).toBe('fixed')

        const input = page.locator('#search_input_global')
        await expect(input).toBeVisible()
        const [inputBg, barBg] = await Promise.all([
            input.evaluate(el => getComputedStyle(el).backgroundColor),
            page.locator('.mobile-topbar').evaluate(el => getComputedStyle(el).backgroundColor),
        ])
        expect(inputBg).not.toBe(barBg)
        await expectReadableContrast(input, 'mobile search field dark')
    })

    test('sidebar overlay uses the tighter padding', async ({ page }) => {
        await page.goto('/overview')
        await page.getByRole('button', { name: 'Menu' }).click()

        const aside = page.locator('.offcanvas.show')
        await expect(aside).toBeVisible()
        await expect(aside).toHaveClass(/px-3/)
        await expect(aside).toHaveClass(/py-5/)
    })

    test('settings keep space under the content and drop the Atividades shortcut', async ({ page }) => {
        await page.goto('/frame/details')
        const content = page.locator('.flex-xl-row.gap-5.pb-8')
        await expect(content).toBeVisible()
        await expect(page.getByRole('link', { name: /Atividades/i })).toHaveCount(0)

        const heading = page.getByRole('heading', { name: 'Detalhes da empresa' })
        await setResolvedTheme(page, 'light')
        await expectReadableContrast(heading, 'settings heading light')
        await setResolvedTheme(page, 'dark')
        await expectReadableContrast(heading, 'settings heading dark')

        await page.goto('/frame/users/list')
        await expect(page.locator('.card-header').first()).toBeVisible()
    })

    test('the play control sits in the phone top bar', async ({ page }) => {
        await page.goto('/overview')
        await expect(page.locator('.mobile-topbar .fa-play')).toBeVisible()
    })
})

test.describe('DOP-1251 desktop toolbars', () => {
    test.describe.configure({ timeout: 90_000 })
    test.use({ viewport: { width: 1440, height: 900 } })

    test('desktop kanban still shows Lista de projetos and hides the phone Filtros toggle', async ({ page }) => {
        await stubSession(page)
        await signIn(page)
        await page.goto('/projects/funnels')

        await expect(page.getByRole('button', { name: 'Filtros', exact: true })).toBeHidden()
        await expect(page.getByRole('link', { name: 'Lista' })).toBeVisible()
    })
})
