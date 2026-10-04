import { test, expect } from '@playwright/test'
import { loginAsIsolatedE2EUser } from '../helpers/isolated-user'
import {
    companyAllowsMultipleActiveChannels,
    multipleActiveChannelsCard,
    multipleActiveChannelsSwitch,
    openFrameSettings,
    requireMultipleActiveChannelsSettings,
    saveCompanyMultipleActiveChannels,
} from '../helpers/frame-settings'

/**
 * DOP-1158 — company card on `/frame/settings`.
 *
 * Skips via `requireMultipleActiveChannelsSettings` when the card is absent on the front under
 * test. The switch is the company default for the whole feature; the card also has to state the
 * routing rule (a card requirement) and what turning the option off does.
 *
 * Runs on an isolated user + work frame, so the writes never touch the shared `devframe` seed and
 * the file is parallel-safe (`testInfo.parallelIndex` gives each worker its own account).
 */
test.describe('DOP-1158 multiple active conversations — company card', () => {
    test.describe.configure({ timeout: 120_000 })

    test.beforeEach(async ({ page, request }, testInfo) => {
        await loginAsIsolatedE2EUser(page, request, { workerIndex: testInfo.parallelIndex })
        await openFrameSettings(page)
        await requireMultipleActiveChannelsSettings(page)
    })

    test('shows the switch, the routing rule and what turning it off does', async ({ page }) => {
        const card = multipleActiveChannelsCard(page)

        await expect(card).toBeVisible()
        await expect(multipleActiveChannelsSwitch(page)).toBeVisible()

        await expect(
            card.getByText(/Para qual conversa a mensagem vai\?|Which conversation receives the message\?/i)
        ).toBeVisible()
        // The tie-break goes to the most recently created conversation, not the oldest.
        await expect(
            card.getByText(/entra a conversa mais recente|most recently created conversation wins/i)
        ).toBeVisible()
        await expect(
            card.getByText(/Cada integração pode ter sua própria regra|Each integration can have its own rule/i)
        ).toBeVisible()
        await expect(
            card.getByText(/O que acontece ao desligar|What turning this off does/i)
        ).toBeVisible()
        await expect(
            card.getByRole('button', { name: /Salvar|Save/i })
        ).toBeVisible()
    })

    test('saves only its own key and keeps the value after reload', async ({ page }) => {
        const before = await companyAllowsMultipleActiveChannels(page)
        const target = !before

        const response = await saveCompanyMultipleActiveChannels(page, target)
        expect(response.status()).toBe(200)

        // The card must not resend the other settings on the page.
        const posted = response.request().postDataJSON() as Record<string, unknown>
        expect(posted).toEqual({ allow_multiple_active_channels: target })

        await expect(
            page.getByText(
                /Configuração de conversas ativas salva com sucesso|Active conversations setting saved successfully/i
            ).first()
        ).toBeVisible({ timeout: 15_000 })

        await openFrameSettings(page)
        await requireMultipleActiveChannelsSettings(page)
        await expect(multipleActiveChannelsSwitch(page)).toBeChecked({ checked: target })

        // Restore the prior value so the seed frame stays stable across runs.
        const restore = await saveCompanyMultipleActiveChannels(page, before)
        expect(restore.status()).toBe(200)
    })
})
