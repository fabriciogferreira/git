import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import {
    channelStateCheckSelect,
    expectSelectOptions,
    openChannelStateCondition,
    pickSelectOptionByText,
} from '../helpers/automation'

/**
 * DOP-1154 — condição "Estado da conversa do projeto".
 *
 * Skips via requireVisible when the component is absent (e.g. develop without the branch).
 */
test.describe('DOP-1154 channel state condition', () => {
    test.describe.configure({ timeout: 90_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
        await openChannelStateCondition(page)
    })

    test('lists and opens Estado da conversa do projeto', async ({ page }) => {
        await expect(
            page.getByText(/O que verificar|What to check/i).first()
        ).toBeVisible()

        // Default config on the front is `has_active_client_channel`.
        await expect(
            page.getByText(/Conversa externa ativa|Active external conversation/i).first()
        ).toBeVisible()

        await expect(
            page.getByText(
                /Bloquear o fluxo completo dessa automação caso a condição seja falsa|Block the (entire )?flow.*condition is false/i
            )
        ).toBeVisible()
    })

    test('check options cover active, awaiting, answered and resolved', async ({ page }) => {
        await expectSelectOptions(page, channelStateCheckSelect(page), [
            /Conversa externa ativa|Active external conversation/i,
            /Aguardando resposta|Awaiting reply/i,
            /Alguém da equipe respondeu|Someone from the team replied/i,
            /Conversa resolvida|Conversation resolved/i,
        ])
    })

    test('selecting a check shows its hint', async ({ page }) => {
        await pickSelectOptionByText(
            page,
            channelStateCheckSelect(page),
            /Conversa resolvida|Conversation resolved/i
        )

        await expect(
            page
                .getByText(
                    /marcada como resolvida|marked as resolved|Sem conversa|Without a conversation/i
                )
                .first()
        ).toBeVisible({ timeout: 10_000 })
    })
})
