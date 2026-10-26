import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import {
    createE2EAttachmentForm,
    deleteE2EForm,
    openProjectContentAddAction,
    openProjectContentAddAttachments,
    pickProjectContentAddFormField,
    pickSelectOption,
    projectContentAddAttachmentsBlock,
    projectContentAddAttachmentsMultiSelect,
    projectContentAddFormLocationSelect,
    automationSaveButton,
} from '../helpers/automation'

/**
 * DOP-1132 — optional step/funnel file attachments on "Envia conteúdo do projeto".
 *
 * Covers the configure UI. Skips via requireVisible when the picker is absent
 * (e.g. develop without the feature branch).
 */
test.describe('DOP-1132 project content add attachments', () => {
    test.describe.configure({ timeout: 90_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
        await openProjectContentAddAction(page)
    })

    test('shows optional attachments MultiSelect on Envia conteúdo do projeto', async ({
        page,
    }) => {
        const block = projectContentAddAttachmentsBlock(page)

        await expect(block.getByText(/Arquivos anexados \(opcional\)|Attached files/i)).toBeVisible()
        await expect(projectContentAddAttachmentsMultiSelect(page)).toBeVisible()
        await expect(
            block.getByText(
                /Escolha arquivos já anexados em etapas ou funis|Choose files already attached/i
            )
        ).toBeVisible()
    })

    test('attachments MultiSelect opens without error', async ({ page }) => {
        const panel = await openProjectContentAddAttachments(page)

        const hasOptions = (await panel.locator('[role="option"]').count()) > 0
        if (!hasOptions) {
            await expect(
                panel.getByText(
                    /Nenhum arquivo anexado disponível|No attached file|empty|Nenhum resultado/i
                ).first()
            ).toBeVisible()
        }

        await page.keyboard.press('Escape')
    })

    test('requires the message when no file is selected and always requires the destination', async ({ page }) => {
        const messageLabel = page.locator('.p-dialog .form-label').filter({ hasText: /^Mensagem$|^Message$/ }).first()
        const destinationLabel = page.locator('.p-dialog .form-label').filter({ hasText: /^Destino$|^Destination$/ }).first()

        await expect(messageLabel).toBeVisible()
        await expect(messageLabel).toHaveClass(/\brequired\b/)
        await expect(destinationLabel).toBeVisible()
        await expect(destinationLabel).toHaveClass(/\brequired\b/)

        const destination = page.locator('select').filter({
            has: page.locator('option', { hasText: /Canal principal|Main channel/i }),
        })
        await expect(destination).toBeVisible()
        await expect(destination).toHaveValue('main')
    })
})

test.describe('DOP-1132 funnel attachment listing', () => {
    test.describe.configure({ timeout: 90_000 })

    test('loads linked funnel files in one request', async ({ page }) => {
        const funnelAttachmentUrls: string[] = []
        page.on('request', request => {
            const url = request.url()
            if (request.method() === 'GET' && url.includes('/funnel-attachments')) {
                funnelAttachmentUrls.push(url)
            }
        })

        await loginAsE2EUser(page)
        await openProjectContentAddAction(page)

        await expect.poll(() => funnelAttachmentUrls.length).toBe(1)
        expect(funnelAttachmentUrls[0]).toContain('all_linked=1')
        expect(funnelAttachmentUrls[0]).not.toContain('project_funnel_id=')
    })
})

test.describe('DOP-1132 form attachment location', () => {
    test.describe.configure({ timeout: 90_000 })

    let fieldLabel = ''
    let formId = 0

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
        fieldLabel = `e2e-anexo-${Date.now()}`
        formId = await createE2EAttachmentForm(page, fieldLabel)
        await openProjectContentAddAction(page)
    })

    test.afterEach(async ({ page }) => {
        if (formId) await deleteE2EForm(page, formId)
    })

    test('drops the message asterisk after a file is selected', async ({ page }) => {
        const messageLabel = page.locator('.p-dialog .form-label').filter({ hasText: /^Mensagem$/ }).first()
        const destinationLabel = page.locator('.p-dialog .form-label').filter({ hasText: /^Destino$/ }).first()

        await expect(messageLabel).toHaveClass(/\brequired\b/)

        await pickProjectContentAddFormField(page, fieldLabel)

        await expect(messageLabel).not.toHaveClass(/\brequired\b/)
        await expect(destinationLabel).toHaveClass(/\brequired\b/)
    })

    test('hides the form location until an attachment field is chosen', async ({ page }) => {
        await expect(page.getByText('Onde está o formulário?', { exact: true })).toHaveCount(0)
        await expect(projectContentAddAttachmentsMultiSelect(page)).toBeVisible()
    })

    test('asks where the form lives after an attachment field is chosen', async ({ page }) => {
        await pickProjectContentAddFormField(page, fieldLabel)

        const select = projectContentAddFormLocationSelect(page)
        await expect(select).toBeVisible()
        await expect(
            page.getByText(/A ação envia só os arquivos respondidos nesse lugar/i)
        ).toBeVisible()
        await expect(page.getByText(/Sem isso a ação não salva/i)).toBeVisible()
        await expect(automationSaveButton(page)).toBeDisabled()

        await select.click()
        const listId = await select.getByRole('combobox').getAttribute('aria-controls')
        const options = listId
            ? page.locator(`#${listId}`).getByRole('option')
            : page.locator('.p-select-overlay').last().getByRole('option')
        for (const name of [
            /Formulário do projeto/i,
            /Formulário de um funil/i,
            /Formulário de uma etapa/i,
            /Formulário avulso/i,
        ]) {
            await expect(options.filter({ hasText: name }).first()).toBeVisible()
        }
        await expect(options).toHaveCount(4)
        await page.keyboard.press('Escape')
    })

    test('funnel location asks which funnel', async ({ page }) => {
        await pickProjectContentAddFormField(page, fieldLabel)
        await pickSelectOption(
            page,
            projectContentAddFormLocationSelect(page),
            /Formulário de um funil/i
        )

        await expect(page.getByText(/Qual funil\?/i).first()).toBeVisible()
        await expect(page.getByText(/Selecione o funil/i).first()).toBeVisible()
        await expect(automationSaveButton(page)).toBeDisabled()
    })

    test('step location asks which step', async ({ page }) => {
        await pickProjectContentAddFormField(page, fieldLabel)
        await pickSelectOption(
            page,
            projectContentAddFormLocationSelect(page),
            /Formulário de uma etapa/i
        )

        await expect(page.getByText(/Qual etapa\?/i).first()).toBeVisible()
        await expect(page.getByText(/Selecione a etapa/i).first()).toBeVisible()
        await expect(automationSaveButton(page)).toBeDisabled()
    })

    test('project location rejects a field from another form', async ({ page }) => {
        await pickProjectContentAddFormField(page, fieldLabel)
        await pickSelectOption(
            page,
            projectContentAddFormLocationSelect(page),
            /Formulário do projeto/i
        )

        await expect(
            page.getByText(/não pertencem ao formulário desse lugar/i)
        ).toBeVisible()
        await expect(automationSaveButton(page)).toBeDisabled()
    })

    test('loose location warns that the first loose form is the one sent', async ({ page }) => {
        await pickProjectContentAddFormField(page, fieldLabel)
        await pickSelectOption(
            page,
            projectContentAddFormLocationSelect(page),
            /Formulário avulso/i
        )

        await expect(page.getByText(/Formulários avulsos duplicados/i)).toBeVisible()
        await expect(
            page.getByText(/os arquivos enviados são os do primeiro/i)
        ).toBeVisible()
        await expect(automationSaveButton(page)).toBeEnabled()
    })

    test('hides the location question when the attachment field is removed', async ({ page }) => {
        await pickProjectContentAddFormField(page, fieldLabel)
        await expect(projectContentAddFormLocationSelect(page)).toBeVisible()

        await pickProjectContentAddFormField(page, fieldLabel)

        await expect(page.getByText('Onde está o formulário?', { exact: true })).toHaveCount(0)
        await expect(automationSaveButton(page)).toBeEnabled()
    })

    test('warns when attachment fields come from more than one form', async ({ page }) => {
        const otherLabel = `e2e-anexo-b-${Date.now()}`
        const otherFormId = await createE2EAttachmentForm(page, otherLabel)
        await page.reload()
        await openProjectContentAddAction(page)

        try {
            await pickProjectContentAddFormField(page, fieldLabel)
            await pickProjectContentAddFormField(page, otherLabel)

            await expect(
                page.getByText(/Escolha campos de anexo de um único formulário/i)
            ).toBeVisible()
            await expect(automationSaveButton(page)).toBeDisabled()
        } finally {
            await deleteE2EForm(page, otherFormId)
        }
    })
})
