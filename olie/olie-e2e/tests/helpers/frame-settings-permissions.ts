import { type Page, expect } from '@playwright/test'

async function spaPush(page: Page, path: string) {
    const started = await page.evaluate(target => {
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
        void router.push(target)
        return true
    }, path)
    if (!started) throw new Error(`Vue router not found on #app (push ${path})`)
}

/**
 * Drop frame_settings.edit.configurations / * from in-memory auth permissions
 * and remount /frame/settings so v-permission and CheckUserPermission re-evaluate.
 *
 * Must use SPA router.push — page.goto reloads get-auth-user and restores grants.
 * Same approach as stripActivitiesSearchAndRemountProject (DOP-1161).
 */
export async function stripFrameSettingsEditConfigurationsAndRemount(
    page: Page
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
            p =>
                p.name !== 'frame_settings.edit.configurations' &&
                p.name !== '*'
        )
        store.commit('permission/UPDATE_AUTH_PERMISSIONS', next)
        return { ok: true as const, remaining: next.length }
    })

    if (!stripped.ok) {
        throw new Error(
            `stripFrameSettingsEditConfigurationsAndRemount: ${stripped.reason}`
        )
    }

    // Leave settings so FrameSettings remounts with the stripped store.
    await spaPush(page, '/contacts/index')
    await expect(page).toHaveURL(/\/contacts\/index/, { timeout: 20_000 })

    await spaPush(page, '/frame/settings')
    await expect(page).toHaveURL(/\/frame\/settings/, { timeout: 20_000 })

    await expect(
        page
            .getByRole('heading', {
                name: /Dados da empresa|Company data|Notificações de usuários|User notifications/i,
            })
            .first()
    ).toBeVisible({ timeout: 15_000 })
}
