import { test, expect } from '@playwright/test'
import { loginAsIsolatedE2EUser } from '../helpers/isolated-user'
import { createE2EProject } from '../helpers/project'
import { openProjectContentTab } from '../helpers/content-media'
import {
    createE2ECommunicationIntegration,
    deleteE2ECommunicationIntegration,
    e2eCounterpart,
    listProjectChannels,
    openExternalConversationViaApi,
} from '../helpers/channel-conversation'

/**
 * DOP-1158 — when "Encerrar e ativar aqui" is confirmed but the force_takeover
 * PUT fails, the user must see an error (not a silent unhandled rejection).
 */
test.describe('DOP-1158 force_takeover retry error', () => {
    test.describe.configure({ timeout: 300_000 })

    test.beforeEach(async ({ page, request }, testInfo) => {
        await loginAsIsolatedE2EUser(page, request, { workerIndex: testInfo.parallelIndex })
    })

    test('shows an error when the force_takeover retry fails after confirm', async ({ page }) => {
        const integration = await createE2ECommunicationIntegration(page)
        const suffix = Date.now()
        const firstProject = await createE2EProject(page, { name: `dop1158-hold-${suffix}` })
        const secondProject = await createE2EProject(page, { name: `dop1158-activate-${suffix}` })
        const counterpart = e2eCounterpart()

        try {
            expect(
                await openExternalConversationViaApi(page, {
                    projectId: firstProject,
                    integrationId: integration.id,
                    externalRef: counterpart.externalRef,
                })
            ).toBe(201)

            // Second card: create an inactive duplicate via API (history row), then activate in UI.
            const createdInactive = await page.evaluate(
                async ({ apiUrl, projectId, integrationId, externalRef }) => {
                    const token = localStorage.getItem('token')
                    if (!token) return { ok: false as const, status: 0 }

                    const res = await fetch(apiUrl, {
                        method: 'POST',
                        headers: {
                            Authorization: `Bearer ${token}`,
                            'Content-Type': 'application/json',
                            Accept: 'application/json',
                        },
                        body: JSON.stringify({
                            project_id: projectId,
                            integration_id: integrationId,
                            external_ref: externalRef,
                            name: 'WhatsApp',
                            is_active: false,
                        }),
                    })

                    return { ok: res.ok, status: res.status }
                },
                {
                    apiUrl: `${process.env.E2E_API_URL || 'http://api.olie.localhost'}/api/management/channels`,
                    projectId: secondProject,
                    integrationId: integration.id,
                    externalRef: counterpart.externalRef,
                }
            )
            expect(createdInactive.status, JSON.stringify(createdInactive)).toBe(201)

            await openProjectContentTab(page, secondProject)

            const inactive = page
                .locator('.channel-rail')
                .locator('button.btn')
                .filter({ hasText: /WhatsApp/i })
                .first()
            await expect(inactive).toBeVisible({ timeout: 20_000 })

            // Quick-activate on the inactive channel (desktop sidebar).
            const activate = page
                .locator('.channel-rail')
                .locator('button.btn-light-primary:has(i.fa-toggle-on)')
                .first()
            await expect(activate).toBeVisible({ timeout: 15_000 })

            let putCount = 0
            await page.route('**/api/management/channels/**', async route => {
                if (route.request().method() !== 'PUT') {
                    await route.continue()
                    return
                }

                putCount += 1
                const body = route.request().postDataJSON() as { force_takeover?: boolean }

                if (body?.force_takeover === true || putCount >= 2) {
                    await route.fulfill({
                        status: 422,
                        contentType: 'application/json',
                        body: JSON.stringify({
                            response: false,
                            message: 'validation_errors',
                            error: 'Erro ao validar os campos.',
                            validation: { name: ['Simulated force_takeover failure'] },
                        }),
                    })
                    return
                }

                await route.continue()
            })

            await activate.click()

            const takeoverPrompt = page.locator('.swal2-container').filter({
                hasText: /Encerrar e ativar|close.*activate|conversa ativa/i,
            })
            await expect(takeoverPrompt).toBeVisible({ timeout: 20_000 })
            await takeoverPrompt.locator('.swal2-confirm').click()

            // After the failed retry, FireErrorMessage must surface — toast or modal Swal.
            await expect(page.locator('.swal2-container')).toBeVisible({ timeout: 20_000 })
            await expect(page.locator('.swal2-container')).toContainText(
                /Simulated force_takeover failure|validar|erro|error/i
            )

            const stillInactive = await listProjectChannels(page, secondProject)
            expect(stillInactive.some(c => c.is_active === false || c.is_active === 0)).toBeTruthy()
        } finally {
            await deleteE2ECommunicationIntegration(page, integration.id)
        }
    })
})
