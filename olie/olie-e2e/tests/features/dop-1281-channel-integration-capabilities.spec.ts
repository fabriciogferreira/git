import { test, expect, type Locator, type Page } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { openProjectContentTab } from '../helpers/content-media'
import { createE2EProject } from '../helpers/project'
import {
    channelDialog,
    channelRailItem,
    createE2ECommunicationIntegration,
    deleteE2ECommunicationIntegration,
    e2eCounterpart,
    fillCounterpartPhone,
    openChannelDialog,
    openExternalConversationViaApi,
    pickIntegration,
    selectExternalMode,
    submitOpenConversation,
} from '../helpers/channel-conversation'

/**
 * DOP-1281 — conversation adapts to channel integration capabilities.
 *
 * WhatsApp Cloud with a WABA: closed 24h window replaces the composer with a
 * warning + "Enviar template"; templates action opens the picker; Principal
 * stays a normal composer. Light/dark contrast of the closed panel is sampled.
 *
 * Note: `#media_conversation_content` is only the MediaViewer scroll area —
 * the composer (and reply-window replace UI) are siblings under `.content-tab`.
 */

type ContrastSample = {
    theme: string
    label: string
    fg: string
    bg: string
    ratio: number
}

function parseRgb(input: string): [number, number, number] | null {
    const m = input.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/i)
    if (!m) return null
    return [Number(m[1]), Number(m[2]), Number(m[3])]
}

function relativeLuminance([r, g, b]: [number, number, number]) {
    const toLin = (c: number) => {
        const s = c / 255
        return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4
    }
    return 0.2126 * toLin(r) + 0.7152 * toLin(g) + 0.0722 * toLin(b)
}

function contrastRatio(fg: string, bg: string): number | null {
    const a = parseRgb(fg)
    const b = parseRgb(bg)
    if (!a || !b) return null
    const L1 = relativeLuminance(a)
    const L2 = relativeLuminance(b)
    const lighter = Math.max(L1, L2)
    const darker = Math.min(L1, L2)
    return (lighter + 0.05) / (darker + 0.05)
}

async function effectiveBackground(page: Page, el: Locator) {
    return el.evaluate(node => {
        let current: Element | null = node
        while (current) {
            const style = getComputedStyle(current)
            const bg = style.backgroundColor
            if (bg && bg !== 'rgba(0, 0, 0, 0)' && bg !== 'transparent') {
                return bg
            }
            current = current.parentElement
        }
        return getComputedStyle(document.body).backgroundColor
    })
}

async function setTheme(page: Page, theme: 'light' | 'dark') {
    await page.evaluate(next => {
        localStorage.setItem('theme', next)
        document.documentElement.setAttribute('data-theme', next)
        document.documentElement.classList.toggle('dark-mode', next === 'dark')
    }, theme)
}

async function dismissUnexpectedError(page: Page) {
    const dialog = page.locator('.swal2-container').filter({ hasText: /Opss|erro inesperado|unexpected/i })
    if (await dialog.isVisible().catch(() => false)) {
        await dialog.getByRole('button', { name: /^OK$/i }).click()
        await expect(dialog).toBeHidden({ timeout: 10_000 })
    }
}

function contentTab(page: Page): Locator {
    return page.locator('.content-tab').first()
}

const CLOSED_COPY =
    /O cliente ainda não iniciou conversa|janela de \d+h fechou|reply window|has not started/i
const SEND_TEMPLATE = /Enviar template|Send template/i
test.describe('DOP-1281 channel integration capabilities', () => {
    test.describe.configure({ timeout: 240_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
    })

    test('Cloud channel without inbound shows closed window and template entry', async ({
        page,
    }) => {
        const integration = await createE2ECommunicationIntegration(page, {
            name: `e2e-dop1281-${Date.now()}`,
            config: { graph_version: 'v21.0', waba_id: '123456789012345' },
        })
        const projectId = await createE2EProject(page, {
            name: `dop1281-closed-${Date.now()}`,
        })
        const counterpart = e2eCounterpart()

        try {
            await openProjectContentTab(page, projectId)
            await dismissUnexpectedError(page)

            const status = await openExternalConversationViaApi(page, {
                projectId,
                integrationId: integration.id,
                externalRef: counterpart.externalRef,
            })
            expect(status).toBe(201)

            await page.reload()
            await expect(page.locator('#media_conversation_content')).toBeVisible({
                timeout: 35_000,
            })
            await dismissUnexpectedError(page)

            await channelRailItem(page, 'WhatsApp').click()
            await expect(channelRailItem(page, 'WhatsApp')).toBeVisible()

            const tab = contentTab(page)
            const caps = await page.evaluate(
                async ({ apiUrl, projectId }) => {
                    const token = localStorage.getItem('token')
                    if (!token) return null
                    const res = await fetch(
                        `${apiUrl}/api/management/channels?project_id=${projectId}`,
                        {
                            headers: {
                                Authorization: `Bearer ${token}`,
                                Accept: 'application/json',
                            },
                        }
                    )
                    const data = (await res.json().catch(() => null)) as {
                        channels?: Array<{
                            capabilities?: {
                                reply_window?: { open?: boolean } | null
                                free_text?: boolean
                                templates?: boolean
                                typing?: boolean
                            }
                            integration_type?: string | null
                        }>
                    } | null
                    return data?.channels?.[0] ?? null
                },
                {
                    apiUrl: process.env.E2E_API_URL || 'http://api.olie.localhost',
                    projectId,
                }
            )

            expect(caps?.integration_type).toBe('whatsapp_cloud')
            expect(caps?.capabilities?.templates).toBe(true)
            expect(caps?.capabilities?.typing).toBe(true)
            expect(caps?.capabilities?.free_text).toBe(false)
            expect(caps?.capabilities?.reply_window?.open).toBe(false)

            await expect(tab.getByText(CLOSED_COPY)).toBeVisible({ timeout: 20_000 })
            await expect(tab.getByRole('button', { name: SEND_TEMPLATE })).toBeVisible()
            await expect(tab.locator('.media-conversation-input .ProseMirror')).toHaveCount(0)

            await page.route(/\/channels\/[^/]+\/templates(\?|$)/, async route => {
                if (route.request().method() !== 'GET') {
                    await route.continue()
                    return
                }
                await route.fulfill({
                    status: 200,
                    contentType: 'application/json',
                    body: JSON.stringify({ response: true, templates: [] }),
                })
            })

            await tab.getByRole('button', { name: SEND_TEMPLATE }).click()
            const picker = page
                .locator('.p-dialog')
                .filter({ hasText: /Enviar template|Send template/i })
                .first()
            await expect(picker).toBeVisible({ timeout: 15_000 })
            await expect(picker.locator('p.text-muted').first()).toBeVisible({ timeout: 20_000 })
        } finally {
            await deleteE2ECommunicationIntegration(page, integration.id)
        }
    })

    test('Principal channel keeps a normal composer without reply-window chrome', async ({
        page,
    }) => {
        const projectId = await createE2EProject(page, {
            name: `dop1281-principal-${Date.now()}`,
        })

        await openProjectContentTab(page, projectId)
        await dismissUnexpectedError(page)

        const tab = contentTab(page)
        await expect(tab.locator('.media-conversation-input .ProseMirror').last()).toBeVisible({
            timeout: 20_000,
        })
        await expect(tab.getByText(CLOSED_COPY)).toHaveCount(0)
        await expect(tab.getByRole('button', { name: SEND_TEMPLATE })).toHaveCount(0)
        await expect(
            tab.getByRole('button', {
                name: /Enviar template aprovado|Send approved template/i,
            })
        ).toHaveCount(0)
    })

    test('measures closed-window panel contrast in light and dark themes', async ({
        page,
    }) => {
        const integration = await createE2ECommunicationIntegration(page, {
            name: `e2e-dop1281-contrast-${Date.now()}`,
            config: { graph_version: 'v21.0', waba_id: '123456789012345' },
        })
        const projectId = await createE2EProject(page, {
            name: `dop1281-contrast-${Date.now()}`,
        })
        const counterpart = e2eCounterpart()

        try {
            await openProjectContentTab(page, projectId)
            await dismissUnexpectedError(page)

            const status = await openExternalConversationViaApi(page, {
                projectId,
                integrationId: integration.id,
                externalRef: counterpart.externalRef,
            })
            expect(status).toBe(201)
            await page.reload()
            await expect(page.locator('#media_conversation_content')).toBeVisible({
                timeout: 35_000,
            })
            await dismissUnexpectedError(page)
            await channelRailItem(page, 'WhatsApp').click()

            const tab = contentTab(page)
            const panel = tab.locator('[role="status"]').filter({ hasText: CLOSED_COPY }).first()
            await expect(panel).toBeVisible({ timeout: 20_000 })

            const samples: ContrastSample[] = []
            for (const theme of ['light', 'dark'] as const) {
                await setTheme(page, theme)
                await expect(page.locator('html')).toHaveAttribute('data-theme', theme)
                await expect(panel).toBeVisible()

                const text = panel.locator('span').first()
                const fg = await text.evaluate(node => getComputedStyle(node).color)
                const bg = await effectiveBackground(page, text)
                const ratio = contrastRatio(fg, bg)
                expect(ratio).not.toBeNull()
                samples.push({
                    theme,
                    label: ((await text.innerText()) || '').trim().slice(0, 80),
                    fg,
                    bg,
                    ratio: Number(ratio!.toFixed(2)),
                })
            }

            console.log('DOP-1281 contrast samples:', JSON.stringify(samples, null, 2))
            for (const sample of samples) {
                expect(sample.ratio).toBeGreaterThan(1)
            }
        } finally {
            await deleteE2ECommunicationIntegration(page, integration.id)
        }
    })

    test('channel dialog still opens after Cloud integration exists', async ({ page }) => {
        const integration = await createE2ECommunicationIntegration(page, {
            name: `e2e-dop1281-dialog-${Date.now()}`,
            config: { graph_version: 'v21.0', waba_id: '123456789012345' },
        })
        const projectId = await createE2EProject(page, {
            name: `dop1281-dialog-${Date.now()}`,
        })

        try {
            await openProjectContentTab(page, projectId)
            await dismissUnexpectedError(page)
            await openChannelDialog(page)
            await selectExternalMode(page)
            await pickIntegration(page, integration.name)
            await fillCounterpartPhone(page, e2eCounterpart().national)
            await expect(channelDialog(page)).toBeVisible()
        } finally {
            await deleteE2ECommunicationIntegration(page, integration.id)
        }
    })
})
