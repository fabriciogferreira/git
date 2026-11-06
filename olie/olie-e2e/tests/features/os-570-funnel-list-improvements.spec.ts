import { expect, type Locator, type Page, test } from '@playwright/test'
import { stubRecaptchaForPage } from '../helpers/auth'
import { requireFeature } from '../helpers/feature'

/**
 * OS-570 — funnel selector improvements on the kanban.
 *
 * 1. Clicking the star must favorite only (PrimeVue Select selects on mousedown;
 *    click.stop alone still opened the funnel).
 * 2. Non-favorites group by business area (not a single "Geral" bucket).
 *
 * Stubs mirror os-551-favorite-funnels.spec.ts so the selector can be exercised
 * without a full board seed.
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
                    token: 'os-570-e2e-token',
                    user_id: '00000000-0000-4000-8000-000000000570',
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
                    user_id: '00000000-0000-4000-8000-000000000570',
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

async function requireOs570Selector(page: Page, overlay: Locator) {
    await requireFeature(page, {
        id: 'OS-570',
        probe: async () => {
            try {
                await overlay
                    .getByRole('button', { name: 'Marcar funil como favorito' })
                    .first()
                    .waitFor({ state: 'visible', timeout: 8_000 })
                // OS-570 drops the single "Geral" bucket for business-area headers.
                const hasGeral = (await overlay.getByText('Geral', { exact: true }).count()) > 0
                const hasAreaDev = (await overlay.getByText('Área Dev', { exact: true }).count()) > 0
                return !hasGeral && hasAreaDev
            } catch {
                return false
            }
        },
    })
}

test.describe('OS-570 funnel list improvements', () => {
    test.describe.configure({ timeout: 90_000 })
    test.use({ viewport: { width: 1440, height: 900 } })

    test.beforeEach(async ({ page }) => {
        await stubSession(page)
        await signIn(page)
        await page.evaluate(() => localStorage.removeItem('ui_favorite_project_funnels'))
    })

    test('non-favorites are grouped by business area instead of Geral', async ({ page }) => {
        await page.goto('/projects/funnels')
        const { overlay } = await openFunnelSelect(page)
        await requireOs570Selector(page, overlay)

        await expect(overlay.getByText('Geral', { exact: true })).toHaveCount(0)
        await expect(overlay.getByText('Área Dev', { exact: true })).toBeVisible()
        await expect(overlay.getByText('Área Comercial', { exact: true })).toBeVisible()
        await expect(overlay.getByRole('option').filter({ hasText: 'Funil Alpha' })).toBeVisible()
        await expect(overlay.getByRole('option').filter({ hasText: 'Funil Gamma' })).toBeVisible()
        await expect(overlay.getByText('Favoritos', { exact: true })).toHaveCount(0)
    })

    test('clicking the star favorites without selecting the funnel', async ({ page }) => {
        await page.goto('/projects/funnels')
        const { select, overlay } = await openFunnelSelect(page)
        await requireOs570Selector(page, overlay)

        // Establish a known selection first (Alpha).
        await overlay.getByRole('option').filter({ hasText: 'Funil Alpha' }).first().click()
        await expect(select).toContainText('Funil Alpha')

        const { overlay: overlayAgain } = await openFunnelSelect(page)
        const gamma = overlayAgain.getByRole('option').filter({ hasText: 'Funil Gamma' }).first()
        await gamma.getByRole('button', { name: 'Marcar funil como favorito' }).click()

        // Overlay should stay open with Favoritos; selection must remain Alpha.
        await expect(overlayAgain.getByText('Favoritos', { exact: true })).toBeVisible()
        await expect(
            gamma.getByRole('button', { name: 'Remover funil dos favoritos' }),
        ).toBeVisible()
        await expect(select).toContainText('Funil Alpha')
        await expect(select).not.toContainText('Funil Gamma')

        const stored = await page.evaluate(() => localStorage.getItem('ui_favorite_project_funnels'))
        expect(stored).toBeTruthy()
        const parsed = JSON.parse(stored as string) as Array<{ id: number }>
        expect(parsed).toEqual(expect.arrayContaining([expect.objectContaining({ id: 103 })]))
    })
})
