import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import {
    businessRulesCard,
    notificationsCard,
    openFrameSettings,
} from '../helpers/frame-settings'

/**
 * DOP-1157 — baseline of company settings (/frame/settings) before the
 * content_added_debounce_seconds UI lands.
 *
 * Locks current notifications + business rules cards so the new card does not
 * regress the existing FrameSettings surface.
 */
test.describe('DOP-1157 frame settings baseline', () => {
    test.describe.configure({ timeout: 90_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
        await openFrameSettings(page)
    })

    test('shows company overview on settings page', async ({ page }) => {
        // modules.frame.overview.data_titles — "Dados" / "Data"
        await expect(
            page.locator('#settings_overview .card-title h3').first()
        ).toHaveText(/Dados|Data/i)
    })

    test('shows user notifications card with assignment and removal toggles', async ({
        page,
    }) => {
        const card = notificationsCard(page)
        await expect(card).toBeVisible()

        await expect(
            card.getByText(/Atribuição de Usuários|User Assignment/i).first()
        ).toBeVisible()
        await expect(
            card.getByText(/Remoção de Usuários|User Removal/i).first()
        ).toBeVisible()

        await expect(card.locator('input[type="checkbox"]')).toHaveCount(2)
        await expect(
            card.getByRole('button', { name: /Salvar|Save/i })
        ).toBeVisible()
    })

    test('shows business rules card with inactive-users toggle', async ({ page }) => {
        const card = businessRulesCard(page)
        await expect(card).toBeVisible()

        await expect(
            card
                .getByText(
                    /Remover o acesso aos funis de usuários inativos|Remove access to funnels from inactive users/i
                )
                .first()
        ).toBeVisible()

        await expect(card.locator('input[type="checkbox"]')).toHaveCount(1)
        await expect(
            card.getByRole('button', { name: /Salvar|Save/i })
        ).toBeVisible()
    })

    test('saving business rules keeps the card and shows success feedback', async ({
        page,
    }) => {
        const card = businessRulesCard(page)
        await expect(card).toBeVisible()

        const toggle = card.locator('input[type="checkbox"]').first()
        const before = await toggle.isChecked()

        await toggle.click({ force: true })
        await expect(toggle).toBeChecked({ checked: !before })

        await page.keyboard.press('Escape')

        const saveResponse = page.waitForResponse(
            r =>
                /frame-configurations/.test(r.url()) &&
                r.request().method() === 'POST' &&
                (r.status() === 200 || r.status() === 422),
            { timeout: 30_000 }
        )

        await card.getByRole('button', { name: /Salvar|Save/i }).click({ force: true })
        const response = await saveResponse
        expect(response.status()).toBe(200)

        await expect(
            page.getByText(
                /Regras de negócio salvas com sucesso|Business rules saved successfully/i
            ).first()
        ).toBeVisible({ timeout: 15_000 })

        // Restore prior value so the seed frame stays stable across runs.
        await toggle.click({ force: true })
        await expect(toggle).toBeChecked({ checked: before })

        await page.keyboard.press('Escape')

        const restoreResponse = page.waitForResponse(
            r =>
                /frame-configurations/.test(r.url()) &&
                r.request().method() === 'POST' &&
                r.status() === 200,
            { timeout: 30_000 }
        )
        await card.getByRole('button', { name: /Salvar|Save/i }).click({ force: true })
        await restoreResponse
    })
})
