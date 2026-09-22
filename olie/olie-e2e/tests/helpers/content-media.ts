import { type Page, expect } from '@playwright/test'

export type ContentFilter = 'default' | 'content' | 'logs'

const FILTER_OPTION_NAME: Record<ContentFilter, RegExp> = {
    default: /^Conteúdo e Logs$|^Content and Logs$/i,
    content: /^Conteúdo$|^Content$/i,
    logs: /^Logs$/i,
}

/**
 * Apply the content/logs filter after the widget is on screen.
 *
 * Writing localStorage before navigation is not enough: get-auth-user restores
 * `current_relationship.local_storage` from the server and can overwrite the key
 * with a stale value (often `"logs"` from earlier E2E runs).
 */
export async function setContentFilter(page: Page, filter: ContentFilter) {
    await page.evaluate(value => {
        localStorage.setItem('selected_project_content_filter', JSON.stringify(value))
    }, filter)

    const select = page.locator('.content-toolbar .p-select').first()
    await expect(select).toBeVisible({ timeout: 15_000 })
    await select.click()
    await page.getByRole('option', { name: FILTER_OPTION_NAME[filter] }).click()
    await expect(select).toHaveText(FILTER_OPTION_NAME[filter])
}

async function openWithFeed(page: Page, path: string, feedSelector: string) {
    await page.goto(path)
    const feed = page.locator(feedSelector)
    try {
        await expect(feed).toBeVisible({ timeout: 35_000 })
    } catch {
        // Blank shell (KeepAlive / slow get-auth-user) — one reload within the 90s budget.
        await page.reload()
        await expect(feed).toBeVisible({ timeout: 35_000 })
    }
}

export async function openProjectOverview(page: Page, projectId: string) {
    await openWithFeed(page, `/projects/${projectId}/details/overview`, '#project_media_content')
}

export async function openProjectContentTab(page: Page, projectId: string) {
    await openWithFeed(page, `/projects/${projectId}/details/content`, '#media_conversation_content')
}

export async function sendMediaMessage(page: Page, message: string) {
    // TipTap keeps draft in Vue (`draftMarkdown`); Playwright `fill()` often updates the
    // contenteditable DOM without emitting the editor update — type via the keyboard.
    const prose = page.locator('.ProseMirror').last()
    await prose.click()
    await page.keyboard.type(message, { delay: 10 })
    await expect(prose).toContainText(message)

    const send = page.locator('button.btn-primary').filter({ has: page.locator('.fa-paper-plane') })
    await Promise.all([
        page.waitForResponse(
            r => r.url().includes('/save-media') && r.request().method() === 'POST' && r.ok(),
            { timeout: 20_000 }
        ),
        send.click(),
    ])
}
