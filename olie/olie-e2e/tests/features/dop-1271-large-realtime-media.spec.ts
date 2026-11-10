import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { createE2EProject } from '../helpers/project'
import {
    openProjectContentTab,
    openProjectOverview,
    setContentFilter,
} from '../helpers/content-media'

/**
 * DOP-1271 — oversized realtime media arrives with `incomplete: true` and the
 * open chat must fetch the full row (`around_id`) so the message still appears
 * without a page reload.
 */

function apiBaseUrl() {
    return process.env.E2E_API_URL || 'http://api.olie.localhost'
}

/** Pad past Reverb's ~10k max_message_size so Media::broadcastWith strips text. */
function oversizedMessage(marker: string): string {
    return `${marker}\n${'X'.repeat(12_000)}`
}

async function saveOversizedMedia(page: import('@playwright/test').Page, projectId: string, text: string) {
    const apiUrl = `${apiBaseUrl()}/api/management/save-media`

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
        { apiUrl, projectId, text }
    )

    if (!result.ok) {
        throw new Error(`save-media failed: ${result.error}`)
    }

    return result.mediaId
}

test.describe.configure({ timeout: 120_000 })

test('overview: incomplete realtime media is resolved via around_id fetch', async ({ browser }) => {
    const marker = `e2e-dop-1271-overview-${Date.now()}`
    const text = oversizedMessage(marker)

    const viewerContext = await browser.newContext()
    const senderContext = await browser.newContext()
    const viewer = await viewerContext.newPage()
    const sender = await senderContext.newPage()

    try {
        await loginAsE2EUser(viewer)
        const projectId = await createE2EProject(viewer)

        await loginAsE2EUser(sender)

        await openProjectOverview(viewer, projectId)
        await setContentFilter(viewer, 'content')

        // Presence join needs a beat before the peer broadcast lands.
        await viewer.waitForTimeout(1500)

        // MediaService posts to `/projects/{id}/media?around_id=…` (singular).
        const aroundFetch = viewer.waitForResponse(
            r =>
                r.request().method() === 'POST' &&
                r.url().includes(`/projects/${projectId}/media`) &&
                r.url().includes('around_id=') &&
                r.ok(),
            { timeout: 45_000 }
        )

        const mediaId = await saveOversizedMedia(sender, projectId, text)
        expect(mediaId).toBeTruthy()

        await aroundFetch
        await expect(viewer.locator('#project_media_content').getByText(marker)).toBeVisible({
            timeout: 45_000,
        })
    } finally {
        await viewerContext.close()
        await senderContext.close()
    }
})

test('content tab: incomplete realtime media is resolved via around_id fetch', async ({ browser }) => {
    const marker = `e2e-dop-1271-content-${Date.now()}`
    const text = oversizedMessage(marker)

    const viewerContext = await browser.newContext()
    const senderContext = await browser.newContext()
    const viewer = await viewerContext.newPage()
    const sender = await senderContext.newPage()

    try {
        await loginAsE2EUser(viewer)
        const projectId = await createE2EProject(viewer)

        await loginAsE2EUser(sender)

        await openProjectContentTab(viewer, projectId)
        await setContentFilter(viewer, 'content')

        await viewer.waitForTimeout(1500)

        const aroundFetch = viewer.waitForResponse(
            r =>
                r.request().method() === 'POST' &&
                r.url().includes(`/projects/${projectId}/media`) &&
                r.url().includes('around_id=') &&
                r.ok(),
            { timeout: 45_000 }
        )

        const mediaId = await saveOversizedMedia(sender, projectId, text)
        expect(mediaId).toBeTruthy()

        await aroundFetch
        await expect(viewer.locator('#media_conversation_content').getByText(marker)).toBeVisible({
            timeout: 45_000,
        })
    } finally {
        await viewerContext.close()
        await senderContext.close()
    }
})
