import { test, expect, type Locator, type Page } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { requireFeature } from '../helpers/feature'
import { resolvePageOrigin } from '../helpers/navigation'
import { expectReadableContrast, setResolvedTheme } from '../helpers/theme'

/**
 * DOP-1247 — Execute-agent modal hides the model picker when "Usar o modelo
 * padrão do agente" is on, and shows a badge with that default model name.
 *
 * Opens an existing agent (trial frames often hit the AI-agent creation cap
 * after a few creates). Prefers an agent that already has default_model.
 */

type AgentSummary = {
    id: string
    name?: string
    default_model?: string | null
}

async function listAgentsFromSession(page: Page): Promise<AgentSummary[]> {
    // Fetch inside the page so Traefik host-resolver rules apply (page.request
    // resolves *.olie.localhost to loopback and misses the gateway).
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

async function openAgentDetails(page: Page) {
    const agents = await listAgentsFromSession(page)
    const withDefault =
        agents.find(a => a.default_model) || agents[0]

    test.skip(!withDefault?.id, 'No AI agent available on this frame for DOP-1247')

    await page.goto(
        `${resolvePageOrigin(page)}/ai-agents/${withDefault!.id}/details`
    )
    await expect(page).toHaveURL(
        new RegExp(`/ai-agents/${withDefault!.id}/details`),
        { timeout: 30_000 }
    )
    await expect(
        page.getByRole('button', { name: /Executar Agente|Execute agent/i })
    ).toBeVisible({ timeout: 30_000 })
}

async function openExecuteModal(page: Page): Promise<Locator> {
    const executeBtn = page.getByRole('button', { name: /Executar Agente|Execute agent/i })
    await expect(executeBtn).toBeVisible({ timeout: 20_000 })
    await executeBtn.click()

    const dialog = page.getByRole('dialog').filter({
        hasText: /Executar Agente|Execute agent/i,
    })
    await expect(dialog).toBeVisible({ timeout: 15_000 })
    return dialog
}

function defaultModelToggle(dialog: Locator): Locator {
    return dialog.locator('#ommitCustomModel')
}

test.describe('DOP-1247 hide model selection when using default model', () => {
    test.describe.configure({ timeout: 180_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
        await openAgentDetails(page)
    })

    test('hides model picker and shows default-model badge when toggle is on', async ({
        page,
    }) => {
        const dialog = await openExecuteModal(page)

        await requireFeature(page, {
            id: 'DOP-1247',
            probe: async () => {
                const toggle = defaultModelToggle(dialog)
                if (!(await toggle.isVisible().catch(() => false))) {
                    return false
                }
                await toggle.check({ force: true })
                const pickerGone = await dialog
                    .getByText(/Escolha um modelo para testar|Choose a model to test/i)
                    .isVisible()
                    .then(v => !v)
                    .catch(() => true)
                const badgeVisible = await dialog
                    .locator('span.badge')
                    .first()
                    .isVisible()
                    .catch(() => false)
                return pickerGone && badgeVisible
            },
        })

        const toggle = defaultModelToggle(dialog)
        await toggle.check({ force: true })

        await expect(
            dialog.getByText(/Escolha um modelo para testar|Choose a model to test/i)
        ).toHaveCount(0)
        await expect(dialog.locator('.model-selector')).toHaveCount(0)

        const badge = dialog.locator('span.badge').first()
        await expect(badge).toBeVisible({ timeout: 20_000 })
        await expect(badge).not.toHaveText(/^[\s-]*$/)
        const badgeText = ((await badge.textContent()) || '').trim()
        expect(badgeText.length, 'default-model badge should name the model').toBeGreaterThan(2)

        await toggle.uncheck({ force: true })
        await expect(
            dialog.getByText(/Escolha um modelo para testar|Choose a model to test/i)
        ).toBeVisible({ timeout: 10_000 })
        await expect(dialog.locator('.model-selector, .p-select').first()).toBeVisible()
        await expect(dialog.locator('span.badge')).toHaveCount(0)
    })

    for (const theme of ['light', 'dark'] as const) {
        test(`default-model badge stays readable in ${theme} theme`, async ({ page }) => {
            await setResolvedTheme(page, theme)
            const dialog = await openExecuteModal(page)
            const toggle = defaultModelToggle(dialog)

            await requireFeature(page, {
                id: 'DOP-1247',
                probe: async () => {
                    if (!(await toggle.isVisible().catch(() => false))) {
                        return false
                    }
                    await toggle.check({ force: true })
                    return dialog.locator('span.badge').first().isVisible().catch(() => false)
                },
            })

            await toggle.check({ force: true })
            const badge = dialog.locator('span.badge').first()
            await expect(badge).toBeVisible({ timeout: 20_000 })
            await expect(badge).not.toHaveText(/^[\s-]*$/)
            await expectReadableContrast(badge, `${theme} default-model badge`)
        })
    }
})
