import { type Page, expect } from '@playwright/test'
import { requireVisible } from './feature'

/**
 * DOP-1214 — inject a finished audio whose transcription stopped for
 * insufficient AI credits into the next `POST …/projects/{id}/media` response.
 *
 * Creating a real empty-wallet + provider round-trip is flaky in e2e; the UI
 * only needs the status + copy + retry control on screen.
 */
export async function injectInsufficientCreditsAudio(page: Page, projectId: string) {
    const mediaId = `e2e-insufficient-credits-${Date.now()}`

    await page.route(`**/projects/${projectId}/media**`, async route => {
        if (route.request().method() !== 'POST') {
            await route.continue()
            return
        }

        const response = await route.fetch()
        const body = (await response.json().catch(() => null)) as {
            medias?: Record<string, unknown>[]
            response?: boolean
        } | null

        const injected = {
            id: mediaId,
            name: 'e2e-insufficient-credits.ogg',
            technical_name: 'e2e-insufficient-credits.ogg',
            type: 3,
            extension: 'ogg',
            text: null,
            file_url: 'https://cdn.test/e2e-insufficient-credits.ogg',
            transcription_status: 'insufficient_credits',
            transcription: null,
            log: null,
            user_id: null,
            project_id: projectId,
            channel_id: null,
            direction: 'outbound',
            origin: 'internal',
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
            deleted_at: null,
        }

        const medias = Array.isArray(body?.medias) ? body.medias : []

        await route.fulfill({
            status: response.status(),
            contentType: 'application/json',
            body: JSON.stringify({
                ...body,
                response: true,
                medias: [injected, ...medias],
            }),
        })
    })


    return mediaId
}

/** Bubble that renders `AudioTranscription` for an audio media. */
export function audioTranscriptionBubble(page: Page) {
    return page.locator('.audio-transcription')
}

/**
 * Skip when this front build lacks the insufficient_credits transcription UI
 * (e.g. develop without the feature branch).
 */
export async function requireInsufficientCreditsTranscriptionUi(page: Page, timeout = 12_000) {
    await requireVisible(
        page,
        'DOP-1214',
        audioTranscriptionBubble(page).getByText(
            /sem créditos de IA|not enough AI credits/i
        ),
        timeout
    )
}

export async function expectInsufficientCreditsCopyAndRetry(page: Page) {
    const bubble = audioTranscriptionBubble(page)

    await expect(bubble).toBeVisible({ timeout: 15_000 })
    await expect(
        bubble.getByText(/Transcrição não realizada: sem créditos de IA|Transcription skipped: not enough AI credits/i)
    ).toBeVisible()
    await expect(
        bubble.getByRole('button', { name: /Tentar novamente|Try again/i })
    ).toBeVisible()
}
