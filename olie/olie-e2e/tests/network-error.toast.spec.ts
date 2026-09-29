import { test, expect, type Page } from '@playwright/test'
import { loginAsE2EUser } from './helpers/auth'
import { createE2EProject, openProjectDetailsTab } from './helpers/project'

/**
 * OS-549 — toast `network_error` em blips de rede (`net::ERR_NETWORK_CHANGED`).
 *
 * Chrome aborta o request no meio; Axios vira `ERR_NETWORK` sem `response`.
 * Playwright não sintetiza o código do console, mas `route.abort('internetdisconnected')`
 * cai no mesmo caminho Axios → `normalizeAxiosCatchError` → toast.
 *
 * Gatilho: GET `get-notifications` (1 clique no sino). Representa qualquer GET do app.
 *
 * Aceite do fix (retry 1× em GET ~400ms no interceptor axios):
 *  - falha permanente → toast
 *  - 1 falha + 1 retry ok no mesmo clique → sem toast, `attempts === 2`
 *
 * Residual (Vinicius / CR): ao trocar de aba do projeto, GETs automáticos ainda
 * disparam Swal — não devem (tratar via UI / sem FireErrorMessage em background).
 *
 * `NavbarButtons` busca notificações no `onMounted`. O abort só é armado depois
 * do login; senão o GET inicial + o clique dão `attempts >= 2` sem retry (falso verde).
 */

const NETWORK_TOAST =
    /Houve uma falha na conexão, verifique sua rede\.|There was a connection failure, please check your network\./i

async function notificationBell(page: Page) {
    return page.locator('button').filter({ has: page.locator('i.fas.fa-bell') })
}

async function openNotificationBell(page: Page) {
    const bell = await notificationBell(page)
    await expect(bell).toBeVisible({ timeout: 20_000 })
    await bell.click()
}

test.describe('OS-549 network_error toast', () => {
    test.describe.configure({ timeout: 90_000 })

    test('shows toast when get-notifications keeps failing', async ({ page }) => {
        let armed = false

        await page.route('**/get-notifications**', async route => {
            if (!armed) {
                await route.continue()
                return
            }
            await route.abort('internetdisconnected')
        })

        await loginAsE2EUser(page)
        await expect(await notificationBell(page)).toBeVisible({ timeout: 20_000 })

        armed = true
        await openNotificationBell(page)

        await expect(page.getByText(NETWORK_TOAST)).toBeVisible({ timeout: 15_000 })
    })

    test('does not show toast when the first get-notifications fails and the retry succeeds', async ({
        page,
    }) => {
        let armed = false
        let attempts = 0

        await page.route('**/get-notifications**', async route => {
            if (!armed) {
                await route.continue()
                return
            }

            attempts += 1
            if (attempts === 1) {
                await route.abort('internetdisconnected')
                return
            }
            await route.continue()
        })

        await loginAsE2EUser(page)
        await expect(await notificationBell(page)).toBeVisible({ timeout: 20_000 })

        armed = true
        attempts = 0

        await openNotificationBell(page)

        // Exactly one user click: fail + axios retry = 2. Without interceptor, stays 1.
        await expect
            .poll(() => attempts, {
                timeout: 8_000,
                message:
                    'OS-549: one bell click must produce 2 GETs (fail + retry). Without axios network retry this stays 1.',
            })
            .toBe(2)

        await expect(page.getByText(NETWORK_TOAST)).toHaveCount(0)
    })

    /**
     * Residual after GET retry (#657): Vinicius — Swal still appears when switching
     * project tabs. Vínculos uses TanStack + `ProjectService(true)` (auto FireErrorMessage);
     * network blips on those automatic GETs must not toast.
     *
     * Expect RED until tab-entry / background GETs stop auto-toasting on network errors.
     */
    test('does not show network toast when opening Vínculos tab while GETs fail', async ({
        page,
    }) => {
        await loginAsE2EUser(page)

        const projectId = await createE2EProject(page, {
            name: `e2e-os549-tabs-${Date.now()}`,
        })
        await openProjectDetailsTab(page, projectId, 'overview')

        await page.route('**/api/management/**', async route => {
            if (route.request().method() === 'GET') {
                await route.abort('internetdisconnected')
                return
            }
            await route.continue()
        })

        await page.locator('a.nav-link', { hasText: /Vínculos|Hierarchy|Links/i }).click()

        // Must fail fast: default toHaveCount(0) waits until the toast timer hides it → false green.
        const toastAppeared = await page
            .getByText(NETWORK_TOAST)
            .waitFor({ state: 'visible', timeout: 3_000 })
            .then(() => true)
            .catch(() => false)

        expect(
            toastAppeared,
            'OS-549: entering a project tab must not toast network_error on automatic GETs'
        ).toBe(false)
    })
})
