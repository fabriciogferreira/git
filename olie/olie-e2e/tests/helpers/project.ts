import { type Page } from '@playwright/test'

function apiBaseUrl() {
    return process.env.E2E_API_URL || 'http://api.olie.localhost'
}

/**
 * Create a disposable project via quick-store (same path as the UI).
 * Must run after loginAsE2EUser so localStorage has the bearer token.
 * New projects pick up the default overview template (includes ContentWidget).
 */
export async function createE2EProject(page: Page): Promise<string> {
    const name = `e2e-${Date.now()}`
    const apiUrl = `${apiBaseUrl()}/api/management/projects/quick-store`

    const result = await page.evaluate(
        async ({ apiUrl, name }) => {
            const token = localStorage.getItem('token')
            if (!token) {
                return { ok: false, status: 0, error: 'missing token', projectId: null as string | null }
            }

            const res = await fetch(apiUrl, {
                method: 'POST',
                headers: {
                    Authorization: `Bearer ${token}`,
                    'Content-Type': 'application/json',
                    Accept: 'application/json',
                },
                body: JSON.stringify({ name, prefix: 'E2E' }),
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
        { apiUrl, name }
    )

    if (!result.ok || !result.projectId) {
        throw new Error(
            `quick-store failed (status=${result.status}): ${result.error ?? 'unknown'} — is api.olie.localhost reachable?`
        )
    }

    return result.projectId
}
