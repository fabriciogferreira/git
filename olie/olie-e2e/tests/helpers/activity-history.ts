import { type Locator, type Page, expect } from '@playwright/test'
import { requireVisible } from './feature'

/** i18n for permissions.activities.search (pt-BR | en). */
export const ACTIVITIES_SEARCH_LABEL =
    /Visualizar o histórico de alterações dos registros\.|View change history for records\./i

/** permissions.grouping_title.activities */
export const ACTIVITIES_GROUP_TITLE = /Histórico de alterações|Change history/i

export function frameRolesCard(page: Page): Locator {
    return page.locator('#settings_roles')
}

/**
 * Project header history toggle (fa-clock). Prefer the gated
 * `data-permission` when present; fall back for users with `*` (directive
 * used to return before setting the attribute).
 */
export function projectHistoryButton(page: Page): Locator {
    const gated = page.locator(
        'button.btn-icon[data-permission="activities.search"]'
    ).filter({ has: page.locator('i.fa-clock') })

    return gated.or(
        page.locator('button.btn-sm.btn-icon').filter({ has: page.locator('i.fa-clock') })
    ).first()
}

export function logsPanel(page: Page): Locator {
    return page.locator('.logs-activity-container.logs-show')
}

/**
 * Opens Frame → Roles (SetupRoleModal host).
 * Skips when the roles card is absent on this front build.
 */
export async function openFrameRoles(page: Page) {
    await page.goto('/frame/roles')
    await expect(page).toHaveURL(/\/frame\/roles/, { timeout: 15_000 })
    await requireVisible(page, 'DOP-1161', frameRolesCard(page), 10_000)
}

/** Open create-role modal (SetupRoleModal). */
export async function openCreateRoleModal(page: Page) {
    const createBtn = frameRolesCard(page).getByRole('button', {
        name: /Criar papel|Create paper|Create role/i,
    })
    await requireVisible(page, 'DOP-1161 create role', createBtn, 8_000)
    await createBtn.click()

    const modal = page.locator('.modal.show').filter({
        has: page.getByRole('heading', {
            name: /Criar papel de usuário|Create user role/i,
        }),
    })
    await expect(modal.first()).toBeVisible({ timeout: 10_000 })
    return modal.first()
}

/**
 * Probe: DOP-1161 i18n landed when activities.search shows a human label
 * (not the raw key as the primary description).
 */
export async function requireActivitiesSearchI18n(page: Page, modal: Locator) {
    const searchInput = modal.locator('.input-group input.form-control').first()
    await searchInput.fill('activities.search')

    await requireVisible(
        page,
        'DOP-1161 activities.search i18n',
        modal.getByText(ACTIVITIES_SEARCH_LABEL),
        8_000
    )

    await expect(
        modal.locator('.permission-description', { hasText: /^activities\.search$/ })
    ).toHaveCount(0)
}

export function isSearchActivitiesRequest(url: string, method: string) {
    return /\/search-activities\b/.test(url) && method === 'POST'
}

function spaPushProjectTab(page: Page, projectId: string, tab: string) {
    return page.evaluate(
        ({ projectId, tab }) => {
            const el = document.querySelector('#app') as {
                __vue_app__?: {
                    config: {
                        globalProperties: {
                            $router?: { push: (loc: string) => Promise<unknown> }
                        }
                    }
                }
            } | null
            const router = el?.__vue_app__?.config?.globalProperties?.$router
            if (!router) return false
            void router.push(`/projects/${projectId}/details/${tab}`)
            return true
        },
        { projectId, tab }
    )
}

/**
 * Drop activities.search / * from the in-memory auth permissions and remount
 * ProjectDetails so v-permission:hide re-evaluates.
 *
 * Must leave ProjectDetails entirely: tab hops keep ProjectHeader mounted, so
 * the permission directive would not run again. Avoid page.route + route.fetch()
 * (Node DNS cannot reach api.olie.localhost in the e2e container).
 */
export async function stripActivitiesSearchAndRemountProject(
    page: Page,
    projectId: string
) {
    const stripped = await page.evaluate(() => {
        const store = (
            window as unknown as {
                store?: {
                    state: {
                        permission?: {
                            auth_permissions?: Array<{ name: string }>
                        }
                    }
                    commit: (type: string, payload: unknown) => void
                }
            }
        ).store

        if (!store?.state?.permission?.auth_permissions) {
            return { ok: false as const, reason: 'no auth_permissions' }
        }

        const next = store.state.permission.auth_permissions.filter(
            p => p.name !== 'activities.search' && p.name !== '*'
        )
        store.commit('permission/UPDATE_AUTH_PERMISSIONS', next)
        return { ok: true as const, remaining: next.length }
    })

    if (!stripped.ok) {
        throw new Error(`stripActivitiesSearchAndRemountProject: ${stripped.reason}`)
    }

    // Leave ProjectDetails (header stays mounted across overview/tasks hops).
    const left = await page.evaluate(() => {
        const el = document.querySelector('#app') as {
            __vue_app__?: {
                config: {
                    globalProperties: {
                        $router?: { push: (loc: string) => Promise<unknown> }
                    }
                }
            }
        } | null
        const router = el?.__vue_app__?.config?.globalProperties?.$router
        if (!router) return false
        void router.push('/contacts/index')
        return true
    })
    if (!left) throw new Error('Vue router not found on #app')
    await expect(page).toHaveURL(/\/contacts\/index/, { timeout: 20_000 })

    const startedBack = await spaPushProjectTab(page, projectId, 'overview')
    if (!startedBack) throw new Error('Vue router not found on #app')
    await expect(page).toHaveURL(new RegExp(`/projects/${projectId}/details/overview`), {
        timeout: 20_000,
    })

    // Button may be d-none — only wait for it to exist in the DOM.
    await page
        .locator('button.btn-icon[data-permission="activities.search"], button.btn-sm.btn-icon')
        .filter({ has: page.locator('i.fa-clock') })
        .first()
        .waitFor({ state: 'attached', timeout: 15_000 })
        .catch(() => undefined)
}

/**
 * Skip unless the DOP-1161 history control is on the project header.
 * Prefer `data-permission="activities.search"`; fall back to the clock icon
 * (sessions with `*` may omit the attribute on older PermissionDirective).
 */
export async function requireProjectHistoryGate(page: Page) {
    const gated = page
        .locator('button.btn-icon[data-permission="activities.search"]')
        .filter({ has: page.locator('i.fa-clock') })

    try {
        await gated.first().waitFor({ state: 'attached', timeout: 8_000 })
        return
    } catch {
        // fall through
    }

    await requireVisible(
        page,
        'DOP-1161 project history button',
        page.locator('button.btn-sm.btn-icon').filter({ has: page.locator('i.fa-clock') }),
        8_000
    )
}
