import { test, expect } from '@playwright/test'
import { loginAsDoctor, meetingConsultationId } from './helpers/doctor'

/**
 * TV-35 — the doctor join link names the consultation.
 * The shared /meet/enterscience path is not the room.
 */
test.describe('TV-35 consultation meeting link', () => {
    test.describe.configure({ timeout: 120_000 })

    test('doctor join opens /consultation/{id} with the meeting token', async ({ page }) => {
        const consultationId = meetingConsultationId()
        await loginAsDoctor(page)
        await page.goto(`/dashboard/consultations/view/${consultationId}`)

        const join = page.locator(`#join-meeting-${consultationId}-button-tooltip`)
        await expect(join).toBeVisible({ timeout: 30_000 })

        let landed = ''
        const tokenResponse = page.waitForResponse(
            response =>
                response.url().includes(`/consultations/${consultationId}/meeting-token`) &&
                response.request().method() === 'POST' &&
                response.ok(),
            { timeout: 30_000 }
        )
        const navigation = page.waitForURL(
            url => {
                const href = url.toString()
                const matches =
                    href.includes(`/consultation/${consultationId}`) &&
                    href.includes('token=') &&
                    !href.includes('/meet/enterscience')
                if (matches) {
                    landed = href
                }
                return matches
            },
            { timeout: 30_000 }
        )

        await join.click()
        const [response] = await Promise.all([tokenResponse, navigation])
        const body = (await response.json()) as { token?: string }
        const landedUrl = new URL(landed)

        expect(body.token).toBeTruthy()
        expect(landedUrl.pathname).toBe(`/consultation/${consultationId}`)
        expect(landedUrl.searchParams.get('token')).toBe(body.token)
        expect(landedUrl.searchParams.get('consultationId')).toBeNull()
        expect(landed).not.toContain('/meet/enterscience')
    })
})
