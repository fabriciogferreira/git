import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { createE2EProject } from '../helpers/project'
import {
    createChannelManageAutomation,
    createInternalChannelViaApi,
    deleteE2EAutomation,
    renameProjectViaApi,
    requireChannelManageActionApi,
    waitForProjectChannel,
} from '../helpers/channel-manage-runtime'

/**
 * DOP-1154 — runtime: automação dispara e o canal muda de fato.
 *
 * Setup via API (automation store + project rename trigger). Asserts on
 * `GET /channels?project_id=…`. Skips when `project_channel_manage_action` is
 * missing on the API (develop without the feature branch).
 *
 * Uses the shared seed user (`loginAsE2EUser`) with unique titles/names so
 * workers=1 is safe. Prefer `E2E_AUTH_TOKEN` + `E2E_USER_ID` when local
 * reCAPTCHA rejects the Playwright stub (register/login otherwise 422).
 */
test.describe('DOP-1154 channel manage runtime', () => {
    test.describe.configure({ timeout: 180_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
        await requireChannelManageActionApi(page)
    })

    test('creates an internal channel when the project name changes', async ({ page }) => {
        const stamp = Date.now()
        const channelName = `Fornecedor-${stamp}`
        const projectId = await createE2EProject(page, {
            name: `e2e-dop1154-create-${stamp}`,
        })

        const automationId = await createChannelManageAutomation(page, {
            title: `e2e-dop1154-create-auto-${stamp}`,
            action: {
                operation: 'create',
                audience: 'internal',
                channel_name: channelName,
            },
        })

        try {
            await renameProjectViaApi(page, projectId, `e2e-dop1154-create-fired-${stamp}`)

            const channels = await waitForProjectChannel(
                page,
                projectId,
                list => list.some(c => c.name === channelName && c.is_active)
            )

            const created = channels.find(c => c.name === channelName)
            expect(created).toMatchObject({
                name: channelName,
                is_active: true,
            })
        } finally {
            await deleteE2EAutomation(page, automationId)
        }
    })

    test('deactivates the named channel when the project name changes', async ({ page }) => {
        const stamp = Date.now()
        const channelName = `Equipe-${stamp}`
        const projectId = await createE2EProject(page, {
            name: `e2e-dop1154-deact-${stamp}`,
        })

        const seeded = await createInternalChannelViaApi(page, {
            projectId,
            name: channelName,
            isActive: true,
        })
        expect(seeded.is_active).toBe(true)

        const automationId = await createChannelManageAutomation(page, {
            title: `e2e-dop1154-deact-auto-${stamp}`,
            action: {
                operation: 'deactivate',
                channel_name: channelName,
            },
        })

        try {
            await renameProjectViaApi(page, projectId, `e2e-dop1154-deact-fired-${stamp}`)

            await waitForProjectChannel(
                page,
                projectId,
                list => list.some(c => c.id === seeded.id && c.is_active === false)
            )
        } finally {
            await deleteE2EAutomation(page, automationId)
        }
    })

    test('renames the named channel when the project name changes', async ({ page }) => {
        const stamp = Date.now()
        const oldName = `Cliente-${stamp}`
        const newName = `Cliente-encerrado-${stamp}`
        const projectId = await createE2EProject(page, {
            name: `e2e-dop1154-rename-${stamp}`,
        })

        const seeded = await createInternalChannelViaApi(page, {
            projectId,
            name: oldName,
        })

        const automationId = await createChannelManageAutomation(page, {
            title: `e2e-dop1154-rename-auto-${stamp}`,
            action: {
                operation: 'rename',
                channel_name: oldName,
                new_name: newName,
            },
        })

        try {
            await renameProjectViaApi(page, projectId, `e2e-dop1154-rename-fired-${stamp}`)

            const channels = await waitForProjectChannel(
                page,
                projectId,
                list => list.some(c => c.id === seeded.id && c.name === newName)
            )

            expect(channels.find(c => c.id === seeded.id)?.name).toBe(newName)
            expect(channels.some(c => c.name === oldName)).toBe(false)
        } finally {
            await deleteE2EAutomation(page, automationId)
        }
    })

    test('reactivates a deactivated channel when the project name changes', async ({ page }) => {
        const stamp = Date.now()
        const channelName = `Suporte-${stamp}`
        const projectId = await createE2EProject(page, {
            name: `e2e-dop1154-act-${stamp}`,
        })

        const seeded = await createInternalChannelViaApi(page, {
            projectId,
            name: channelName,
            isActive: false,
        })
        expect(seeded.is_active).toBe(false)

        const automationId = await createChannelManageAutomation(page, {
            title: `e2e-dop1154-act-auto-${stamp}`,
            action: {
                operation: 'activate',
                channel_name: channelName,
            },
        })

        try {
            await renameProjectViaApi(page, projectId, `e2e-dop1154-act-fired-${stamp}`)

            await waitForProjectChannel(
                page,
                projectId,
                list => list.some(c => c.id === seeded.id && c.is_active === true)
            )
        } finally {
            await deleteE2EAutomation(page, automationId)
        }
    })
})
