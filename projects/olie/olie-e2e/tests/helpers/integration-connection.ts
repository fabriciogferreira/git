import { type Page } from '@playwright/test'

const API_INTERNAL = process.env.E2E_API_INTERNAL || 'http://olie-api-main:8080'

export type E2EConnectionState = 'unknown' | 'connecting' | 'connected' | 'disconnected'

/**
 * Rewrite `connection_state` / `connection_state_changed_at` on integration CRUD JSON.
 *
 * The field is not writable from the management API (backend `RecordIntegrationConnectionState`
 * only), so feature specs that need connected/disconnected use this stub. `route.fetch` goes to
 * `olie-api-main` on the compose network — Node inside the e2e container cannot resolve
 * `api.olie.localhost` (see activity-history helper notes).
 */
export async function mockIntegrationConnectionState(
    page: Page,
    integrationId: string,
    fields: {
        connection_state: E2EConnectionState
        connection_state_changed_at: string | null
    }
) {
    await page.route(/\/api\/management\/integrations/, async route => {
        const request = route.request()
        const method = request.method()

        if (method !== 'GET' && method !== 'PUT' && method !== 'POST') {
            await route.continue()
            return
        }

        let pathname: string
        let search: string
        try {
            const original = new URL(request.url())
            pathname = original.pathname
            search = original.search
        } catch {
            await route.continue()
            return
        }

        // CRUD only — leave /logs, /status, /qr, /reconnect, /disconnect alone.
        const isIndex = /\/api\/management\/integrations\/?$/.test(pathname)
        const isMember = /\/api\/management\/integrations\/[0-9a-f-]{36}\/?$/i.test(pathname)
        if (!isIndex && !isMember) {
            await route.continue()
            return
        }

        const headers = { ...request.headers(), host: 'api.olie.localhost' }
        const response = await route.fetch({
            url: `${API_INTERNAL}${pathname}${search}`,
            method,
            headers,
            postData: request.postData() ?? undefined,
        })

        const json = (await response.json().catch(() => null)) as {
            integrations?: Array<Record<string, unknown> & { id?: string }>
            integration?: Record<string, unknown> & { id?: string }
        } | null

        if (json) {
            if (Array.isArray(json.integrations)) {
                json.integrations = json.integrations.map(item =>
                    item.id === integrationId ? { ...item, ...fields } : item
                )
            }
            if (json.integration?.id === integrationId) {
                json.integration = { ...json.integration, ...fields }
            }
        }

        await route.fulfill({
            status: response.status(),
            contentType: 'application/json',
            body: JSON.stringify(json),
        })
    })
}
