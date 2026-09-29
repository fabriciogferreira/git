import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { requireVisible } from '../helpers/feature'
import {
    ACTIVITIES_GROUP_TITLE,
    ACTIVITIES_SEARCH_LABEL,
    openCreateRoleModal,
    openFrameRoles,
    requireActivitiesSearchI18n,
} from '../helpers/activity-history'

/**
 * DOP-1161 — activities.search i18n + ready templates in SetupRoleModal.
 *
 * Skips via requireVisible when the roles / i18n surface is absent on the
 * front under test (e.g. develop without bugfix/DOP-1161-*).
 */
test.describe('DOP-1161 activities.search role editor', () => {
    test.describe.configure({ timeout: 90_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
        await openFrameRoles(page)
    })

    test('shows human-readable activities.search label and change-history group', async ({
        page,
    }) => {
        const modal = await openCreateRoleModal(page)
        await requireActivitiesSearchI18n(page, modal)

        await expect(modal.getByText(ACTIVITIES_SEARCH_LABEL).first()).toBeVisible()
        await expect(modal.getByText(ACTIVITIES_GROUP_TITLE).first()).toBeVisible()

        await expect(
            modal.locator('.permission-description', { hasText: /^activities\.search$/ })
        ).toHaveCount(0)
    })

    test('ready template without * includes activities.search checked', async ({ page }) => {
        const modal = await openCreateRoleModal(page)

        // SetupRoleModal marks permission checkboxes as role="button" — avoid getByRole('button', /Modelos/),
        // which also matches labels like projects.searcher.index_templates.
        await modal
            .locator('.modal-header button.btn-sm.btn-light')
            .filter({ hasText: /Modelos|Models/i })
            .click()

        // Popover body: "Modelo 3" / "Model 3" is the first template that lists
        // activities.search explicitly (0–1 use "*").
        const templateCard = page
            .locator('.bg-light.bg-hover-opacity-50.cursor-pointer, .bg-light.cursor-pointer.rounded')
            .filter({ hasText: /Modelo 3|Model 3/i })
            .first()

        await requireVisible(
            page,
            'DOP-1161 ready template 3',
            templateCard,
            8_000
        )
        await templateCard.click()

        const searchInput = modal.locator('.input-group input.form-control').first()
        await searchInput.fill('activities.search')

        const checkbox = modal.locator('input.form-check-input[value="activities.search"]')
        await expect(checkbox).toBeVisible({ timeout: 10_000 })
        await expect(checkbox).toBeChecked()

        // Soft label check: human copy when i18n is wired; skip raw key-as-label.
        await expect(modal.getByText(ACTIVITIES_SEARCH_LABEL).first()).toBeVisible()
        await expect(
            modal.getByText(/permissions\.activities\.search(\.title)?/)
        ).toHaveCount(0)
    })
})
