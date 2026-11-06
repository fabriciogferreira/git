import { test, expect, type Page } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { createE2EProject, purgeE2EProjects } from '../helpers/project'
import {
    openProjectContentTab,
    openProjectOverview,
    sendMediaMessage,
} from '../helpers/content-media'

/**
 * DOP-1168 — opening project content with many image messages must land (and
 * stay) at the bottom while media finishes loading; a real user scroll up must
 * release stick-to-bottom so late height growth does not yank the viewport.
 *
 * Shared seed (RECAPTCHA test secret — see workflow-policy Temporary E2E CAPTCHA):
 *   docker compose exec e2e npx playwright test --project=chromium --workers=1 \
 *     tests/features/dop-1168-content-scroll-to-bottom.spec.ts
 */

const API = process.env.E2E_API_URL || 'http://api.olie.localhost'
const PROJECT_PREFIX = 'e2e-dop-1168-'

type ScrollMetrics = {
    scrollTop: number
    scrollHeight: number
    clientHeight: number
    distanceFromEnd: number
}

async function feedMetrics(page: Page, feedSelector: string): Promise<ScrollMetrics> {
    return page.locator(feedSelector).evaluate(el => {
        const distanceFromEnd = el.scrollHeight - el.scrollTop - el.clientHeight
        return {
            scrollTop: el.scrollTop,
            scrollHeight: el.scrollHeight,
            clientHeight: el.clientHeight,
            distanceFromEnd,
        }
    })
}

/** Tall PNG so each message grows the thread after decode (the card's root cause). */
async function seedTallImageMessages(page: Page, projectId: string, count: number) {
    const result = await page.evaluate(
        async ({ apiUrl, projectId, count }) => {
            const token = localStorage.getItem('token')
            if (!token) return { ok: false as const, error: 'missing token' }

            const sleep = (ms: number) => new Promise(r => setTimeout(r, ms))

            const canvas = document.createElement('canvas')
            canvas.width = 480
            canvas.height = 720
            const ctx = canvas.getContext('2d')
            if (!ctx) return { ok: false as const, error: 'no canvas' }
            ctx.fillStyle = '#2c5282'
            ctx.fillRect(0, 0, canvas.width, canvas.height)
            ctx.fillStyle = '#ed8936'
            ctx.fillRect(40, 40, canvas.width - 80, canvas.height - 80)

            const blob = await new Promise<Blob | null>(resolve =>
                canvas.toBlob(resolve, 'image/png')
            )
            if (!blob) return { ok: false as const, error: 'toBlob failed' }

            for (let i = 0; i < count; i++) {
                let lastError = 'unknown'
                for (let attempt = 0; attempt < 5; attempt++) {
                    const form = new FormData()
                    form.append('project_ids[]', projectId)
                    form.append('type', '2')
                    form.append('text', `e2e-dop-1168-img-${i}`)
                    form.append('file[0]', blob, `dop-1168-tall-${i}.png`)

                    const res = await fetch(`${apiUrl}/api/management/save-media`, {
                        method: 'POST',
                        headers: {
                            Authorization: `Bearer ${token}`,
                            Accept: 'application/json',
                        },
                        body: form,
                    })
                    const body = (await res.json().catch(() => null)) as {
                        response?: boolean
                        message?: string
                        error?: string
                        wait_seconds?: number
                    } | null

                    if (res.ok && body?.response !== false) {
                        lastError = ''
                        break
                    }

                    lastError = body?.message ?? body?.error ?? `status=${res.status}`
                    const throttled =
                        res.status === 429 || /too_many_requests/i.test(lastError)
                    if (!throttled) {
                        return { ok: false as const, error: lastError }
                    }

                    const waitSec = Number(
                        res.headers.get('retry-after') ?? body?.wait_seconds ?? 3
                    )
                    await sleep(Math.min(30, Math.max(1, waitSec)) * 1000)
                }

                if (lastError) {
                    return { ok: false as const, error: lastError }
                }

                // Gap between uploads so bulk lock / throttle stay calm across specs.
                await sleep(250)
            }

            return { ok: true as const }
        },
        { apiUrl: API, projectId, count }
    )

    expect(result.ok, `seedTallImageMessages: ${'error' in result ? result.error : ''}`).toBe(
        true
    )
}

async function waitForImages(page: Page, feedSelector: string, minCount = 3) {
    const feed = page.locator(feedSelector)
    await expect
        .poll(async () => feed.locator('img').count(), { timeout: 45_000 })
        .toBeGreaterThanOrEqual(minCount)

    await expect
        .poll(
            async () =>
                feed.locator('img').evaluateAll(
                    (imgs, needed) => {
                        const loaded = imgs.filter(
                            img => (img as HTMLImageElement).naturalHeight > 0
                        )
                        return (
                            loaded.length >= needed &&
                            loaded.every(img => (img as HTMLImageElement).complete)
                        )
                    },
                    minCount
                ),
            { timeout: 45_000 }
        )
        .toBe(true)
}

async function expectNearBottom(page: Page, feedSelector: string, maxDistance = 80) {
    await expect
        .poll(async () => (await feedMetrics(page, feedSelector)).distanceFromEnd, {
            timeout: 20_000,
        })
        .toBeLessThan(maxDistance)
}

test.describe('DOP-1168 content scroll to bottom', () => {
    test.describe.configure({ timeout: 120_000 })

    test('overview ContentWidget sticks to bottom while tall images load', async ({ page }) => {
        const projectName = `${PROJECT_PREFIX}${Date.now()}`
        let created = false

        try {
            await loginAsE2EUser(page)
            const projectId = await createE2EProject(page, { name: projectName, prefix: 'E2E' })
            created = true

            await seedTallImageMessages(page, projectId, 4)

            await openProjectOverview(page, projectId)
            const feed = '#project_media_content'
            await expect(page.locator(feed)).toBeVisible()

            await waitForImages(page, feed)
            await expectNearBottom(page, feed)

            // Grow the conversation after a real user scroll-away: must not yank back.
            await page.locator(feed).evaluate(el => {
                el.dispatchEvent(new WheelEvent('wheel', { deltaY: -400, bubbles: true }))
                el.scrollTop = Math.max(0, el.scrollTop - 500)
                el.dispatchEvent(new Event('scroll'))
            })
            await page.waitForTimeout(200)

            const afterUserScroll = await feedMetrics(page, feed)
            expect(afterUserScroll.distanceFromEnd).toBeGreaterThan(120)

            await page.locator(feed).evaluate(el => {
                const inner = (el.firstElementChild as HTMLElement | null) ?? el
                const spacer = document.createElement('div')
                spacer.style.height = '900px'
                spacer.dataset.e2eDop1168 = '1'
                inner.appendChild(spacer)
            })
            await page.waitForTimeout(400)

            const afterGrowth = await feedMetrics(page, feed)
            expect(
                afterGrowth.distanceFromEnd,
                'user scroll must release stick-to-bottom'
            ).toBeGreaterThan(120)
        } finally {
            if (created) {
                await purgeE2EProjects(page, projectName).catch(() => undefined)
            }
        }
    })

    test('content tab sticks to bottom after open and after send', async ({ page }) => {
        const projectName = `${PROJECT_PREFIX}tab-${Date.now()}`
        let created = false

        try {
            await loginAsE2EUser(page)
            const projectId = await createE2EProject(page, { name: projectName, prefix: 'E2E' })
            created = true

            await seedTallImageMessages(page, projectId, 4)
            await openProjectContentTab(page, projectId)

            const feed = '#media_conversation_content'
            await expect(page.locator(feed)).toBeVisible()

            await waitForImages(page, feed)
            await expectNearBottom(page, feed)

            const message = `e2e-dop-1168-send-${Date.now()}`
            await sendMediaMessage(page, message)
            await expect(page.locator(feed).getByText(message)).toBeVisible({ timeout: 15_000 })
            await expectNearBottom(page, feed)
        } finally {
            if (created) {
                await purgeE2EProjects(page, projectName).catch(() => undefined)
            }
        }
    })
})
