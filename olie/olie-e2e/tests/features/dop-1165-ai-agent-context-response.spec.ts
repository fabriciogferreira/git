import { test, expect, type Page } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { requireFeature, requireVisible } from '../helpers/feature'
import { resolvePageOrigin } from '../helpers/navigation'
import { expectReadableContrast, setResolvedTheme } from '../helpers/theme'

/**
 * DOP-1165 — AI agent context routes return `response: true` and the contexts
 * panel on agent details still lists / creates / deletes text contexts.
 */

type AgentSummary = { id: string; name?: string }

async function listAgentsFromSession(page: Page): Promise<AgentSummary[]> {
    const api = (process.env.E2E_API_URL || 'http://api.olie.localhost').replace(/\/$/, '')
    return page.evaluate(async apiBase => {
        const token = localStorage.getItem('token')
        if (!token) {
            return []
        }
        const res = await fetch(`${apiBase}/api/management/ai/agents`, {
            headers: {
                accept: 'application/json',
                authorization: `Bearer ${token}`,
            },
        })
        if (!res.ok) {
            return []
        }
        const body = await res.json()
        return Array.isArray(body.agents) ? body.agents : []
    }, api)
}

async function openAgentDetails(page: Page): Promise<string> {
    const agents = await listAgentsFromSession(page)
    const agent = agents[0]
    test.skip(!agent?.id, 'No AI agent available on this frame for DOP-1165')

    await page.goto(`${resolvePageOrigin(page)}/ai-agents/${agent!.id}/details`)
    await expect(page).toHaveURL(
        new RegExp(`/ai-agents/${agent!.id}/details`),
        { timeout: 30_000 }
    )
    return agent!.id
}

function contextsCard(page: Page) {
    return page.locator('.card').filter({
        has: page.getByRole('heading', { name: /Contextos|Contexts/i }),
    })
}

test.describe('DOP-1165 AI agent context response envelope', () => {
    test.describe.configure({ timeout: 180_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
    })

    test('contexts UI create/delete and API envelopes include response:true', async ({
        page,
    }) => {
        const agentId = await openAgentDetails(page)
        const card = contextsCard(page)

        await requireVisible(page, 'DOP-1165 contexts panel', card, 20_000)

        const unique = `DOP-1165 e2e ${Date.now()}`

        const listResponsePromise = page.waitForResponse(
            r =>
                new RegExp(`/ai/agents/${agentId}/contexts/?$`).test(r.url()) &&
                r.request().method() === 'GET' &&
                r.status() === 200,
            { timeout: 30_000 }
        )

        // Initial list may already have fired; trigger a soft reload of details.
        await page.reload()
        await requireVisible(page, 'DOP-1165 contexts panel after reload', card, 20_000)

        const listResponse = await listResponsePromise
        const listBody = await listResponse.json()
        expect(listBody.response, 'GET contexts must include response:true').toBe(true)
        expect(Array.isArray(listBody.contexts)).toBe(true)

        await requireFeature(page, {
            id: 'DOP-1165',
            probe: async () => {
                const input = card.locator('textarea').first()
                return input.isVisible().catch(() => false)
            },
        })

        const textarea = card.locator('textarea').first()
        const sendBtn = card.locator('button.btn-icon.btn-primary').first()
        await textarea.fill(unique)
        await expect(sendBtn).toBeEnabled({ timeout: 5_000 })

        const [createResponse] = await Promise.all([
            page.waitForResponse(
                r =>
                    /\/ai\/agents\/[^/]+\/contexts\/?$/.test(r.url()) &&
                    r.request().method() === 'POST',
                { timeout: 30_000 }
            ),
            sendBtn.click(),
        ])
        expect(createResponse.status()).toBe(201)
        const createBody = await createResponse.json()
        expect(createBody.response, 'POST context must include response:true').toBe(true)
        expect(createBody.context?.content).toBe(unique)
        const contextId = createBody.context?.id as string
        expect(contextId).toBeTruthy()

        await expect(card.getByText(unique)).toBeVisible({ timeout: 20_000 })

        // Update is file-oriented in the UI; assert the PUT envelope from the session.
        const api = (process.env.E2E_API_URL || 'http://api.olie.localhost').replace(/\/$/, '')
        const updatedContent = `${unique} updated`
        const updateBody = await page.evaluate(
            async ({ apiBase, agentId: aid, contextId: cid, content }) => {
                const token = localStorage.getItem('token')
                const res = await fetch(
                    `${apiBase}/api/management/ai/agents/${aid}/contexts/${cid}`,
                    {
                        method: 'PUT',
                        headers: {
                            accept: 'application/json',
                            'content-type': 'application/json',
                            authorization: `Bearer ${token}`,
                        },
                        body: JSON.stringify({ content }),
                    }
                )
                return { status: res.status, body: await res.json() }
            },
            { apiBase: api, agentId, contextId, content: updatedContent }
        )
        expect(updateBody.status).toBe(200)
        expect(updateBody.body.response, 'PUT context must include response:true').toBe(true)
        expect(updateBody.body.context?.content).toBe(updatedContent)

        await page.reload()
        await requireVisible(page, 'DOP-1165 contexts after update', card, 20_000)
        await expect(card.getByText(updatedContent)).toBeVisible({ timeout: 20_000 })

        const deleteResponsePromise = page.waitForResponse(
            r =>
                new RegExp(`/ai/agents/${agentId}/contexts/${contextId}/?$`).test(r.url()) &&
                r.request().method() === 'DELETE',
            { timeout: 30_000 }
        )

        await card
            .locator('.w-100.d-flex')
            .filter({ hasText: updatedContent })
            .locator('button.btn-light-danger')
            .click()

        const confirm = page.locator('.swal2-container').getByRole('button', {
            name: /Sim, excluir|Yes, delete|Confirm/i,
        })
        await expect(confirm).toBeVisible({ timeout: 10_000 })
        await confirm.click()

        const deleteResponse = await deleteResponsePromise
        expect(deleteResponse.ok()).toBe(true)
        const deleteBody = await deleteResponse.json()
        expect(deleteBody.response, 'DELETE context must include response:true').toBe(true)

        await expect(card.getByText(updatedContent)).toHaveCount(0, { timeout: 20_000 })
    })

    test('contexts panel text contrast holds in light and dark themes', async ({ page }) => {
        await openAgentDetails(page)
        const card = contextsCard(page)
        await requireVisible(page, 'DOP-1165 contexts contrast', card, 20_000)

        // Title is the primary copy on the contexts panel. Helper / empty-state
        // `.text-muted` / `.alert-info` contrast is a pre-existing Metronic pattern
        // outside this card's API envelope change.
        const title = card.getByRole('heading', { name: /Contextos|Contexts/i })

        for (const theme of ['light', 'dark'] as const) {
            await setResolvedTheme(page, theme)
            await expectReadableContrast(title, `DOP-1165 contexts title (${theme})`)
        }
    })
})
