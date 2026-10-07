import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import {
    channelStateEventSelect,
    expectSelectOptions,
    openChannelStateTrigger,
    pickSelectOptionByText,
} from '../helpers/automation'

/**
 * DOP-1154 — gatilho "Estado da conversa do projeto alterado".
 *
 * Skips via requireVisible when the component is absent (e.g. develop without the branch).
 * On feature/DOP-1154-*, the trigger is selectable and event options are complete.
 */
test.describe('DOP-1154 channel state trigger', () => {
    test.describe.configure({ timeout: 90_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
        await openChannelStateTrigger(page)
    })

    test('lists and opens Estado da conversa do projeto alterado', async ({ page }) => {
        await expect(
            page.getByText(/Quando disparar|When to fire|When to trigger/i).first()
        ).toBeVisible()

        // Default config on the front is `resolved`.
        await expect(
            page.getByText(/Conversa resolvida|Conversation resolved/i).first()
        ).toBeVisible()
    })

    test('event options cover resolved, reopened, awaiting reply and answered', async ({
        page,
    }) => {
        await expectSelectOptions(page, channelStateEventSelect(page), [
            /Conversa resolvida|Conversation resolved/i,
            /Conversa reaberta|Conversation reopened/i,
            /Passou a aguardar resposta|Started awaiting reply/i,
            /Alguém da equipe respondeu|Someone from the team replied/i,
        ])
    })

    test('selecting an event shows its hint', async ({ page }) => {
        await pickSelectOptionByText(
            page,
            channelStateEventSelect(page),
            /Passou a aguardar resposta|Started awaiting reply/i
        )

        await expect(
            page
                .getByText(
                    /Passou a aguardar resposta\. Não dispara de novo|Started awaiting reply/i
                )
                .first()
        ).toBeVisible({ timeout: 10_000 })
    })
})
