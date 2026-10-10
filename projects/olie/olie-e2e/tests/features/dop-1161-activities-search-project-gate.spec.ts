import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { createE2EProject, openProjectDetailsTab } from '../helpers/project'
import {
    isSearchActivitiesRequest,
    logsPanel,
    projectHistoryButton,
    requireProjectHistoryGate,
    stripActivitiesSearchAndRemountProject,
} from '../helpers/activity-history'

/**
 * DOP-1161 — UI gate for activity history on project details.
 *
 * Happy path uses the seeded tester (normally has activities.search).
 * Negative path strips the permission from Vuex + remounts ProjectDetails
 * (no page.route/fetch — Node DNS cannot reach api.olie.localhost in Docker).
 */
test.describe('DOP-1161 activities.search project history gate', () => {
    test.describe.configure({ timeout: 90_000 })

    let projectId: string

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
        projectId = await createE2EProject(page, {
            name: `e2e-dop-1161-${Date.now()}`,
            prefix: 'E2E',
        })
        await openProjectDetailsTab(page, projectId, 'overview')
        await requireProjectHistoryGate(page)
    })

    test('with permission: history button opens panel and POSTs /search-activities', async ({
        page,
    }) => {
        const historyBtn = projectHistoryButton(page)
        await expect(historyBtn).toBeVisible()
        await expect(historyBtn).not.toHaveClass(/d-none/)

        const searchResponse = page.waitForResponse(
            r =>
                isSearchActivitiesRequest(r.url(), r.request().method()) &&
                (r.status() === 200 || r.status() === 403),
            { timeout: 30_000 }
        )

        await historyBtn.click()

        await expect(logsPanel(page)).toBeVisible({ timeout: 15_000 })
        const response = await searchResponse
        expect(response.status()).toBe(200)

        await page.keyboard.press('Escape')
        await expect(logsPanel(page)).toHaveCount(0, { timeout: 10_000 })
    })

    test('without permission: history button hidden and no search-activities', async ({
        page,
    }) => {
        await stripActivitiesSearchAndRemountProject(page, projectId)

        const historyBtn = projectHistoryButton(page)
        const count = await historyBtn.count()

        if (count > 0) {
            await expect(historyBtn).toHaveClass(/d-none/)
            await expect(historyBtn).not.toBeVisible()
        }

        let posted = false
        page.on('request', request => {
            if (isSearchActivitiesRequest(request.url(), request.method())) {
                posted = true
            }
        })

        await page.waitForTimeout(1_500)
        expect(posted).toBe(false)
        await expect(logsPanel(page)).toHaveCount(0)
    })

    test('LogsActivityOffset guard: forced open without permission does not panel/POST', async ({
        page,
    }) => {
        await stripActivitiesSearchAndRemountProject(page, projectId)

        let posted = false
        page.on('request', request => {
            if (isSearchActivitiesRequest(request.url(), request.method())) {
                posted = true
            }
        })

        // Reveal + click the gated button so LogsActivityOffset receives open=true;
        // the component guard must refuse to show / fetch.
        const forced = await page.evaluate(() => {
            const btn =
                (
                    document.querySelector(
                        'button.btn-icon[data-permission="activities.search"] i.fa-clock'
                    ) as HTMLElement | null
                )?.closest('button') ??
                (
                    document.querySelector('button.btn-sm.btn-icon i.fa-clock') as HTMLElement | null
                )?.closest('button')

            if (!btn) return false
            btn.classList.remove('d-none')
            ;(btn as HTMLButtonElement).style.display = ''
            ;(btn as HTMLButtonElement).click()
            return true
        })

        test.skip(
            !forced,
            'DOP-1161 LogsActivityOffset force-open path unavailable — skipped'
        )

        await page.waitForTimeout(1_200)
        await expect(logsPanel(page)).toHaveCount(0)
        expect(posted).toBe(false)
    })
})
