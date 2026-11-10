import { test, expect, type Page } from '@playwright/test'
import { loginAsIsolatedE2EUser } from '../helpers/isolated-user'
import { resolvePageOrigin } from '../helpers/navigation'
import { createE2EProject } from '../helpers/project'
import { requireFeature } from '../helpers/feature'
import {
    createChannelViaApi,
    createE2ECommunicationIntegration,
    deleteE2ECommunicationIntegration,
    e2eCounterpart,
} from '../helpers/channel-conversation'

/**
 * OS-566 — on mention details, other channels (e.g. WhatsApp) must stay selectable so the
 * user can open and read them. The old ContentWidget locked ChannelSelector whenever
 * `aroundMedia` was set; switching away must leave mention/around mode.
 */

function apiBaseUrl() {
    return process.env.E2E_API_URL || 'http://api.olie.localhost'
}

async function currentUser(page: Page): Promise<{ id: string; name: string }> {
    const apiUrl = `${apiBaseUrl()}/api/management/get-auth-user`

    const result = await page.evaluate(async ({ apiUrl }) => {
        const token = localStorage.getItem('token')
        if (!token) return { ok: false as const, error: 'missing token' }

        const res = await fetch(apiUrl, {
            headers: {
                Authorization: `Bearer ${token}`,
                Accept: 'application/json',
            },
        })
        const data = (await res.json().catch(() => null)) as {
            response?: boolean
            user?: { id?: string; name?: string }
            message?: string
        } | null

        if (!res.ok || !data?.response || !data.user?.id) {
            return { ok: false as const, error: data?.message ?? `status=${res.status}` }
        }

        return {
            ok: true as const,
            id: data.user.id,
            name: data.user.name ?? 'E2E',
        }
    }, { apiUrl })

    if (!result.ok) {
        throw new Error(`get-auth-user failed: ${result.error}`)
    }

    return { id: result.id, name: result.name }
}

/** Post a Principal-channel text media that mentions the current user (creates a Mention row). */
async function saveMentionMedia(
    page: Page,
    args: { projectId: string; userId: string; userName: string; textMarker: string }
): Promise<string> {
    const apiUrl = `${apiBaseUrl()}/api/management/save-media`
    const text = `<u@${args.userId}:${args.userName}> ${args.textMarker}`

    const result = await page.evaluate(
        async ({ apiUrl, projectId, text }) => {
            const token = localStorage.getItem('token')
            if (!token) return { ok: false as const, error: 'missing token' }

            const form = new FormData()
            form.append('project_ids[]', projectId)
            form.append('type', '1')
            form.append('text', text)

            const res = await fetch(apiUrl, {
                method: 'POST',
                headers: {
                    Authorization: `Bearer ${token}`,
                    Accept: 'application/json',
                },
                body: form,
            })

            const data = (await res.json().catch(() => null)) as {
                response?: boolean
                media?: { id?: string }
                medias?: Array<{ id?: string }>
                message?: string
            } | null

            const mediaId = data?.media?.id ?? data?.medias?.[0]?.id
            if (!res.ok || !data?.response || !mediaId) {
                return { ok: false as const, error: data?.message ?? `status=${res.status}` }
            }

            return { ok: true as const, mediaId }
        },
        { apiUrl, projectId: args.projectId, text }
    )

    if (!result.ok) {
        throw new Error(`save-media failed: ${result.error}`)
    }

    return result.mediaId
}

async function findMentionIdForMedia(page: Page, mediaId: string): Promise<number> {
    const apiUrl = `${apiBaseUrl()}/api/management/mentions?perPage=30`

    const result = await page.evaluate(
        async ({ apiUrl, mediaId }) => {
            const token = localStorage.getItem('token')
            if (!token) return { ok: false as const, error: 'missing token' }

            const res = await fetch(apiUrl, {
                headers: {
                    Authorization: `Bearer ${token}`,
                    Accept: 'application/json',
                },
            })

            const data = (await res.json().catch(() => null)) as {
                response?: boolean
                mentions?: { data?: Array<{ id?: number; media?: { id?: string } }> }
                message?: string
            } | null

            if (!res.ok || !data?.response) {
                return { ok: false as const, error: data?.message ?? `status=${res.status}` }
            }

            const hit = (data.mentions?.data ?? []).find(item => item.media?.id === mediaId)
            if (!hit?.id) {
                return { ok: false as const, error: 'mention not found for media' }
            }

            return { ok: true as const, id: hit.id }
        },
        { apiUrl, mediaId }
    )

    if (!result.ok) {
        throw new Error(`find mention failed: ${result.error}`)
    }

    return result.id
}

function channelTab(page: Page, name: RegExp) {
    return page.locator('.channel-tabs button.btn').filter({ hasText: name }).first()
}

test.describe('OS-566 mention details channel switch', () => {
    test.describe.configure({ timeout: 240_000 })

    test.beforeEach(async ({ page, request }, testInfo) => {
        await loginAsIsolatedE2EUser(page, request, { workerIndex: testInfo.parallelIndex })
    })

    test('keeps WhatsApp selectable on mention details and loads without around_id', async ({
        page,
    }) => {
        const integration = await createE2ECommunicationIntegration(page)
        const projectId = await createE2EProject(page, {
            name: `os566-mention-channels-${Date.now()}`,
        })
        const counterpart = e2eCounterpart()
        const marker = `os566-${Date.now()}`

        try {
            const created = await createChannelViaApi(page, {
                projectId,
                name: 'WhatsApp',
                integrationId: integration.id,
                externalRef: counterpart.externalRef,
                isActive: true,
            })
            expect(created.status, JSON.stringify(created.channel)).toBe(201)
            expect(created.channel?.id).toBeTruthy()

            const user = await currentUser(page)
            const mediaId = await saveMentionMedia(page, {
                projectId,
                userId: user.id,
                userName: user.name,
                textMarker: marker,
            })
            const mentionId = await findMentionIdForMedia(page, mediaId)

            await page.goto(`${resolvePageOrigin(page)}/mentions/${mentionId}/details`)
            await expect(page.getByText(/Detalhes da menção|Mention details/i).first()).toBeVisible({
                timeout: 35_000,
            })
            await expect(page.locator('#project_media_content')).toBeVisible({ timeout: 35_000 })

            const whatsapp = channelTab(page, /^WhatsApp$/i)
            await requireFeature(page, {
                id: 'OS-566',
                probe: async () => {
                    try {
                        await whatsapp.waitFor({ state: 'visible', timeout: 12_000 })
                        return await whatsapp.isEnabled()
                    } catch {
                        return false
                    }
                },
            })

            await expect(whatsapp).toBeEnabled()
            await expect(channelTab(page, /Principal|Main/i)).toBeEnabled()

            const mediaLoad = page.waitForResponse(
                response => {
                    // ContentWidget loads media via POST /projects/{id}/media?channel_id=…
                    if (response.request().method() !== 'POST' || !response.ok()) return false
                    const url = response.url()
                    if (!url.includes(`/projects/${projectId}/media`)) return false
                    if (!url.includes(`channel_id=${created.channel!.id}`)) return false
                    return !/[?&]around_id=/.test(url)
                },
                { timeout: 30_000 }
            )

            await whatsapp.click()
            await mediaLoad

            await expect(whatsapp).toHaveClass(/active/)
        } finally {
            await deleteE2ECommunicationIntegration(page, integration.id)
        }
    })
})
