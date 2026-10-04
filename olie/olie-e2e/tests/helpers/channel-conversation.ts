import { type Locator, type Page, expect } from '@playwright/test'
import { requireVisible } from './feature'

/**
 * DOP-1158 — helpers for the channel UI (conversation with an external counterpart).
 *
 * The entry point for creating a channel is `ChannelDialog`, reached from the project's content
 * sidebar (`ChannelSidebar`) or from the overview's `ChannelSelector`. Everything here drives that
 * dialog the way a person does: pick the account, type the phone, submit. Nothing bypasses the UI,
 * so these helpers stay valid as the behaviour behind them changes.
 *
 * The backend `fake` connector cannot be used as a fixture: it is absent from the front's
 * `CONNECTOR_REGISTRY` on purpose, and `connectorFor()` returns `undefined` for it, which breaks
 * the integration picker. `whatsapp_cloud` accepts dummy credentials (nothing is sent to the
 * provider until someone publishes), so it is the fixture used here.
 */

function apiBaseUrl() {
    return process.env.E2E_API_URL || 'http://api.olie.localhost'
}

export type E2EIntegration = {
    id: string
    name: string
}

export type E2ECounterpart = {
    /** What the person types: national BR digits, as `PhoneInput` shows them. */
    national: string
    /** What lands in `external_ref`: the E.164 digits (no `+`, no JID suffix). */
    externalRef: string
}

/**
 * A Brazilian mobile counterpart nobody else in the suite uses.
 *
 * `PhoneInput` only keeps digits that parse for the selected country (`BR` by default) and drops
 * anything else, so this has to be a *valid* BR number — 2-digit area code plus a 9-digit mobile
 * starting with 9 — not just any digit soup. The random tail keeps `external_ref`, which the Cloud
 * connector builds from the E.164 digits (`+55…` stripped), unique across specs sharing the seed
 * frame: an active conversation for the same counterpart is exactly the state these tests create.
 */
export function e2eCounterpart(): E2ECounterpart {
    const stamp = Date.now().toString().slice(-6)
    const rand = String(Math.floor(Math.random() * 90 + 10))
    const national = `119${stamp}${rand}`

    return { national, externalRef: `55${national}` }
}

/**
 * Create an active `whatsapp_cloud` integration with dummy credentials.
 *
 * Must run after login so localStorage carries the bearer token. One per spec: the dialog picks by
 * label, so a dedicated account keeps each test's channels separate.
 */
export async function createE2ECommunicationIntegration(
    page: Page,
    options: { name?: string; config?: Record<string, unknown> } = {}
): Promise<E2EIntegration> {
    const name = options.name ?? `e2e-wa-${Date.now()}`
    const config = { graph_version: 'v21.0', ...(options.config ?? {}) }
    const apiUrl = `${apiBaseUrl()}/api/management/integrations`

    const result = await page.evaluate(
        async ({ apiUrl, name, config }) => {
            const token = localStorage.getItem('token')
            if (!token) return { ok: false as const, error: 'missing token' }

            const res = await fetch(apiUrl, {
                method: 'POST',
                headers: {
                    Authorization: `Bearer ${token}`,
                    'Content-Type': 'application/json',
                    Accept: 'application/json',
                },
                body: JSON.stringify({
                    type: 'whatsapp_cloud',
                    name,
                    credentials: {
                        phone_number_id: '100000000000000',
                        access_token: 'e2e-access-token',
                        app_secret: 'e2e-app-secret',
                        verify_token: 'e2e-verify-token',
                    },
                    config,
                }),
            })

            const data = (await res.json().catch(() => null)) as {
                response?: boolean
                integration?: { id?: string; name?: string }
                message?: string
            } | null

            if (!res.ok || !data?.response || !data.integration?.id) {
                return {
                    ok: false as const,
                    error: data?.message ?? `status=${res.status}`,
                }
            }

            return {
                ok: true as const,
                id: data.integration.id,
                name: data.integration.name ?? name,
            }
        },
        { apiUrl, name, config }
    )

    if (!result.ok) {
        throw new Error(`create integration failed: ${result.error}`)
    }

    return { id: result.id, name: result.name }
}

/** Best-effort cleanup; never fails a test over a leftover fixture. */
export async function deleteE2ECommunicationIntegration(page: Page, integrationId: string) {
    const url = `${apiBaseUrl()}/api/management/integrations/${integrationId}`

    await page
        .evaluate(
            async ({ url }: { url: string }) => {
                const token = localStorage.getItem('token')
                if (!token) return
                await fetch(url, {
                    method: 'DELETE',
                    headers: {
                        Authorization: `Bearer ${token}`,
                        Accept: 'application/json',
                    },
                })
            },
            { url }
        )
        .catch(() => undefined)
}

/**
 * Read one integration back from the API (its `config` is the whole point of these assertions).
 *
 * There is no `GET /integrations/{id}` — the account is read from the index list.
 */
export async function getE2EIntegration(
    page: Page,
    integrationId: string
): Promise<{ id: string; config: Record<string, unknown> } | null> {
    const url = `${apiBaseUrl()}/api/management/integrations`

    return page.evaluate(
        async ({ url, integrationId }: { url: string; integrationId: string }) => {
            const token = localStorage.getItem('token')
            if (!token) return null

            const res = await fetch(url, {
                headers: {
                    Authorization: `Bearer ${token}`,
                    Accept: 'application/json',
                },
            })

            const data = (await res.json().catch(() => null)) as {
                integrations?: Array<{ id?: string; config?: Record<string, unknown> }>
            } | null

            const found = data?.integrations?.find(item => item.id === integrationId)
            if (!found?.id) return null

            return { id: found.id, config: found.config ?? {} }
        },
        { url, integrationId }
    )
}

export type E2EChannel = {
    id: string
    name: string
    is_active: boolean
    external_ref: string | null
    integration_id: string | null
}

/**
 * Channels of a project straight from the API.
 *
 * The rail renders names, not `external_ref` or `is_active`, so any assertion about *which*
 * counterpart a conversation belongs to (or whether it was closed) reads the rows.
 */
export async function listProjectChannels(page: Page, projectId: string): Promise<E2EChannel[]> {
    const apiUrl = `${apiBaseUrl()}/api/management/channels?project_id=${projectId}`

    return page.evaluate(
        async ({ apiUrl }: { apiUrl: string }) => {
            const token = localStorage.getItem('token')
            if (!token) return []

            const res = await fetch(apiUrl, {
                headers: {
                    Authorization: `Bearer ${token}`,
                    Accept: 'application/json',
                },
            })

            const data = (await res.json().catch(() => null)) as {
                channels?: E2EChannel[]
            } | null

            return data?.channels ?? []
        },
        { apiUrl }
    )
}

/**
 * Open (or reopen) a conversation straight through the API. Returns the HTTP status, so callers
 * can tell 201 from the `active_channel_elsewhere` 409 without driving the dialog.
 *
 * Used where the UI is already covered by another spec and the per-frame request budget matters.
 */
export async function openExternalConversationViaApi(
    page: Page,
    args: { projectId: string; integrationId: string; externalRef: string }
): Promise<number> {
    const apiUrl = `${apiBaseUrl()}/api/management/channels/open`

    return page.evaluate(
        async ({ apiUrl, args }) => {
            const token = localStorage.getItem('token')
            if (!token) return 0

            const res = await fetch(apiUrl, {
                method: 'POST',
                headers: {
                    Authorization: `Bearer ${token}`,
                    'Content-Type': 'application/json',
                    Accept: 'application/json',
                },
                body: JSON.stringify({
                    project_id: args.projectId,
                    integration_id: args.integrationId,
                    external_ref: args.externalRef,
                }),
            })

            return res.status
        },
        { apiUrl, args }
    )
}

export function channelDialog(page: Page): Locator {
    return page
        .locator('.p-dialog')
        .filter({ hasText: /Novo canal|New channel/i })
        .first()
}

/** Rail item of a channel in the content sidebar, by its displayed name. */
export function channelRailItem(page: Page, name: string | RegExp): Locator {
    return page
        .locator('.card')
        .filter({ has: page.getByRole('heading', { name: /Canais|Channels/i }) })
        .locator('.d-none.d-md-flex button.btn')
        .filter({ hasText: name })
        .first()
}

/**
 * Open `ChannelDialog` from the project's content tab.
 *
 * The sidebar renders the `+` in its card header on every viewport; the overview's
 * `ChannelSelector` only exposes it in tabs mode, so the content tab is the stable entry point.
 * Scoped to `.channel-rail` because the project header has other icon buttons.
 */
export async function openChannelDialog(page: Page) {
    const contentTab = page.locator('#media_conversation_content')
    await expect(contentTab).toBeVisible({ timeout: 35_000 })

    const plus = page.locator('.channel-rail .card-header button:has(i.fa-plus)').first()
    await expect(plus).toBeVisible({ timeout: 20_000 })
    await plus.click({ force: true })

    const dialog = channelDialog(page)
    await expect(dialog).toBeVisible({ timeout: 15_000 })
    return dialog
}

/** Pick the external-conversation mode (the default when the frame has integrations). */
export async function selectExternalMode(page: Page) {
    const dialog = channelDialog(page)
    const external = dialog
        .locator('button.btn')
        .filter({ hasText: /Conversa externa|External conversation/i })
        .first()
    await expect(external).toBeVisible({ timeout: 10_000 })
    await external.click()
}

export async function pickIntegration(page: Page, integrationName: string) {
    const dialog = channelDialog(page)
    const select = dialog.locator('.p-select').first()
    await expect(select).toBeVisible({ timeout: 15_000 })
    await select.click()

    const option = page.getByRole('option', { name: integrationName }).first()
    await expect(option).toBeVisible({ timeout: 15_000 })
    await option.click()

    await expect(dialog.getByText(integrationName).first()).toBeVisible({ timeout: 10_000 })
}

/** Type the counterpart phone. National digits — the input formats them itself. */
export async function fillCounterpartPhone(page: Page, national: string) {
    const phone = channelDialog(page).locator('input[type="tel"]')
    await expect(phone).toBeVisible({ timeout: 15_000 })
    await phone.click()
    await phone.fill(national)
    await expect(phone).toHaveValue(/\d/)
}

/**
 * Click "Abrir" / "Open" and return the POST /channels/open response (or null when the dialog
 * swallowed it — the 409 recovery answers a Swal instead of a visible error).
 */
export async function submitOpenConversation(page: Page) {
    const response = page.waitForResponse(
        r =>
            /\/channels\/open/.test(r.url()) &&
            r.request().method() === 'POST' &&
            (r.status() === 201 || r.status() === 409 || r.status() === 422),
        { timeout: 30_000 }
    ).catch(() => null)

    const dialog = channelDialog(page)
    await dialog
        .locator('.p-dialog-footer button.btn-primary')
        .filter({ hasText: /Abrir|\bOpen\b/i })
        .first()
        .click({ force: true })

    return response
}

export const ACTIVE_CHANNEL_ELSEWHERE_PROMPT =
    /já tem uma conversa ativa em outro|already has an active conversation in another/i

/** The 409 recovery question (Swal) with the optional closing note. */
export function activeChannelElsewherePrompt(page: Page): Locator {
    return page.locator('.swal2-container').filter({ hasText: ACTIVE_CHANNEL_ELSEWHERE_PROMPT })
}

export async function expectActiveChannelElsewherePrompt(page: Page) {
    const prompt = activeChannelElsewherePrompt(page)
    await expect(prompt).toBeVisible({ timeout: 20_000 })
    await expect(prompt.getByText(/Motivo do encerramento|Closing note/i)).toBeVisible()
    return prompt
}

/** Answer the 409 question. `confirm: false` is the "no, leave it alone" path. */
export async function answerActiveChannelElsewhere(
    page: Page,
    options: { confirm: boolean; reason?: string }
) {
    const prompt = await expectActiveChannelElsewherePrompt(page)

    if (options.reason) {
        await prompt.locator('input[type="text"]').fill(options.reason)
    }

    const button = options.confirm
        ? prompt.getByRole('button', { name: /^(Sim|Yes|Confirmar|Confirm)$/i })
        : prompt.getByRole('button', { name: /^(Não|No|Cancelar|Cancel)$/i })

    await button.click()
}

/**
 * Open an integration's details page from the accounts tab.
 *
 * `IntegrationFormModal` is where DOP-1158's tri-state lands, so the baseline pins what the modal
 * shows for an account today: the credentials section (secrets blanked, never echoed back) and the
 * connector's own settings, `graph_version` for the Cloud API. The details page is where the
 * *effective* value is rendered.
 */
export async function openIntegrationDetails(page: Page, integrationName: string) {
    const row = page
        .locator('.integration-row')
        .filter({ hasText: integrationName })
        .first()
    await expect(row).toBeVisible({ timeout: 30_000 })
    await row.click()

    const edit = page
        .locator('button.btn-primary:has(i.fa-pen)')
        .filter({ hasText: /Editar|Edit/i })
        .first()
    await expect(edit).toBeVisible({ timeout: 30_000 })
}

/** Open an integration's edit modal from the accounts tab. */
export async function openIntegrationForm(page: Page, integrationName: string) {
    await openIntegrationDetails(page, integrationName)

    const edit = page
        .locator('button.btn-primary:has(i.fa-pen)')
        .filter({ hasText: /Editar|Edit/i })
        .first()
    await edit.click()

    const dialog = page
        .locator('.p-dialog')
        .filter({ hasText: /Editar integração|Edit integration/i })
        .first()
    await expect(dialog).toBeVisible({ timeout: 20_000 })
    return dialog
}

/** DOP-1158 tri-state field inside `IntegrationFormModal` (communication connectors only). */
export function multipleActiveChannelsField(dialog: Locator): Locator {
    return dialog.locator('#integration-multiple-active-channels')
}

/** Skip when the front under test lacks DOP-1158's integration override. */
export async function requireMultipleActiveChannelsIntegration(
    page: Page,
    dialog: Locator,
    timeout = 8_000
) {
    await requireVisible(page, 'DOP-1158', multipleActiveChannelsField(dialog), timeout)
}

const MULTIPLE_ACTIVE_CHANNELS_OPTIONS = {
    inherit: /Herdar da empresa|Inherit from the company/i,
    allow: /Permitir várias|Allow several/i,
    block: /Permitir apenas uma|Allow only one/i,
} as const

/** Pick one of the tri-state options and wait for the combobox to show it. */
export async function chooseMultipleActiveChannels(
    page: Page,
    dialog: Locator,
    mode: 'inherit' | 'allow' | 'block'
) {
    const field = multipleActiveChannelsField(dialog)
    await expect(field).toBeVisible({ timeout: 15_000 })
    // The dialog/select transitions can keep the label moving for a frame; Playwright's stability
    // check then blocks until the test timeout. The label spans the whole trigger, so a forced
    // click is safe and opens the listbox regardless of the transition.
    await field.click({ force: true })

    // The option's accessible name is the raw option object (`aria-label` from `getOptionLabel`
    // without an `optionLabel`), so match the visible text instead.
    const option = page
        .locator('[role="option"]')
        .filter({ hasText: MULTIPLE_ACTIVE_CHANNELS_OPTIONS[mode] })
        .first()
    await expect(option).toBeVisible({ timeout: 15_000 })
    await option.click({ force: true })

    await expect(field).toHaveText(MULTIPLE_ACTIVE_CHANNELS_OPTIONS[mode])
}

/** Save the integration modal and wait for the `PUT` to land. */
export async function saveIntegrationForm(page: Page) {
    const response = page.waitForResponse(
        r => /\/integrations\//.test(r.url()) && r.request().method() === 'PUT',
        { timeout: 30_000 }
    )

    const dialog = page.locator('.p-dialog').filter({ hasText: /Editar integração|Edit integration/i })
    await dialog
        .locator('.p-dialog-footer button.btn-primary')
        .filter({ hasText: /Salvar|Save/i })
        .first()
        .click()

    return response
}
