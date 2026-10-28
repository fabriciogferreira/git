import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import {
    businessRulesCard,
    contentAddedDebounceCard,
    contentAddedDebounceInput,
    multipleActiveChannelsCard,
    multipleActiveChannelsSwitch,
    notificationsCard,
    openFrameSettings,
    requireContentAddedDebounceSettings,
    requireMultipleActiveChannelsSettings,
} from '../helpers/frame-settings'
import { stripFrameSettingsEditConfigurationsAndRemount } from '../helpers/frame-settings-permissions'

/**
 * DOP-1177 — company settings require frame_settings.edit.configurations.
 *
 * Without the permission the tab still loads (frame_settings.view), but fields
 * are read-only and Save is gated by v-permission (no-perm).
 */
test.describe('DOP-1177 company settings edit permission', () => {
    test.describe.configure({ timeout: 120_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
        await openFrameSettings(page)
        await requireContentAddedDebounceSettings(page)
        await requireMultipleActiveChannelsSettings(page)
        await stripFrameSettingsEditConfigurationsAndRemount(page)
    })

    test('shows settings read-only when edit.configurations is missing', async ({
        page,
    }) => {
        const notifications = notificationsCard(page)
        await expect(notifications).toBeVisible()
        await expect(
            notifications.locator('input[type="checkbox"]').first()
        ).toBeDisabled()
        await expect(
            notifications.getByRole('button', { name: /Salvar|Save/i })
        ).toHaveClass(/no-perm/)

        const businessRules = businessRulesCard(page)
        await expect(businessRules).toBeVisible()
        await expect(
            businessRules.locator('input[type="checkbox"]').first()
        ).toBeDisabled()
        await expect(
            businessRules.getByRole('button', { name: /Salvar|Save/i })
        ).toHaveClass(/no-perm/)

        await expect(contentAddedDebounceCard(page)).toBeVisible()
        await expect(contentAddedDebounceInput(page)).toBeDisabled()
        await expect(
            contentAddedDebounceCard(page).getByRole('button', {
                name: /Salvar|Save/i,
            })
        ).toHaveClass(/no-perm/)

        await expect(multipleActiveChannelsCard(page)).toBeVisible()
        await expect(multipleActiveChannelsSwitch(page)).toBeDisabled()
        await expect(
            multipleActiveChannelsCard(page).getByRole('button', {
                name: /Salvar|Save/i,
            })
        ).toHaveClass(/no-perm/)
    })
})
