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

function isProjectLimitExceeded(status: number, error: string | null | undefined) {
    return status === 402 || /project_max_limit_exceeded/i.test(error ?? '')
}

/**
 * Soft-delete disposable e2e projects (name contains `e2e-`) to free plan slots.
 * Local frames fill up quickly after stress suites.
 */
export async function purgeE2EProjects(page: Page, nameContains = 'e2e-'): Promise<number> {
    const apiUrl = apiBaseUrl()

    return page.evaluate(
        async ({ apiUrl, nameContains }) => {
            const token = localStorage.getItem('token')
            if (!token) return 0

            const headers = {
                Authorization: `Bearer ${token}`,
                'Content-Type': 'application/json',
                Accept: 'application/json',
            }

            const searchRes = await fetch(`${apiUrl}/api/management/projects/search?perPage=100`, {
                method: 'POST',
                headers,
                body: JSON.stringify({
                    filters: [
                        {
                            field: 'name_code',
                            operator: 'contains',
                            value: nameContains,
                            logical_operator: 'and',
                        },
                    ],
                }),
            })

            const searchData = (await searchRes.json().catch(() => null)) as {
                projects?: Array<{ id?: string; name?: string; code?: string }>
            } | null

            const projects = searchData?.projects ?? []
            let deleted = 0
            const maxDelete = 30

            for (const project of projects) {
                if (deleted >= maxDelete) break
                if (!project.id) continue
                const label = `${project.name ?? ''} ${project.code ?? ''}`.toLowerCase()
                if (!label.includes(nameContains.toLowerCase())) continue

                const del = await fetch(`${apiUrl}/api/management/projects/${project.id}`, {
                    method: 'DELETE',
                    headers,
                })
                if (del.ok) deleted += 1
                // Small gap so delete bursts are less likely to trip 429.
                await new Promise(r => setTimeout(r, 100))
            }

            return deleted
        },
        { apiUrl, nameContains }
    )
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
 * On plan limit (402), purges prior e2e-* projects once and retries.
 */
export async function createE2EProject(
    page: Page,
    options: QuickStoreOptions = {}
): Promise<string> {
    const name = options.name ?? `e2e-${Date.now()}`
    const prefix = options.prefix ?? 'E2E'
    const apiUrl = `${apiBaseUrl()}/api/management/projects/quick-store`
    const maxAttempts = 8
    let purgedForLimit = false

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
            await sleep(Math.min(15_000, 3_000 * 2 ** (attempt - 1)))
            continue
        }

        if (
            !purgedForLimit &&
            isProjectLimitExceeded(result.status, result.error) &&
            attempt < maxAttempts
        ) {
            purgedForLimit = true
            await purgeE2EProjects(page)
            // Cool down after a burst of deletes before retrying create.
            await sleep(5_000)
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
            await sleep(Math.min(15_000, 3_000 * 2 ** (attempt - 1)))
            continue
        }

        throw new Error(`get-available-steps failed: ${result.error}`)
    }

    throw new Error('get-available-steps failed: exhausted retries')
}

/** Empty-state copy on ProjectFunnelTab when `project.funnels.length === 0`. */
export const EMPTY_FUNNELS_ALERT =
    /Nenhum funil de .+ vinculado com este .+|No project funnel linked/i

/**
 * Open a ProjectDetails tab and wait until the project find succeeds.
 * Avoids asserting on a blank shell when find 404/429 (router.go(-1) leaves empty UI).
 * Retries the navigation on 429.
 */
export async function openProjectDetailsTab(
    page: Page,
    projectId: string,
    tab: string = 'overview'
) {
    const maxAttempts = 5

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
        const findResponse = page.waitForResponse(
            response => {
                if (response.request().method() !== 'GET') return false
                let pathname = ''
                try {
                    pathname = new URL(response.url()).pathname
                } catch {
                    return false
                }
                return (
                    pathname.endsWith(`/projects/${projectId}`) &&
                    !pathname.includes('/hierarchy')
                )
            },
            { timeout: 30_000 }
        )

        await page.goto(`/projects/${projectId}/details/${tab}`)
        const response = await findResponse

        if (response.ok()) {
            await expect(page).toHaveURL(new RegExp(`/projects/${projectId}/details`))
            return
        }

        if (response.status() === 429 && attempt < maxAttempts) {
            await sleep(Math.min(15_000, 3_000 * 2 ** (attempt - 1)))
            continue
        }

        throw new Error(
            `project find failed after goto (status=${response.status()} url=${response.url()})`
        )
    }
}

export async function openProjectFunnelTab(page: Page, projectId: string) {
    await openProjectDetailsTab(page, projectId, 'funnel')
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
