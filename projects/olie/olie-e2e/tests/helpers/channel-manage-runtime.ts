import { type Page, expect, test } from '@playwright/test'
import { listProjectChannels, type E2EChannel } from './channel-conversation'

/**
 * DOP-1154 — runtime helpers for channel-manage automations.
 *
 * Creates automations via the management API (field-change trigger → manage action),
 * fires them by renaming a project, and polls `/channels` until the side-effect appears.
 * Skips when `project_channel_manage_action` is absent on the API under test.
 */

function apiBaseUrl() {
    return process.env.E2E_API_URL || 'http://api.olie.localhost'
}

function uniqueId(prefix: string) {
    return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`
}

export type ChannelManageOperation =
    | 'create'
    | 'rename'
    | 'activate'
    | 'deactivate'
    | 'resolve'
    | 'reopen'

export type ChannelManageActionConfig = {
    operation: ChannelManageOperation
    audience?: 'internal' | 'client'
    channel_name?: string
    new_name?: string
    counterpart_expression?: string
    /** Default on the API is `phone` when omitted. */
    counterpart_input?: 'phone' | 'identifier'
    force_reopen?: boolean
    close_reason?: string
}

type ApiResult<T> = {
    ok: boolean
    status: number
    error: string | null
    data: T | null
}

async function managementFetch<T>(
    page: Page,
    path: string,
    options: { method?: string; body?: unknown } = {}
): Promise<ApiResult<T>> {
    const apiUrl = `${apiBaseUrl()}/api/management${path}`

    return page.evaluate(
        async ({ apiUrl, method, body }) => {
            const token = localStorage.getItem('token')
            if (!token) {
                return { ok: false, status: 0, error: 'missing token', data: null }
            }

            const res = await fetch(apiUrl, {
                method: method ?? 'GET',
                headers: {
                    Authorization: `Bearer ${token}`,
                    'Content-Type': 'application/json',
                    Accept: 'application/json',
                },
                body: body === undefined ? undefined : JSON.stringify(body),
            })

            const json = (await res.json().catch(() => null)) as Record<string, unknown> | null
            const error =
                (typeof json?.message === 'string' ? json.message : null) ??
                (typeof json?.error === 'string' ? json.error : null)

            return {
                ok: res.ok && json?.response === true,
                status: res.status,
                error,
                data: json as T | null,
            }
        },
        { apiUrl, method: options.method ?? 'GET', body: options.body }
    )
}

function isMissingManageAction(result: ApiResult<unknown>) {
    const blob = `${result.error ?? ''} ${JSON.stringify(result.data ?? {})}`.toLowerCase()
    return (
        result.status === 422 ||
        /project_channel_manage_action|invalid.*variant|component_validation|validation_errors/.test(
            blob
        )
    )
}

/**
 * Skip the current test when the API does not expose `project_channel_manage_action`
 * (e.g. develop without the DOP-1154 branch).
 */
export async function requireChannelManageActionApi(page: Page) {
    const probeTitle = `e2e-dop1154-probe-${Date.now()}`
    const triggerId = uniqueId('trig')
    const actionId = uniqueId('act')

    const result = await managementFetch<{ automation?: { id?: string | number } }>(
        page,
        '/automations',
        {
            method: 'POST',
            body: {
                title: probeTitle,
                active: false,
                executions: 0,
                components: [
                    {
                        id: triggerId,
                        type: 'trigger',
                        variant: 'project_field_change_trigger',
                        parent_id: null,
                        conditional_case: null,
                        order: 0,
                        config: { field: 'name' },
                        relations: [],
                    },
                    {
                        id: actionId,
                        type: 'action',
                        variant: 'project_channel_manage_action',
                        parent_id: null,
                        conditional_case: null,
                        order: 1,
                        config: {
                            operation: 'create',
                            audience: 'internal',
                            channel_name: 'e2e-probe-channel',
                        },
                        relations: [],
                    },
                ],
            },
        }
    )

    if (result.ok && result.data?.automation?.id != null) {
        await deleteE2EAutomation(page, result.data.automation.id)
        return
    }

    test.skip(
        isMissingManageAction(result),
        'DOP-1154 project_channel_manage_action not on this API — skipped'
    )

    throw new Error(
        `channel-manage probe failed (status=${result.status}): ${result.error ?? 'unknown'}`
    )
}

/**
 * Active automation: project name change → channel manage action.
 * Returns the automation id for cleanup.
 */
export async function createChannelManageAutomation(
    page: Page,
    options: {
        title?: string
        action: ChannelManageActionConfig
    }
): Promise<string | number> {
    const title = options.title ?? `e2e-dop1154-${Date.now()}`
    const triggerId = uniqueId('trig')
    const actionId = uniqueId('act')

    const result = await managementFetch<{ automation?: { id?: string | number } }>(
        page,
        '/automations',
        {
            method: 'POST',
            body: {
                title,
                active: true,
                executions: 0,
                components: [
                    {
                        id: triggerId,
                        type: 'trigger',
                        variant: 'project_field_change_trigger',
                        parent_id: null,
                        conditional_case: null,
                        order: 0,
                        config: { field: 'name' },
                        relations: [],
                    },
                    {
                        id: actionId,
                        type: 'action',
                        variant: 'project_channel_manage_action',
                        parent_id: null,
                        conditional_case: null,
                        order: 1,
                        config: options.action,
                        relations: [],
                    },
                ],
            },
        }
    )

    if (!result.ok || result.data?.automation?.id == null) {
        if (isMissingManageAction(result)) {
            test.skip(true, 'DOP-1154 project_channel_manage_action not on this API — skipped')
        }
        throw new Error(
            `create automation failed (status=${result.status}): ${result.error ?? 'unknown'}`
        )
    }

    return result.data.automation.id
}

export async function deleteE2EAutomation(page: Page, automationId: string | number) {
    await managementFetch(page, `/automations/${automationId}`, { method: 'DELETE' })
}

/** Fire `project_field_change_trigger` (field=name) by renaming the project. */
export async function renameProjectViaApi(page: Page, projectId: string, name: string) {
    const result = await managementFetch(page, `/projects/${projectId}`, {
        method: 'PUT',
        body: { name },
    })

    if (!result.ok) {
        throw new Error(
            `rename project failed (status=${result.status}): ${result.error ?? 'unknown'}`
        )
    }
}

/** Seed an internal channel without going through the conversation dialog. */
export async function createInternalChannelViaApi(
    page: Page,
    args: { projectId: string; name: string; isActive?: boolean }
): Promise<E2EChannel> {
    const result = await managementFetch<{ channel?: E2EChannel }>(page, '/channels', {
        method: 'POST',
        body: {
            project_id: args.projectId,
            name: args.name,
            audience: 'internal',
            is_active: args.isActive ?? true,
        },
    })

    if (!result.ok || !result.data?.channel?.id) {
        throw new Error(
            `create channel failed (status=${result.status}): ${result.error ?? 'unknown'}`
        )
    }

    return result.data.channel
}

/**
 * Poll project channels until `predicate` matches (automation runs sync on the request,
 * but the list can lag a tick under load).
 */
export async function waitForProjectChannel(
    page: Page,
    projectId: string,
    predicate: (channels: E2EChannel[]) => boolean,
    options: { timeout?: number } = {}
): Promise<E2EChannel[]> {
    const timeout = options.timeout ?? 20_000
    let latest: E2EChannel[] = []

    await expect
        .poll(
            async () => {
                latest = await listProjectChannels(page, projectId)
                return predicate(latest)
            },
            { timeout, intervals: [200, 400, 800, 1_000] }
        )
        .toBe(true)

    return latest
}
