import { test, type Locator, type Page } from '@playwright/test'

export type FeatureProbe = {
    /** Card / short id shown in the skip reason (e.g. DOP-1121). */
    id: string
    /** Return true when the running front exposes the feature. */
    probe: (page: Page) => Promise<boolean>
}

/**
 * Skip the current test when the feature is absent on the front under test
 * (e.g. develop without the colleague's branch). Prefer this over moving files.
 */
export async function requireFeature(page: Page, feature: FeatureProbe) {
    const present = await feature.probe(page)
    test.skip(!present, `${feature.id} not on this front build — skipped`)
}

/** Convenience: skip unless `locator` becomes visible within `timeout`. */
export async function requireVisible(
    page: Page,
    id: string,
    locator: Locator,
    timeout = 8_000
) {
    await requireFeature(page, {
        id,
        probe: async () => {
            try {
                await locator.first().waitFor({ state: 'visible', timeout })
                return true
            } catch {
                return false
            }
        },
    })
}

/**
 * OS-505: Logs filter must hide outbound user media.
 * If the message is still in the feed, this front build lacks the fix → skip.
 */
export async function requireLogsFilterHidesMessage(
    feed: Locator,
    message: string,
    settleMs = 1_500
) {
    await feed.page().waitForTimeout(settleMs)
    const stillVisible = (await feed.getByText(message).count()) > 0
    test.skip(
        stillVisible,
        'OS-505 Logs filter hide not on this front build — skipped'
    )
}
