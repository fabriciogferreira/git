import { type Page, expect } from '@playwright/test'

function apiBaseUrl() {
    return process.env.E2E_API_URL || 'http://api.olie.localhost'
}

function isRateLimited(error: string | null | undefined) {
    return /too_many_requests|too many requests|429/i.test(error ?? '')
}

async function sleep(ms: number) {
    await new Promise(r => setTimeout(r, ms))
}

type QuickStoreOptions = {
    name?: string
    prefix?: string
    funnel_step_id?: number | string
}

/**
 * Create a disposable project via quick-store (same path as the UI).
 * Must run after loginAsE2EUser so localStorage has the bearer token.
 * Pass `funnel_step_id` to link the project to a kanban step (has funnels on details).
 */
export async function createE2EProject(
    page: Page,
    options: QuickStoreOptions = {}
): Promise<string> {
    const name = options.name ?? `e2e-${Date.now()}`
    const prefix = options.prefix ?? 'E2E'
    const apiUrl = `${apiBaseUrl()}/api/management/projects/quick-store`
    const maxAttempts = 8

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
        const result = await page.evaluate(
            async ({ apiUrl, name, prefix, funnel_step_id }) => {
                const token = localStorage.getItem('token')
                if (!token) {
                    return {
                        ok: false,
                        status: 0,
                        error: 'missing token',
                        projectId: null as string | null,
                    }
                }

                const body: Record<string, unknown> = { name, prefix }
                if (funnel_step_id != null) body.funnel_step_id = funnel_step_id

                const res = await fetch(apiUrl, {
                    method: 'POST',
                    headers: {
                        Authorization: `Bearer ${token}`,
                        'Content-Type': 'application/json',
                        Accept: 'application/json',
                    },
                    body: JSON.stringify(body),
                })

                const data = (await res.json().catch(() => null)) as {
                    response?: boolean
                    project?: { id?: string }
                    message?: string
                } | null

                return {
                    ok: res.ok && Boolean(data?.response && data?.project?.id),
                    status: res.status,
                    error: data?.message ?? null,
                    projectId: data?.project?.id ?? null,
                }
            },
            { apiUrl, name, prefix, funnel_step_id: options.funnel_step_id ?? null }
        )

        if (result.ok && result.projectId) {
            return result.projectId
        }

        const rateLimited =
            result.status === 429 || isRateLimited(result.error)
        if (rateLimited && attempt < maxAttempts) {
            await sleep(Math.min(8_000, 1_500 * 2 ** (attempt - 1)))
            continue
        }

        throw new Error(
            `quick-store failed (status=${result.status}): ${result.error ?? 'unknown'} — is api.olie.localhost reachable?`
        )
    }

    throw new Error('quick-store failed: exhausted retries')
}

/**
 * First funnel step from `/get-available-steps` (includes nested `steps`).
 * GET `/get-project-funnels` does NOT load steps — only listing metadata.
 * Retries on API rate limit so suite noise does not mask DOP-1145.
 */
export async function getFirstFunnelStepId(page: Page): Promise<{
    funnelId: number
    funnelName: string
    stepId: number
}> {
    const apiUrl = `${apiBaseUrl()}/api/management/get-available-steps`
    const maxAttempts = 8

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
        const result = await page.evaluate(async apiUrl => {
            const token = localStorage.getItem('token')
            if (!token) {
                return { ok: false as const, error: 'missing token' }
            }

            const res = await fetch(apiUrl, {
                headers: {
                    Authorization: `Bearer ${token}`,
                    Accept: 'application/json',
                },
            })
            const data = (await res.json().catch(() => null)) as {
                response?: boolean
                funnels?: Array<{
                    id: number
                    name: string
                    steps?: Array<{ id: number }>
                }>
                message?: string
            } | null

            const funnel = data?.funnels?.find(f => (f.steps?.length ?? 0) > 0)
            const step = funnel?.steps?.[0]

            if (!res.ok || !funnel || !step) {
                return {
                    ok: false as const,
                    error:
                        data?.message ??
                        `no funnel with steps (status=${res.status}, funnels=${data?.funnels?.length ?? 0})`,
                }
            }

            return {
                ok: true as const,
                funnelId: funnel.id,
                funnelName: funnel.name,
                stepId: step.id,
            }
        }, apiUrl)

        if (result.ok) {
            return {
                funnelId: result.funnelId,
                funnelName: result.funnelName,
                stepId: result.stepId,
            }
        }

        if (isRateLimited(result.error) && attempt < maxAttempts) {
            await sleep(Math.min(8_000, 1_500 * 2 ** (attempt - 1)))
            continue
        }

        throw new Error(`get-available-steps failed: ${result.error}`)
    }

    throw new Error('get-available-steps failed: exhausted retries')
}

/** Empty-state copy on ProjectFunnelTab when `project.funnels.length === 0`. */
export const EMPTY_FUNNELS_ALERT =
    /Nenhum funil de .+ vinculado com este .+|No project funnel linked/i

export async function openProjectFunnelTab(page: Page, projectId: string) {
    await page.goto(`/projects/${projectId}/details/funnel`)
    await expect(page).toHaveURL(new RegExp(`/projects/${projectId}/details/funnel`))
}

/**
 * Client-side Vue Router navigation (keeps the app + KeepAlive mounted).
 * Full `page.goto` remounts the app and hides KeepAlive reuse bugs (DOP-1145).
 *
 * Do NOT await `router.push` inside `evaluate`: `<transition mode="out-in">` can
 * hang the promise. Callers should already be on a settled internal route
 * (preferably ProjectDetails) — `/overview` replaces its query and aborts pushes.
 */
export async function spaNavigateToProjectFunnel(page: Page, projectId: string) {
    const path = `/projects/${projectId}/details/funnel`

    const started = await page.evaluate(targetPath => {
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
        void router.push(targetPath)
        return true
    }, path)

    if (!started) {
        throw new Error('Vue router not found on #app')
    }

    await expect(page).toHaveURL(new RegExp(`/projects/${projectId}/details/funnel`), {
        timeout: 20_000,
    })
}
