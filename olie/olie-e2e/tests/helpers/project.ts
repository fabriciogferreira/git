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

type CreateTemplateOptions = {
    name?: string
    description?: string
    prefix?: string
}

/**
 * Create a project template via POST /projects (is_template: true).
 * Used as the source for clone-from-template flows (DOP-1145).
 */
export async function createE2ETemplate(
    page: Page,
    options: CreateTemplateOptions = {}
): Promise<string> {
    const name = options.name ?? `e2e-tpl-${Date.now()}`
    const description = options.description ?? 'e2e template'
    const prefix = options.prefix ?? 'TPL'
    const apiUrl = `${apiBaseUrl()}/api/management/projects`
    const maxAttempts = 8
    let purgedForLimit = false

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
        const result = await page.evaluate(
            async ({ apiUrl, name, description, prefix }) => {
                const token = localStorage.getItem('token')
                if (!token) {
                    return {
                        ok: false,
                        status: 0,
                        error: 'missing token',
                        projectId: null as string | null,
                    }
                }

                const res = await fetch(apiUrl, {
                    method: 'POST',
                    headers: {
                        Authorization: `Bearer ${token}`,
                        'Content-Type': 'application/json',
                        Accept: 'application/json',
                    },
                    body: JSON.stringify({
                        name,
                        description,
                        prefix,
                        is_template: true,
                    }),
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
            { apiUrl, name, description, prefix }
        )

        if (result.ok && result.projectId) {
            return result.projectId
        }

        if ((result.status === 429 || isRateLimited(result.error)) && attempt < maxAttempts) {
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
            await sleep(5_000)
            continue
        }

        throw new Error(
            `create template failed (status=${result.status}): ${result.error ?? 'unknown'}`
        )
    }

    throw new Error('create template failed: exhausted retries')
}

type CloneFromTemplateOptions = {
    name: string
    description?: string
    funnel_step_id: number | string
}

/**
 * Clone a template with funnel_step_id in the same request (DOP-1145 option A).
 * Mirrors what ProjectCloneModal sends on "Criar e ver" from the kanban.
 */
export async function cloneE2EProjectFromTemplate(
    page: Page,
    templateId: string,
    options: CloneFromTemplateOptions
): Promise<string> {
    const description = options.description ?? 'e2e cloned from template'
    const apiUrl = `${apiBaseUrl()}/api/management/projects/${templateId}/clone`
    const maxAttempts = 8

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
        const result = await page.evaluate(
            async ({ apiUrl, templateId, name, description, funnel_step_id }) => {
                const token = localStorage.getItem('token')
                if (!token) {
                    return {
                        ok: false,
                        status: 0,
                        error: 'missing token',
                        projectId: null as string | null,
                        funnels: [] as unknown[],
                        funnel_steps: [] as unknown[],
                    }
                }

                const res = await fetch(apiUrl, {
                    method: 'POST',
                    headers: {
                        Authorization: `Bearer ${token}`,
                        'Content-Type': 'application/json',
                        Accept: 'application/json',
                    },
                    body: JSON.stringify({
                        project_id: templateId,
                        name,
                        description,
                        customer: true,
                        funnels: true,
                        clone_tags: true,
                        checklists: true,
                        clone_form_answers: true,
                        medias: true,
                        medias_mention: true,
                        forum: true,
                        loose_checklists: true,
                        loose_form_answers: true,
                        clone_groups: true,
                        clone_assignees: true,
                        funnel_step_id,
                    }),
                })

                const data = (await res.json().catch(() => null)) as {
                    response?: boolean
                    project?: {
                        id?: string
                        funnels?: unknown[]
                        funnel_steps?: unknown[]
                    }
                    message?: string
                } | null

                return {
                    ok: res.ok && Boolean(data?.response && data?.project?.id),
                    status: res.status,
                    error: data?.message ?? null,
                    projectId: data?.project?.id ?? null,
                    funnels: data?.project?.funnels ?? [],
                    funnel_steps: data?.project?.funnel_steps ?? [],
                }
            },
            {
                apiUrl,
                templateId,
                name: options.name,
                description,
                funnel_step_id: options.funnel_step_id,
            }
        )

        if (result.ok && result.projectId) {
            if (!result.funnels.length || !result.funnel_steps.length) {
                throw new Error(
                    `DOP-1145: clone response missing funnels/steps (funnels=${result.funnels.length}, steps=${result.funnel_steps.length}) — is api-main option A deployed?`
                )
            }
            return result.projectId
        }

        if ((result.status === 429 || isRateLimited(result.error)) && attempt < maxAttempts) {
            await sleep(Math.min(15_000, 3_000 * 2 ** (attempt - 1)))
            continue
        }

        throw new Error(
            `clone from template failed (status=${result.status}): ${result.error ?? 'unknown'}`
        )
    }

    throw new Error('clone from template failed: exhausted retries')
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
    stepName: string
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
                    steps?: Array<{ id: number; name?: string }>
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
                stepName: step.name ?? String(step.id),
            }
        }, apiUrl)

        if (result.ok) {
            return {
                funnelId: result.funnelId,
                funnelName: result.funnelName,
                stepId: result.stepId,
                stepName: result.stepName,
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

type CreateFunnelWithFormFlagsOptions = {
    name?: string
    stepName?: string
    show_customer_form?: boolean
    show_contact_form?: boolean
    hide_customer_form_when_linked?: boolean
    hide_contact_form_when_linked?: boolean
    /** Template project ids to sync onto the funnel (kanban Opções → templates). */
    template_project_ids?: string[]
}

/**
 * Create a disposable funnel whose first step has customer/contact form flags.
 * Prefer this on empty frames (isolated E2E users).
 */
export async function createE2EFunnelWithStepFormFlags(
    page: Page,
    options: CreateFunnelWithFormFlagsOptions = {}
): Promise<{
    funnelId: number
    funnelName: string
    stepId: number
    stepName: string
}> {
    const funnelName = options.name ?? `e2e-forms-${Date.now()}`
    const stepName = options.stepName ?? `e2e-step-${Date.now()}`
    const apiUrl = `${apiBaseUrl()}/api/management/project-funnel`
    const maxAttempts = 8

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
        const result = await page.evaluate(
            async ({
                apiUrl,
                funnelName,
                stepName,
                show_customer_form,
                show_contact_form,
                hide_customer_form_when_linked,
                hide_contact_form_when_linked,
                template_projects,
            }) => {
                const token = localStorage.getItem('token')
                if (!token) {
                    return { ok: false as const, error: 'missing token' }
                }

                const res = await fetch(apiUrl, {
                    method: 'POST',
                    headers: {
                        Authorization: `Bearer ${token}`,
                        'Content-Type': 'application/json',
                        Accept: 'application/json',
                    },
                    body: JSON.stringify({
                        name: funnelName,
                        steps: [
                            {
                                name: stepName,
                                order: 1,
                                show_customer_form,
                                show_contact_form,
                                hide_customer_form_when_linked,
                                hide_contact_form_when_linked,
                            },
                        ],
                        attachments: [],
                        tags: [],
                        ...(template_projects.length
                            ? { template_projects }
                            : {}),
                    }),
                })

                const data = (await res.json().catch(() => null)) as {
                    response?: boolean
                    project_funnel?: {
                        id?: number
                        name?: string
                        steps?: Array<{ id?: number; name?: string }>
                    }
                    message?: string
                } | null

                const funnel = data?.project_funnel
                let step = funnel?.steps?.[0]

                if (funnel?.id && !step?.id) {
                    const stepsRes = await fetch(
                        apiUrl.replace(/\/project-funnel$/, '/get-available-steps'),
                        {
                            headers: {
                                Authorization: `Bearer ${token}`,
                                Accept: 'application/json',
                            },
                        }
                    )
                    const stepsData = (await stepsRes.json().catch(() => null)) as {
                        funnels?: Array<{
                            id: number
                            steps?: Array<{ id: number; name?: string }>
                        }>
                    } | null
                    const match = stepsData?.funnels?.find(f => f.id === funnel.id)
                    step = match?.steps?.[0]
                }

                if (!res.ok || !funnel?.id || !step?.id) {
                    return {
                        ok: false as const,
                        error:
                            data?.message ??
                            `create funnel failed (status=${res.status}, steps=${funnel?.steps?.length ?? 0})`,
                    }
                }

                return {
                    ok: true as const,
                    funnelId: funnel.id,
                    funnelName: funnel.name ?? funnelName,
                    stepId: step.id,
                    stepName: step.name ?? stepName,
                }
            },
            {
                apiUrl,
                funnelName,
                stepName,
                show_customer_form: options.show_customer_form ?? true,
                show_contact_form: options.show_contact_form ?? false,
                hide_customer_form_when_linked:
                    options.hide_customer_form_when_linked ?? false,
                hide_contact_form_when_linked:
                    options.hide_contact_form_when_linked ?? false,
                template_projects: (options.template_project_ids ?? []).map(id => ({
                    id,
                })),
            }
        )

        if (result.ok) {
            return {
                funnelId: result.funnelId,
                funnelName: result.funnelName,
                stepId: result.stepId,
                stepName: result.stepName,
            }
        }

        if (isRateLimited(result.error) && attempt < maxAttempts) {
            await sleep(Math.min(15_000, 3_000 * 2 ** (attempt - 1)))
            continue
        }

        throw new Error(`createE2EFunnelWithStepFormFlags failed: ${result.error}`)
    }

    throw new Error('createE2EFunnelWithStepFormFlags failed: exhausted retries')
}

/**
 * Enable customer/contact form flags on the first available funnel step
 * (reuses an existing active funnel — shared seed frames).
 */
export async function enableE2EStepFormFlags(
    page: Page,
    options: CreateFunnelWithFormFlagsOptions = {}
): Promise<{
    funnelId: number
    funnelName: string
    stepId: number
    stepName: string
}> {
    const show_customer_form = options.show_customer_form ?? true
    const show_contact_form = options.show_contact_form ?? false
    const hide_customer_form_when_linked =
        options.hide_customer_form_when_linked ?? false
    const hide_contact_form_when_linked =
        options.hide_contact_form_when_linked ?? false

    const { funnelId, funnelName, stepId, stepName } = await getFirstFunnelStepId(page)
    const apiUrl = apiBaseUrl()
    const maxAttempts = 8

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
        const result = await page.evaluate(
            async ({
                apiUrl,
                funnelId,
                stepId,
                show_customer_form,
                show_contact_form,
                hide_customer_form_when_linked,
                hide_contact_form_when_linked,
            }) => {
                const token = localStorage.getItem('token')
                if (!token) {
                    return { ok: false as const, error: 'missing token' }
                }

                const headers = {
                    Authorization: `Bearer ${token}`,
                    'Content-Type': 'application/json',
                    Accept: 'application/json',
                }

                const findRes = await fetch(`${apiUrl}/api/management/get-project-funnels`, {
                    method: 'POST',
                    headers,
                    body: JSON.stringify({ project_funnel_id: funnelId }),
                })
                const findData = (await findRes.json().catch(() => null)) as {
                    response?: boolean
                    project_funnel?: Record<string, unknown> & {
                        id?: number
                        name?: string
                        steps?: Array<Record<string, unknown> & { id?: number; name?: string }>
                    }
                    message?: string
                } | null

                const funnel = findData?.project_funnel
                if (!findRes.ok || !funnel?.id || !funnel.steps?.length) {
                    return {
                        ok: false as const,
                        error:
                            findData?.message ??
                            `get-project-funnels failed (status=${findRes.status})`,
                    }
                }

                const steps = funnel.steps.map(step => {
                    if (step.id !== stepId) return step
                    return {
                        ...step,
                        show_customer_form,
                        show_contact_form,
                        hide_customer_form_when_linked,
                        hide_contact_form_when_linked,
                    }
                })

                const saveRes = await fetch(`${apiUrl}/api/management/project-funnel`, {
                    method: 'POST',
                    headers,
                    body: JSON.stringify({
                        ...funnel,
                        steps,
                        attachments: funnel.attachments ?? [],
                        tags: funnel.tags ?? [],
                    }),
                })
                const saveData = (await saveRes.json().catch(() => null)) as {
                    response?: boolean
                    message?: string
                } | null

                if (!saveRes.ok || !saveData?.response) {
                    return {
                        ok: false as const,
                        error:
                            saveData?.message ??
                            `project-funnel save failed (status=${saveRes.status})`,
                    }
                }

                const updatedStep = steps.find(s => s.id === stepId)
                return {
                    ok: true as const,
                    funnelId: funnel.id,
                    funnelName: funnel.name ?? String(funnel.id),
                    stepId,
                    stepName: updatedStep?.name ?? String(stepId),
                }
            },
            {
                apiUrl,
                funnelId,
                stepId,
                show_customer_form,
                show_contact_form,
                hide_customer_form_when_linked,
                hide_contact_form_when_linked,
            }
        )

        if (result.ok) {
            return {
                funnelId: result.funnelId,
                funnelName: result.funnelName || funnelName,
                stepId: result.stepId,
                stepName: result.stepName || stepName,
            }
        }

        if (isRateLimited(result.error) && attempt < maxAttempts) {
            await sleep(Math.min(15_000, 3_000 * 2 ** (attempt - 1)))
            continue
        }

        throw new Error(`enableE2EStepFormFlags failed: ${result.error}`)
    }

    throw new Error('enableE2EStepFormFlags failed: exhausted retries')
}

/** Open the project funnel kanban and select a funnel by id/name. */
export async function openProjectFunnelKanban(
    page: Page,
    funnelId: number,
    funnelName?: string
) {
    // Prefer the page's current origin (isolated frames). Relative goto would
    // hit Playwright baseURL (devframe) and leave the wrong company.
    let origin: string
    try {
        origin = new URL(page.url()).origin
        if (origin === 'null' || origin.startsWith('about:')) {
            origin = apiBaseUrl().replace('api.', 'devframe.')
        }
    } catch {
        origin = (process.env.E2E_BASE_URL || 'http://devframe.olie.localhost').replace(
            /\/$/,
            ''
        )
    }

    await page.goto(`${origin}/projects/funnels?project_funnel=${funnelId}`)
    await expect(page).toHaveURL(/\/projects\/funnels/)

    // Wait until kanban columns or empty tip resolve after funnel list load.
    const emptyTip = page.getByText(
        /Após selecionar o kanban|After selecting the kanban/i
    )
    const optionsBtn = page.getByRole('button', { name: /^(Opções|Options)$/i })

    try {
        await optionsBtn.first().waitFor({ state: 'visible', timeout: 20_000 })
        return
    } catch {
        // Fall through — select funnel from combobox.
    }

    if ((await emptyTip.count()) === 0) return

    const funnelCombo = page.getByRole('combobox', {
        name: /Selecione um funil|Select a funnel|Sem área|funil/i,
    }).first()
    await expect(funnelCombo).toBeVisible({ timeout: 20_000 })
    await funnelCombo.click()

    const optionName = funnelName
        ? new RegExp(funnelName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i')
        : new RegExp(String(funnelId))

    const option = page.getByRole('option', { name: optionName }).first()
    await expect(option).toBeVisible({ timeout: 15_000 })
    await option.click()

    await expect(optionsBtn.first()).toBeVisible({ timeout: 30_000 })
}

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
