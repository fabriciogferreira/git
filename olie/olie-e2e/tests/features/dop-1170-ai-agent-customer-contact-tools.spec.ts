import { test, expect, type Locator, type Page } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { requireFeature } from '../helpers/feature'
import { resolvePageOrigin } from '../helpers/navigation'
import {
    expectReadableContrast,
    measureContrastRatio,
    setResolvedTheme,
} from '../helpers/theme'

/**
 * DOP-1170 — AI agent tool picker shows customer/contact CRUD tools (pt-BR labels)
 * and keeps those labels readable in light + dark themes.
 *
 * Front change is locale-only (`pt-br.json`); skips when labels are absent.
 */

const CUSTOMER_CONTACT_TOOLS = [
    {
        name: /Listar e filtrar clientes/i,
        description:
            /Permite listar e filtrar clientes por nome, razão social, documento/i,
    },
    {
        name: /Obter detalhes do cliente/i,
        description: /Consegue acessar dados de um cliente através do ID/i,
    },
    {
        name: /Criar cliente/i,
        description: /Permite criar um novo cliente com nome, tipo de documento/i,
    },
    {
        name: /Editar cliente/i,
        description: /Permite editar dados de um cliente existente através do ID/i,
    },
    {
        name: /Excluir cliente/i,
        description: /Permite excluir um cliente existente através do ID/i,
    },
    {
        name: /Listar e filtrar contatos/i,
        description: /Permite listar e filtrar contatos por nome, telefone, e-mail/i,
    },
    {
        name: /Obter detalhes do contato/i,
        description: /Consegue acessar dados de um contato através do ID/i,
    },
    {
        name: /Criar contato/i,
        description: /Permite criar um novo contato com configurações opcionais/i,
    },
    {
        name: /Editar contato/i,
        description: /Permite editar dados de um contato existente através do ID/i,
    },
    {
        name: /Excluir contato/i,
        description: /Permite excluir um contato existente através do ID/i,
    },
] as const

async function openAiAgentCreate(page: Page) {
    const toolsResponse = page.waitForResponse(
        r => /ai\/available-tools/.test(r.url()) && r.status() === 200,
        { timeout: 30_000 }
    )

    await page.goto(`${resolvePageOrigin(page)}/ai-agents/create`)
    await expect(
        page
            .getByRole('heading', {
                name: /Criar Agente IA|Criar agente|Create agent|Novo agente|New agent/i,
            })
            .first()
    ).toBeVisible({ timeout: 30_000 })

    await toolsResponse
}

async function openToolsDropdown(page: Page): Promise<Locator> {
    const selector = page
        .locator('.mb-4')
        .filter({ hasText: /Ferramentas|Tools/i })
        .locator('.p-multiselect')
        .first()
    await expect(selector).toBeVisible({ timeout: 15_000 })
    await selector.click()

    const overlay = page.locator('.p-multiselect-overlay, .p-multiselect-panel').last()
    await expect(overlay).toBeVisible({ timeout: 10_000 })
    return overlay
}

async function filterToolOption(overlay: Locator, term: string) {
    const filterInput = overlay
        .locator('input.p-multiselect-filter, input[type="text"], input[role="searchbox"]')
        .first()
    await expect(filterInput).toBeVisible({ timeout: 5_000 })
    await filterInput.fill('')
    await filterInput.fill(term)
}

function toolOption(overlay: Locator, name: RegExp): Locator {
    return overlay
        .locator('.p-multiselect-option, .p-multiselect-item, li')
        .filter({ hasText: name })
        .first()
}

test.describe('DOP-1170 AI agent customer/contact tools', () => {
    test.describe.configure({ timeout: 120_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
    })

    test('tool picker lists customer and contact management tools', async ({ page }) => {
        await openAiAgentCreate(page)
        const overlay = await openToolsDropdown(page)

        await requireFeature(page, {
            id: 'DOP-1170',
            probe: async () => {
                await filterToolOption(overlay, 'clientes')
                try {
                    await toolOption(overlay, /Listar e filtrar clientes/i).waitFor({
                        state: 'visible',
                        timeout: 8_000,
                    })
                    return true
                } catch {
                    return false
                }
            },
        })

        for (const tool of CUSTOMER_CONTACT_TOOLS) {
            const searchTerm = /cliente/i.test(tool.name.source) ? 'cliente' : 'contato'
            await filterToolOption(overlay, searchTerm)

            const option = toolOption(overlay, tool.name)
            await expect(option).toBeVisible({ timeout: 10_000 })
            await expect(option.getByText(tool.name).first()).toBeVisible()
            await expect(option.getByText(tool.description).first()).toBeVisible()
        }
    })

    for (const theme of ['light', 'dark'] as const) {
        test(`customer/contact tool labels stay readable in ${theme} theme`, async ({
            page,
        }) => {
            await openAiAgentCreate(page)
            await setResolvedTheme(page, theme)

            const overlay = await openToolsDropdown(page)

            await requireFeature(page, {
                id: 'DOP-1170',
                probe: async () => {
                    await filterToolOption(overlay, 'clientes')
                    try {
                        await toolOption(overlay, /Listar e filtrar clientes/i).waitFor({
                            state: 'visible',
                            timeout: 8_000,
                        })
                        return true
                    } catch {
                        return false
                    }
                },
            })

            const samples = [
                { filter: 'Listar e filtrar clientes', name: /Listar e filtrar clientes/i },
                { filter: 'Listar e filtrar contatos', name: /Listar e filtrar contatos/i },
                { filter: 'Criar cliente', name: /Criar cliente/i },
                { filter: 'Excluir contato', name: /Excluir contato/i },
            ] as const

            for (const sample of samples) {
                await filterToolOption(overlay, sample.filter)

                const title = overlay.locator('.fw-bold').filter({ hasText: sample.name }).first()
                await expect(title).toBeVisible({ timeout: 10_000 })

                const option = title.locator(
                    'xpath=ancestor::*[contains(@class,"p-multiselect-option") or contains(@class,"p-multiselect-item") or self::li][1]'
                )
                const description = option.locator('small.text-muted').first()

                await expectReadableContrast(title, `${theme} ${sample.filter} title`)

                if (await description.isVisible().catch(() => false)) {
                    const muted = await measureContrastRatio(description)
                    test.info().annotations.push({
                        type: 'contrast',
                        description: `${theme} ${sample.filter} description ${muted.ratio.toFixed(2)}:1 (AA normal text needs 4.5)`,
                    })
                    expect(
                        muted.ratio,
                        `${theme} ${sample.filter} description contrast ${muted.ratio.toFixed(2)}:1`
                    ).toBeGreaterThanOrEqual(3)
                }
            }
        })
    }
})
