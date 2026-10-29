import { expect, type Locator, type Page, test } from '@playwright/test'
import { stubRecaptchaForPage } from '../helpers/auth'
import { requireFeature } from '../helpers/feature'

/**
 * OS-551 — mark funnels as favorites in the kanban selector.
 *
 * Favoritos sits above Geral; order follows most recent selection click.
 * Preference key: ui_favorite_project_funnels (LocalStorageSetItem).
 *
 * Auth and funnel APIs are stubbed so the selector can be exercised without a
 * full board seed. Identify/login use the temporary test RECAPTCHA_SECRET path
 * documented in ~/git/olie/prompts/workflow-policy.md.
 */

const AREA_DEV = { id: 1, name: 'Área Dev' }
const AREA_COMERCIAL = { id: 2, name: 'Área Comercial' }

const BUSINESS_AREAS = [
    { ...AREA_DEV, deleted_at: null, project_funnels_count: 2 },
    { ...AREA_COMERCIAL, deleted_at: null, project_funnels_count: 1 },
]

const FUNNELS = [
    {
        id: 101,
        name: 'Funil Alpha',
        business_area: AREA_DEV,
        attachments: [],
        steps: [],
        show_cost_info: false,
    },
    {
        id: 102,
        name: 'Funil Beta',
        business_area: AREA_DEV,
        attachments: [],
        steps: [],
        show_cost_info: false,
    },
    {
        id: 103,
        name: 'Funil Gamma',
        business_area: AREA_COMERCIAL,
        attachments: [],
        steps: [],
        show_cost_info: false,
    },
] as const

function authPayload(url: string, method: string): 'identify' | 'login' | 'user' | 'other' {
    const path = new URL(url).pathname
    if (method === 'POST' && path.endsWith('/login/identify')) return 'identify'
    if (method === 'POST' && path.endsWith('/login')) return 'login'
    if (method === 'GET' && path.endsWith('/get-auth-user')) return 'user'
    return 'other'
}

function funnelById(id: unknown) {
    const numeric = Number(id)
    return FUNNELS.find(funnel => funnel.id === numeric) ?? FUNNELS[0]
}

function apiBody(url: string, method: string, postData: string | null): Record<string, unknown> {
    const path = new URL(url).pathname

    if (method === 'GET' && path.endsWith('/get-project-funnels')) {
        return { response: true, project_funnels: [...FUNNELS] }
    }

    if (method === 'POST' && path.endsWith('/get-project-funnels')) {
        let id: unknown = FUNNELS[0].id
        try {
            id = postData ? JSON.parse(postData)?.id : id
        } catch {
            // keep default
        }
        return {
            response: true,
            project_funnel: funnelById(id),
            funnel_view_configs: [],
        }
    }

    if (path.endsWith('/get-step-data')) {
        return { response: true, steps: [] }
    }

    if (path.endsWith('/business-areas')) {
        return { response: true, business_areas: BUSINESS_AREAS }
    }

    if (path.endsWith('/update-local-storage')) {
        return { response: true }
    }

    return { response: true, data: [] }
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
                    token: 'os-551-e2e-token',
                    user_id: '00000000-0000-4000-8000-000000000551',
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
                    user_id: '00000000-0000-4000-8000-000000000551',
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
            body: JSON.stringify(apiBody(request.url(), request.method(), request.postData())),
        })
    })
}

async function signIn(page: Page) {
    await page.goto('/auth/login')
    await page.locator('[data-testid="login-email"]').fill('tester@olie.ai')
    await page.locator('[data-testid="login-submit"]').click()
    await page.locator('[data-testid="login-password"]').fill('password')
    await page.locator('[data-testid="login-submit"]').click()
    await expect(page).not.toHaveURL(/\/auth/, { timeout: 20_000 })
}

async function openFunnelSelect(page: Page) {
    const select = page.locator('.kanban-funnel-select').first()
    await expect(select).toBeVisible({ timeout: 20_000 })
    await select.click()
    const overlay = page.locator('.p-select-overlay').last()
    await expect(overlay).toBeVisible()
    return { select, overlay }
}

async function requireFavoriteStar(page: Page, overlay: Locator) {
    await requireFeature(page, {
        id: 'OS-551',
        probe: async () => {
            try {
                await overlay
                    .getByRole('button', { name: 'Marcar funil como favorito' })
                    .first()
                    .waitFor({ state: 'visible', timeout: 8_000 })
                return true
            } catch {
                return false
            }
        },
    })
}

test.describe('OS-551 favorite funnels', () => {
    test.describe.configure({ timeout: 90_000 })
    test.use({ viewport: { width: 1440, height: 900 } })

    test.beforeEach(async ({ page }) => {
        await stubSession(page)
        await signIn(page)
        await page.evaluate(() => localStorage.removeItem('ui_favorite_project_funnels'))
    })

    test('star moves a funnel into Favoritos and persists the preference', async ({ page }) => {
        await page.goto('/projects/funnels')

        const { overlay } = await openFunnelSelect(page)

        await requireFavoriteStar(page, overlay)

        // Empty Favoritos: only Geral until something is starred.
        await expect(overlay.getByText('Geral', { exact: true })).toBeVisible()
        await expect(overlay.getByText('Favoritos', { exact: true })).toHaveCount(0)

        const betaOption = overlay.getByRole('option').filter({ hasText: 'Funil Beta' }).first()
        await expect(betaOption).toBeVisible()
        await betaOption.getByRole('button', { name: 'Marcar funil como favorito' }).click()

        await expect(overlay.getByText('Favoritos', { exact: true })).toBeVisible()
        await expect(
            betaOption.getByRole('button', { name: 'Remover funil dos favoritos' }),
        ).toBeVisible()

        const stored = await page.evaluate(() => localStorage.getItem('ui_favorite_project_funnels'))
        expect(stored).toBeTruthy()
        const parsed = JSON.parse(stored as string) as Array<{ id: number; lastClickedAt: number }>
        expect(parsed).toEqual(
            expect.arrayContaining([
                expect.objectContaining({ id: 102 }),
            ]),
        )
        expect(parsed[0]?.lastClickedAt).toEqual(expect.any(Number))
    })

    test('selecting a favorite bumps lastClickedAt so Favoritos stays by recency', async ({
        page,
    }) => {
        await page.goto('/projects/funnels')
        const { overlay } = await openFunnelSelect(page)

        await requireFavoriteStar(page, overlay)

        const alpha = overlay.getByRole('option').filter({ hasText: 'Funil Alpha' }).first()
        const beta = overlay.getByRole('option').filter({ hasText: 'Funil Beta' }).first()

        await alpha.getByRole('button', { name: 'Marcar funil como favorito' }).click()
        await page.waitForTimeout(20)
        await beta.getByRole('button', { name: 'Marcar funil como favorito' }).click()

        // Both favorites exist; Beta was marked last so it should lead Favoritos until Alpha is selected.
        let stored = await page.evaluate(() => localStorage.getItem('ui_favorite_project_funnels'))
        let parsed = JSON.parse(stored as string) as Array<{ id: number; lastClickedAt: number }>
        expect(parsed.map(entry => entry.id)).toEqual([102, 101])

        await page.keyboard.press('Escape')
        await page.locator('.kanban-funnel-select').first().click()
        const overlayAgain = page.locator('.p-select-overlay').last()
        await overlayAgain.getByRole('option').filter({ hasText: 'Funil Alpha' }).first().click()

        await expect.poll(async () => {
            stored = await page.evaluate(() => localStorage.getItem('ui_favorite_project_funnels'))
            parsed = JSON.parse(stored as string) as Array<{ id: number; lastClickedAt: number }>
            return parsed.map(entry => entry.id)
        }).toEqual([101, 102])
    })

    test('business-area filter narrows Favoritos and Geral', async ({ page }) => {
        await page.goto('/projects/funnels')

        const { overlay } = await openFunnelSelect(page)
        await requireFavoriteStar(page, overlay)
        await overlay.getByRole('option').filter({ hasText: 'Funil Gamma' }).first()
            .getByRole('button', { name: 'Marcar funil como favorito' })
            .click()
        await page.keyboard.press('Escape')

        // BA select is the toolbar Select that is not the funnel picker.
        const baSelect = page.locator('#kanban-filters .p-select:not(.kanban-funnel-select)').first()
        await expect(baSelect).toBeVisible()
        await baSelect.click()
        await page.locator('.p-select-overlay').last().getByRole('option', { name: 'Área Dev' }).click()

        const { overlay: filteredOverlay } = await openFunnelSelect(page)
        await expect(filteredOverlay.getByRole('option').filter({ hasText: 'Funil Alpha' })).toBeVisible()
        await expect(filteredOverlay.getByRole('option').filter({ hasText: 'Funil Beta' })).toBeVisible()
        await expect(filteredOverlay.getByRole('option').filter({ hasText: 'Funil Gamma' })).toHaveCount(0)
        // Gamma is favorited but outside the selected BA → Favoritos stays empty.
        await expect(filteredOverlay.getByText('Favoritos', { exact: true })).toHaveCount(0)
        await expect(filteredOverlay.getByText('Geral', { exact: true })).toBeVisible()
    })

    test('Select filter finds a funnel across Favoritos and Geral', async ({ page }) => {
        await page.goto('/projects/funnels')
        const { overlay } = await openFunnelSelect(page)
        await requireFavoriteStar(page, overlay)

        await overlay.getByRole('option').filter({ hasText: 'Funil Alpha' }).first()
            .getByRole('button', { name: 'Marcar funil como favorito' })
            .click()

        const overlayFilter = () => page.locator('.p-select-overlay').last().locator('input').first()

        // Favorited funnel still appears under Favoritos when filtered by name.
        await overlayFilter().fill('Alp')
        await expect(page.locator('.p-select-overlay').last().getByRole('option').filter({ hasText: 'Funil Alpha' })).toBeVisible()
        await expect(page.locator('.p-select-overlay').last().getByText('Favoritos', { exact: true })).toBeVisible()
        await expect(page.locator('.p-select-overlay').last().getByRole('option').filter({ hasText: 'Funil Beta' })).toHaveCount(0)

        await page.keyboard.press('Escape')
        await openFunnelSelect(page)

        // Non-favorite still found under Geral.
        await overlayFilter().fill('Gam')
        await expect(page.locator('.p-select-overlay').last().getByRole('option').filter({ hasText: 'Funil Gamma' })).toBeVisible()
        await expect(page.locator('.p-select-overlay').last().getByRole('option').filter({ hasText: 'Funil Alpha' })).toHaveCount(0)
    })
})
