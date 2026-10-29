import { type Page, expect } from '@playwright/test'
import { loginAsDoctor } from './doctor'

/** Consultation whose join window is open (seeded at now+5min). */
export function joinMeetingInsideConsultationId(): string {
    const id = process.env.E2E_JOIN_MEETING_INSIDE_ID
    if (!id) {
        throw new Error(
            'E2E_JOIN_MEETING_INSIDE_ID is required (seed scripts/seed-join-meeting-window.sh)'
        )
    }
    return id
}

/** Consultation still outside the join window (seeded at now+20min). */
export function joinMeetingOutsideConsultationId(): string {
    const id = process.env.E2E_JOIN_MEETING_OUTSIDE_ID
    if (!id) {
        throw new Error(
            'E2E_JOIN_MEETING_OUTSIDE_ID is required (seed scripts/seed-join-meeting-window.sh)'
        )
    }
    return id
}

export function joinMeetingButton(page: Page, consultationId: string) {
    return page.locator(`#join-meeting-${consultationId}-button-tooltip`)
}

export async function openConsultationView(page: Page, consultationId: string) {
    await loginAsDoctor(page)
    await page.goto(`/dashboard/consultations/view/${consultationId}`)
    await expect(page.getByText(/Exame ocular|Dados do paciente|Paciente/i).first()).toBeVisible({
        timeout: 30_000,
    })
}
