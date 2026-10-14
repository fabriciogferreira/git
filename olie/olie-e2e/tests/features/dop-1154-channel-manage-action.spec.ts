import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import {
    channelManageAudienceSelect,
    channelManageOperationSelect,
    expectSelectOptions,
    openChannelManageAction,
    pickSelectOptionByText,
} from '../helpers/automation'

/**
 * DOP-1154 — ação "Gerenciar canal do projeto".
 *
 * Covers the configure UI: operations, audience, channel name, and client-create fields.
 * Skips via requireVisible when the component is absent (e.g. develop without the branch).
 */
test.describe('DOP-1154 channel manage action', () => {
    test.describe.configure({ timeout: 90_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
        await openChannelManageAction(page)
    })

    test('lists and opens Gerenciar canal do projeto', async ({ page }) => {
        await expect(
            page.getByText(/Tipo de ação|Action type/i).first()
        ).toBeVisible()

        // Default config on the front is `resolve` — no channel name field.
        await expect(
            page.getByText(/Marcar como resolvido|Mark as resolved/i).first()
        ).toBeVisible()
        await expect(
            page.getByText(/Nome do canal|Channel name/i)
        ).toHaveCount(0)
    })

    test('operation options cover create, rename, activate, deactivate, resolve, reopen', async ({
        page,
    }) => {
        await expectSelectOptions(page, channelManageOperationSelect(page), [
            /Criar canal|Create channel/i,
            /Renomear canal|Rename channel/i,
            /Reativar canal|Reactivate channel/i,
            /Inativar canal|Deactivate channel/i,
            /Marcar como resolvido|Mark as resolved/i,
            /Reabrir conversa|Reopen conversation/i,
        ])
    })

    async function chooseCreateOperation(page: import('@playwright/test').Page) {
        const operation = channelManageOperationSelect(page)
        await pickSelectOptionByText(page, operation, /^Criar canal$|^Create channel$/i)
        // append-to="self" keeps option nodes in the DOM — assert the combobox label only.
        await expect(
            operation.getByRole('combobox', { name: /Criar canal|Create channel/i })
        ).toBeVisible({ timeout: 10_000 })
        await expect(
            page.getByText(/Tipo de canal|Channel type/i).first()
        ).toBeVisible({ timeout: 10_000 })
    }

    test('create internal asks for audience and channel name', async ({ page }) => {
        await chooseCreateOperation(page)

        await expect(
            page.getByText(/Nome do canal|Channel name/i).first()
        ).toBeVisible()

        // create defaults audience to internal (onOperationChange).
        const audience = channelManageAudienceSelect(page)
        await expect(audience).toBeVisible()
        await expect(audience.getByText(/Canal interno|Internal channel/i)).toBeVisible()

        // Internal create: no integration / counterpart / force_reopen.
        await expect(page.getByText(/^Integração$|^Integration$/i)).toHaveCount(0)
        await expect(page.getByText(/Destinatário|Counterpart|Recipient/i)).toHaveCount(0)
        await expect(
            page.locator('#project_channel_manage_force_reopen')
        ).toHaveCount(0)
    })

    test('create external shows integration, phone and force reopen', async ({ page }) => {
        await chooseCreateOperation(page)

        // Audience defaults to internal; switch via the combobox accessible name.
        const audienceCombo = page.getByRole('combobox', {
            name: /Canal interno|Internal channel/i,
        })
        await expect(audienceCombo).toBeVisible({ timeout: 10_000 })
        await audienceCombo.click()
        await page
            .getByRole('option', { name: /^Canal externo$|^External channel$/i })
            .click()
        await expect(
            page.getByRole('combobox', { name: /Canal externo|External channel/i })
        ).toBeVisible({ timeout: 10_000 })

        await expect(
            page.getByText(/^Integração$|^Integration$/i).first()
        ).toBeVisible({ timeout: 10_000 })

        // Default: phone mode (connector builds external_ref). Not the raw "Destinatário".
        // Scope to :visible — other modals (criar contato) keep a hidden "Telefone" label in the DOM.
        await expect(
            page.locator('#project_channel_manage_identifier')
        ).toBeVisible()
        await expect(
            page.getByText(/Identificador avançado|Advanced identifier/i)
        ).toBeVisible()
        await expect(
            page.locator('label.form-label:visible', { hasText: /^(Telefone|Phone)$/i })
        ).toBeVisible()

        // Advanced identifier swaps the field label/hint.
        await page.locator('#project_channel_manage_identifier').check()
        await expect(
            page.locator('label.form-label:visible', { hasText: /^(Identificador|Identifier)$/i })
        ).toBeVisible({ timeout: 10_000 })
        await page.locator('#project_channel_manage_identifier').uncheck()
        await expect(
            page.locator('label.form-label:visible', { hasText: /^(Telefone|Phone)$/i })
        ).toBeVisible({ timeout: 10_000 })

        await expect(
            page.locator('#project_channel_manage_force_reopen')
        ).toBeVisible()
        await expect(
            page.getByText(/Reabrir conversa ativa|Reopen active conversation/i)
        ).toBeVisible()

        await page.locator('#project_channel_manage_force_reopen').check()
        await expect(
            page.getByText(/Motivo do encerramento|Closing note|Close reason/i).first()
        ).toBeVisible({ timeout: 10_000 })

        // Turning force_reopen off must hide close_reason (front clears config too).
        await page.locator('#project_channel_manage_force_reopen').uncheck()
        await expect(
            page.getByText(/Motivo do encerramento|Closing note|Close reason/i)
        ).toHaveCount(0)
    })

    test('rename asks for current and new channel name', async ({ page }) => {
        await pickSelectOptionByText(
            page,
            channelManageOperationSelect(page),
            /Renomear canal|Rename channel/i
        )

        await expect(
            page.getByText(/Nome do canal|Channel name/i).first()
        ).toBeVisible({ timeout: 10_000 })
        await expect(
            page.getByText(/Novo nome do canal|New channel name/i).first()
        ).toBeVisible()
        await expect(page.getByText(/Tipo de canal|Channel type/i)).toHaveCount(0)
    })

    test('activate and deactivate ask only for channel name', async ({ page }) => {
        for (const operation of [
            /Reativar canal|Reactivate channel/i,
            /Inativar canal|Deactivate channel/i,
        ]) {
            await pickSelectOptionByText(page, channelManageOperationSelect(page), operation)

            await expect(
                page.getByText(/Nome do canal|Channel name/i).first()
            ).toBeVisible({ timeout: 10_000 })
            await expect(page.getByText(/Novo nome do canal|New channel name/i)).toHaveCount(0)
            await expect(page.getByText(/Tipo de canal|Channel type/i)).toHaveCount(0)
            await expect(page.getByText(/^Integração$|^Integration$/i)).toHaveCount(0)
        }
    })

    test('resolve and reopen hide channel name fields', async ({ page }) => {
        for (const operation of [
            /Marcar como resolvido|Mark as resolved/i,
            /Reabrir conversa|Reopen conversation/i,
        ]) {
            await pickSelectOptionByText(page, channelManageOperationSelect(page), operation)

            await expect(page.getByText(/Nome do canal|Channel name/i)).toHaveCount(0)
            await expect(page.getByText(/Tipo de canal|Channel type/i)).toHaveCount(0)
        }
    })
})
