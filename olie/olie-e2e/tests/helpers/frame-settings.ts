import { type Locator, type Page, expect } from '@playwright/test'
import { requireVisible } from './feature'

type FrameConfigurationsPayload = {
    configurations?: Record<string, unknown>
}

/**
 * Opens Frame → Settings (company configurations).
 * Retries when Vite HMR / slow current_frame leaves the route on "Carregando…".
 */
export async function openFrameSettings(page: Page) {
    for (let attempt = 1; attempt <= 3; attempt++) {
        const configsPromise = page
            .waitForResponse(
                r =>
                    /frame-configurations/.test(r.url()) &&
                    r.request().method() === 'GET' &&
                    r.ok(),
                { timeout: 20_000 }
            )
            .catch(() => null)

        await page.goto('/frame/settings')
        await expect(page).toHaveURL(/\/frame\/settings/, { timeout: 15_000 })

        const reloadBtn = page.getByRole('button', { name: /^Recarregar$|^Reload$/i })
        if (await reloadBtn.isVisible().catch(() => false)) {
            await reloadBtn.click()
        }

        try {
            await expect(page.locator('#settings_overview')).toBeVisible({
                timeout: 15_000,
            })

            const response = await configsPromise
            if (response && (await contentAddedDebounceCard(page).count()) > 0) {
                const body = (await response.json().catch(() => null)) as FrameConfigurationsPayload | null
                const debounce = body?.configurations?.content_added_debounce_seconds
                if (debounce != null) {
                    await expect(contentAddedDebounceInput(page)).toHaveValue(
                        String(debounce),
                        { timeout: 10_000 }
                    )
                }
            }

            return
        } catch (error) {
            if (attempt === 3) throw error
            await page.locator('a[href="/frame/settings"]').last().click().catch(() => undefined)
        }
    }
}

/** Notifications card (assignee / unassignee message configs). */
export function notificationsCard(page: Page): Locator {
    return page
        .locator('.card')
        .filter({
            has: page.getByRole('heading', {
                name: /Notificações de usuários|User notifications/i,
            }),
        })
        .first()
}

/** Business rules card (remove inactive users from funnels, etc.). */
export function businessRulesCard(page: Page): Locator {
    return page
        .locator('.card')
        .filter({
            has: page.getByRole('heading', {
                name: /Regras de Negócio|Business Rules/i,
            }),
        })
        .first()
}

/** DOP-1157 content-added debounce card. */
export function contentAddedDebounceCard(page: Page): Locator {
    return page.locator('#content_added_debounce_settings')
}

export function contentAddedDebounceInput(page: Page): Locator {
    return contentAddedDebounceCard(page).locator('#content_added_debounce_seconds')
}

/**
 * Set the debounce input so Vue `v-model.number` stays in sync.
 * Plain `fill()` can update the DOM without updating the model before Save.
 */
export async function setContentAddedDebounceSeconds(page: Page, value: string) {
    const input = contentAddedDebounceInput(page)
    await input.click()
    await input.fill('')
    await input.pressSequentially(value, { delay: 15 })
    await input.blur()
    await expect(input).toHaveValue(value)
}

/**
 * Skip when this front build lacks the DOP-1157 settings card
 * (e.g. develop without the feature branch).
 */
export async function requireContentAddedDebounceSettings(page: Page) {
    await requireVisible(page, 'DOP-1157', contentAddedDebounceCard(page), 8_000)
}
