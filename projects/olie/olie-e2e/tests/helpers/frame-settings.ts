import { type Locator, type Page, expect } from '@playwright/test'
import { requireVisible } from './feature'
import { resolvePageOrigin } from './navigation'

type FrameConfigurationsPayload = {
    configurations?: Record<string, unknown>
}

function apiBaseUrl() {
    return process.env.E2E_API_URL || 'http://api.olie.localhost'
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

        await page.goto(`${resolvePageOrigin(page)}/frame/settings`)
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
 * Set the debounce input via clear + type so the Vue draft/@input path runs.
 * Plain `fill(value)` alone can skip the input handler before Save.
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

/** DOP-1158 multiple-active-conversations card. */
export function multipleActiveChannelsCard(page: Page): Locator {
    return page.locator('#multiple_active_channels_settings')
}

export function multipleActiveChannelsSwitch(page: Page): Locator {
    return multipleActiveChannelsCard(page).locator('#allow_multiple_active_channels')
}

export async function companyAllowsMultipleActiveChannels(page: Page): Promise<boolean> {
    return multipleActiveChannelsSwitch(page).isChecked()
}

/**
 * Skip when this front build lacks the DOP-1158 settings card
 * (e.g. develop without the feature branch).
 */
export async function requireMultipleActiveChannelsSettings(page: Page, timeout = 8_000) {
    await requireVisible(page, 'DOP-1158', multipleActiveChannelsCard(page), timeout)
}

/**
 * Set the company switch to `value` (no-op when already there) and save it.
 * Resolves with the POST response so callers can assert the partial payload.
 */
export async function saveCompanyMultipleActiveChannels(page: Page, value: boolean) {
    const card = multipleActiveChannelsCard(page)
    const toggle = multipleActiveChannelsSwitch(page)

    if ((await toggle.isChecked()) !== value) {
        await toggle.click({ force: true })
        await expect(toggle).toBeChecked({ checked: value })
    }

    const response = page.waitForResponse(
        r =>
            /frame-configurations/.test(r.url()) &&
            r.request().method() === 'POST' &&
            (r.status() === 200 || r.status() === 422),
        { timeout: 30_000 }
    )

    await card.getByRole('button', { name: /Salvar|Save/i }).click({ force: true })

    return response
}

/**
 * Set the company default straight through the API, bypassing `/frame/settings`.
 *
 * The card is covered by `dop-1158-company-settings.spec.ts`; a behaviour spec that only needs the
 * value flipped must not spend the per-frame request budget on a full settings page load.
 */
export async function setCompanyMultipleActiveChannelsViaApi(
    page: Page,
    value: boolean
): Promise<number> {
    const apiUrl = `${apiBaseUrl()}/api/management/frame-configurations`

    return page.evaluate(
        async ({ apiUrl, value }) => {
            const token = localStorage.getItem('token')
            if (!token) return 0

            const res = await fetch(apiUrl, {
                method: 'POST',
                headers: {
                    Authorization: `Bearer ${token}`,
                    'Content-Type': 'application/json',
                    Accept: 'application/json',
                },
                body: JSON.stringify({ allow_multiple_active_channels: value }),
            })

            return res.status
        },
        { apiUrl, value }
    )
}
