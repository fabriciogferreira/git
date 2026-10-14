import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import {
    expectInsufficientCreditsCopyAndRetry,
    injectInsufficientCreditsAudio,
    requireInsufficientCreditsTranscriptionUi,
} from '../helpers/audio-transcription'
import { openProjectOverview, setContentFilter } from '../helpers/content-media'
import { createE2EProject } from '../helpers/project'

/**
 * DOP-1214 — insufficient_credits copy + retry on the content widget.
 *
 * The media list is patched so the bubble renders without emptying the wallet
 * or waiting on OpenRouter. Skips when the front lacks the new status UI.
 */
test.describe('DOP-1214 audio transcription — insufficient credits UI', () => {
    test.describe.configure({ timeout: 90_000 })

    test('shows credits copy and a retry control on the audio bubble', async ({ page }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-dop1214-credits-${Date.now()}`,
        })

        await injectInsufficientCreditsAudio(page, projectId)
        await openProjectOverview(page, projectId)
        await setContentFilter(page, 'content')

        await requireInsufficientCreditsTranscriptionUi(page)
        await expectInsufficientCreditsCopyAndRetry(page)

        await expect(page.locator('.audio-transcription.border-warning')).toBeVisible()
    })
})

/**
 * With the company toggle off, failed / insufficient_credits bubbles keep the
 * status copy but must not invite a retry that the API would refuse.
 */
test.describe('DOP-1214 audio transcription — retry hidden when toggle off', () => {
    test.describe.configure({ timeout: 90_000 })

    test('hides retry on insufficient_credits when transcription is disabled', async ({ page }) => {
        await loginAsE2EUser(page)

        // Seed the cache the front will read on the media list inject path.
        await page.route('**/frame-configurations/audio_transcription_enabled**', async route => {
            if (route.request().method() !== 'GET') {
                await route.continue()
                return
            }

            await route.fulfill({
                status: 200,
                contentType: 'application/json',
                body: JSON.stringify({
                    response: true,
                    configuration: false,
                }),
            })
        })

        const projectId = await createE2EProject(page, {
            name: `e2e-dop1214-no-retry-${Date.now()}`,
        })

        await injectInsufficientCreditsAudio(page, projectId)
        await openProjectOverview(page, projectId)
        await setContentFilter(page, 'content')

        await requireInsufficientCreditsTranscriptionUi(page)

        const bubble = page.locator('.audio-transcription')
        await expect(bubble).toBeVisible({ timeout: 15_000 })
        await expect(
            bubble.getByText(/Transcrição não realizada: sem créditos de IA|Transcription skipped: not enough AI credits/i)
        ).toBeVisible()
        await expect(
            bubble.getByRole('button', { name: /Tentar novamente|Try again/i })
        ).toHaveCount(0)
    })
})
