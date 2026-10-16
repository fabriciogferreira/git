import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import {
    openProjectContentAddAction,
    projectContentAddAttachmentsBlock,
    projectContentAddAttachmentsMultiSelect,
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
        const multi = projectContentAddAttachmentsMultiSelect(page)
        await expect(multi).toBeVisible()
        await multi.click()

        // Overlay may list files or the empty message — either proves the panel wired correctly.
        const panel = page.locator('.p-multiselect-overlay, .p-multiselect-panel').first()
        await expect(panel).toBeVisible({ timeout: 10_000 })

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

    test('still shows required message and destination fields', async ({ page }) => {
        await expect(page.getByText(/^Mensagem$|^Message$/i).first()).toBeVisible()
        await expect(page.getByText(/^Destino$|^Destination$/i).first()).toBeVisible()
        await expect(
            page.getByText(/Canal principal|Main channel/i).first()
        ).toBeVisible()
    })
})
