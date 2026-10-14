import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import {
    audioTranscriptionSettingsRow,
    audioTranscriptionSwitch,
    businessRulesCard,
    companyAudioTranscriptionEnabled,
    openFrameSettings,
    requireAudioTranscriptionSettings,
    saveCompanyAudioTranscription,
} from '../helpers/frame-settings'

/**
 * DOP-1214 — audio transcription toggle on `/frame/settings` Business Rules.
 *
 * Skips via `requireAudioTranscriptionSettings` when the row is absent on the
 * front under test. Uses the shared e2e user and restores the prior value
 * (same pattern as DOP-1157), so a broken isolated-register path does not
 * block this card.
 */
test.describe('DOP-1214 audio transcription — company toggle', () => {
    test.describe.configure({ timeout: 120_000 })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
        await openFrameSettings(page)
        await requireAudioTranscriptionSettings(page)
    })


    test('shows the switch and credits copy', async ({ page }) => {
        const row = audioTranscriptionSettingsRow(page)

        await expect(row).toBeVisible()
        await expect(audioTranscriptionSwitch(page)).toBeVisible()
        await expect(
            row.getByText(/Transcrever áudios automaticamente|Transcribe audios automatically/i)
        ).toBeVisible()
        await expect(
            row.getByText(/créditos de IA|AI credits/i)
        ).toBeVisible()
        await expect(
            businessRulesCard(page).getByRole('button', { name: /Salvar|Save/i })
        ).toBeVisible()
    })

    test('defaults on, saves false, and keeps the value after reload', async ({ page }) => {
        // New frames get the API default (true).
        await expect(audioTranscriptionSwitch(page)).toBeChecked({ checked: true })

        const before = await companyAudioTranscriptionEnabled(page)
        const target = !before

        const response = await saveCompanyAudioTranscription(page, target)
        expect(response.status()).toBe(200)

        const posted = response.request().postDataJSON() as Record<string, unknown>
        expect(posted.audio_transcription_enabled).toBe(target)
        // Business Rules posts both keys on this card.
        expect(posted).toHaveProperty('remove_inactive_users_from_funnels')

        await expect(
            page.getByText(
                /Regras de negócio salvas com sucesso|Business rules saved successfully/i
            ).first()
        ).toBeVisible({ timeout: 15_000 })

        await openFrameSettings(page)
        await requireAudioTranscriptionSettings(page)
        await expect(audioTranscriptionSwitch(page)).toBeChecked({ checked: target })

        const restore = await saveCompanyAudioTranscription(page, before)
        expect(restore.status()).toBe(200)
    })
})
