import { expect, type Page, test } from '@playwright/test'
import { stubRecaptchaForPage } from '../helpers/auth'
import { requireVisible } from '../helpers/feature'

/**
 * DOP-1233 — company executions live outside Relatórios and open with the V2
 * is_running filter so a manager sees what is running now.
 *
 * Identify, login, get-auth-user and the search endpoint are stubbed so a later
 * 401 cannot log the session out before the request is asserted.
 */

function authPayload(url: string, method: string): 'identify' | 'login' | 'user' | 'other' {
    const path = new URL(url).pathname
    if (method === 'POST' && path.endsWith('/login/identify')) return 'identify'
    if (method === 'POST' && path.endsWith('/login')) return 'login'
    if (method === 'GET' && path.endsWith('/get-auth-user')) return 'user'
    return 'other'
}

function hasRunningFilter(postData: string | null): boolean {
    if (!postData) return false

    try {
        const body = JSON.parse(postData) as {
            filters?: Array<{ field?: string; value?: unknown }>
        }
        return (body.filters ?? []).some(
            filter => filter.field === 'is_running' && (filter.value === true || filter.value === 'true'),
        )
    } catch {
        return false
    }
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
                    token: 'dop-1233-e2e-token',
                    user_id: '00000000-0000-4000-8000-000000001233',
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
                    user_id: '00000000-0000-4000-8000-000000001233',
                    permissions: [
                        { name: 'projects_executions.use' },
                        { name: 'projects_executions.see_timers' },
                    ],
                    features: {},
                    current_relationship: {
                        frame: { name: 'Devframe', subdomain: 'devframe' },
                    },
                }),
            })
            return
        }

        const path = new URL(request.url()).pathname
        if (request.method() === 'POST' && path.endsWith('/project-executions/search')) {
            await route.fulfill({
                status: 200,
                contentType: 'application/json',
                body: JSON.stringify({
                    response: true,
                    project_executions: [],
                    meta: {
                        current_page: 1,
                        from: 0,
                        to: 0,
                        last_page: 1,
                        per_page: 30,
                        total: 0,
                    },
                }),
            })
            return
        }

        if (request.method() === 'GET' && path.endsWith('/system/params/project_execution')) {
            await route.fulfill({
                status: 200,
                contentType: 'application/json',
                body: JSON.stringify({
                    response: true,
                    params: {
                        filters: [
                            {
                                name: 'is_running',
                                operators: ['equals'],
                                input_type: 'select',
                                options: [
                                    { label: 'Em execução', value: true },
                                    { label: 'Finalizada', value: false },
                                ],
                            },
                        ],
                        sorting: [],
                    },
                }),
            })
            return
        }

        await route.fulfill({
            status: 200,
            contentType: 'application/json',
            body: JSON.stringify({ response: true }),
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

test.describe('DOP-1233 company project executions', () => {
    test.describe.configure({ timeout: 90_000 })

    test('opens outside Relatórios with is_running filter and keeps the old reports URL', async ({
        page,
    }) => {
        await stubSession(page)
        await signIn(page)

        const listRequest = page.waitForRequest(
            request =>
                request.method() === 'POST'
                && /\/project-executions\/search(?:\?|$)/.test(new URL(request.url()).pathname)
                && hasRunningFilter(request.postData()),
            { timeout: 30_000 },
        )

        await page.goto('/frame/project-executions')

        const heading = page.getByRole('heading', { name: /Histórico Detalhado de Execuções/i })
        await requireVisible(page, 'DOP-1233 company executions table', heading, 25_000)

        await listRequest

        await page.goto('/frame/reports/time_view')
        await expect(page).toHaveURL(/\/frame\/project-executions/)
    })
})
