import { type Locator, type Page, expect } from '@playwright/test'
import { requireVisible } from './feature'
import { openProjectOverview } from './content-media'
import { openProjectDetailsTab } from './project'

function apiBaseUrl() {
    return process.env.E2E_API_URL || 'http://api.olie.localhost'
}

/** Popover root for FastAttributeEditor (`#fast_attribute_editor_container`). */
export function fastAttributeEditor(page: Page): Locator {
    return page.locator('#fast_attribute_editor_container')
}

export function fastAttributeCancelButton(editor: Locator): Locator {
    return editor.getByRole('button', { name: /^(Cancelar|Cancel)$/i })
}

export function fastAttributeSaveButton(editor: Locator): Locator {
    return editor.getByRole('button', { name: /^(Salvar|Save)$/i })
}

/**
 * Clear / Limpar in the FastAttributeEditor footer.
 * Feature specs assert it appears; use requireFastAttributeClearButton to skip
 * when the front under test lacks OS-558.
 */
export function fastAttributeClearButton(editor: Locator): Locator {
    return editor.getByRole('button', { name: /^(Limpar|Clear)$/i })
}

/** Skip when Limpar/Clear is not on this front build. */
export async function requireFastAttributeClearButton(
    page: Page,
    editor: Locator
) {
    await requireVisible(page, 'OS-558', fastAttributeClearButton(editor))
}

/** Header field labels (pt-br | en) for ProjectHeaderInfo FastAttributeEditor chips. */
export const HEADER_FIELD_LABEL = {
    status: /^(Status)$/i,
    budget: /^(Receita esperada|Expected revenue)$/i,
    customer: /^(Cliente|Customer)$/i,
    contact: /^(Contato|Contact)$/i,
    assignees: /^(Atribuído a|Attributed to|Assigned to)$/i,
    impact: /^(Impacto|Impact)$/i,
    description: /^(Descrição|Description)$/i,
    tags: /^(Etiquetas|Labels)$/i,
    groups: /^(Grupos|Groups)$/i,
} as const

/** Project header chip that opens the editor for a given label. */
export function headerItemByLabel(page: Page, label: RegExp): Locator {
    return page
        .locator('.project-header-item')
        .filter({
            has: page.getByText(label),
        })
        .first()
}

/** Project header "Descrição" / "Description" chip that opens the editor. */
export function descriptionHeaderItem(page: Page): Locator {
    return headerItemByLabel(page, HEADER_FIELD_LABEL.description)
}

/** Seed / update project fields via PUT (same path as header save). */
export async function updateProjectViaApi(
    page: Page,
    projectId: string,
    payload: Record<string, unknown>
): Promise<void> {
    const apiUrl = `${apiBaseUrl()}/api/management/projects/${projectId}`
    const result = await page.evaluate(
        async ({ apiUrl, payload }) => {
            const token = localStorage.getItem('token')
            if (!token) {
                return { ok: false, status: 0, error: 'missing token' }
            }

            const res = await fetch(apiUrl, {
                method: 'PUT',
                headers: {
                    Authorization: `Bearer ${token}`,
                    'Content-Type': 'application/json',
                    Accept: 'application/json',
                },
                body: JSON.stringify(payload),
            })

            const data = (await res.json().catch(() => null)) as {
                response?: boolean
                message?: string
            } | null

            return {
                ok: res.ok && Boolean(data?.response ?? res.ok),
                status: res.status,
                error: data?.message ?? null,
            }
        },
        { apiUrl, payload }
    )

    if (!result.ok) {
        throw new Error(
            `updateProjectViaApi failed (status=${result.status}): ${result.error ?? 'unknown'}`
        )
    }
}

/** Seed / update project description via PUT (same path as header save). */
export async function setProjectDescriptionViaApi(
    page: Page,
    projectId: string,
    description: string
): Promise<void> {
    await updateProjectViaApi(page, projectId, { description })
}

export async function createE2ECustomer(
    page: Page,
    name?: string
): Promise<{ id: string; name: string }> {
    const customerName = name ?? `e2e-customer-${Date.now()}`
    const apiUrl = `${apiBaseUrl()}/api/management/customers`
    const result = await page.evaluate(
        async ({ apiUrl, customerName }) => {
            const token = localStorage.getItem('token')
            if (!token) {
                return { ok: false, status: 0, error: 'missing token', id: null as string | null }
            }

            const res = await fetch(apiUrl, {
                method: 'POST',
                headers: {
                    Authorization: `Bearer ${token}`,
                    'Content-Type': 'application/json',
                    Accept: 'application/json',
                },
                body: JSON.stringify({
                    name: customerName,
                    customer_type: 1,
                    document_type: 1,
                    contacts: { to_add: [], to_rem: [] },
                    tags: { to_add: [], to_rem: [] },
                }),
            })

            const data = (await res.json().catch(() => null)) as {
                customer?: { id?: string; name?: string }
                data?: { id?: string; name?: string }
                id?: string
                name?: string
                message?: string
                validation?: Record<string, string[]>
            } | null

            const id = data?.customer?.id ?? data?.data?.id ?? data?.id ?? null
            const validation = data?.validation
                ? JSON.stringify(data.validation)
                : null
            return {
                ok: res.ok && Boolean(id),
                status: res.status,
                error: data?.message ?? validation,
                id,
                name:
                    data?.customer?.name ??
                    data?.data?.name ??
                    data?.name ??
                    customerName,
            }
        },
        { apiUrl, customerName }
    )

    if (!result.ok || !result.id) {
        throw new Error(
            `createE2ECustomer failed (status=${result.status}): ${result.error ?? 'unknown'}`
        )
    }

    return { id: result.id, name: result.name }
}

export async function createE2EContact(
    page: Page,
    options: { name?: string; customerId?: string } = {}
): Promise<{ id: string | number; name: string }> {
    const contactName = options.name ?? `e2e-contact-${Date.now()}`
    const apiUrl = `${apiBaseUrl()}/api/management/contacts`
    const result = await page.evaluate(
        async ({ apiUrl, contactName, customerId }) => {
            const token = localStorage.getItem('token')
            if (!token) {
                return { ok: false, status: 0, error: 'missing token', id: null as string | null }
            }

            const body: Record<string, unknown> = {
                name: contactName,
                tags: { to_add: [], to_rem: [] },
                customers: {
                    to_add: customerId ? [customerId] : [],
                    to_rem: [],
                },
            }

            const res = await fetch(apiUrl, {
                method: 'POST',
                headers: {
                    Authorization: `Bearer ${token}`,
                    'Content-Type': 'application/json',
                    Accept: 'application/json',
                },
                body: JSON.stringify(body),
            })

            const data = (await res.json().catch(() => null)) as {
                contact?: { id?: string; name?: string }
                data?: { id?: string; name?: string }
                id?: string
                name?: string
                message?: string
                validation?: Record<string, string[]>
            } | null

            const id = data?.contact?.id ?? data?.data?.id ?? data?.id ?? null
            const validation = data?.validation
                ? JSON.stringify(data.validation)
                : null
            return {
                ok: res.ok && Boolean(id),
                status: res.status,
                error: data?.message ?? validation,
                id,
                name:
                    data?.contact?.name ??
                    data?.data?.name ??
                    data?.name ??
                    contactName,
            }
        },
        { apiUrl, contactName, customerId: options.customerId ?? null }
    )

    if (!result.ok || !result.id) {
        throw new Error(
            `createE2EContact failed (status=${result.status}): ${result.error ?? 'unknown'}`
        )
    }

    return { id: result.id, name: result.name }
}

export async function createE2EProjectGroup(
    page: Page,
    name?: string
): Promise<{ id: number; name: string }> {
    const groupName = name ?? `e2e-group-${Date.now()}`
    const apiUrl = `${apiBaseUrl()}/api/management/project-groups`
    const result = await page.evaluate(
        async ({ apiUrl, groupName }) => {
            const token = localStorage.getItem('token')
            if (!token) {
                return { ok: false, status: 0, error: 'missing token', id: null as number | null }
            }

            const res = await fetch(apiUrl, {
                method: 'POST',
                headers: {
                    Authorization: `Bearer ${token}`,
                    'Content-Type': 'application/json',
                    Accept: 'application/json',
                },
                body: JSON.stringify({ name: groupName }),
            })

            const data = (await res.json().catch(() => null)) as {
                data?: { id?: number; name?: string }
                id?: number
                name?: string
                message?: string
                project_group?: { id?: number; name?: string }
            } | null

            const id =
                data?.project_group?.id ?? data?.data?.id ?? data?.id ?? null
            return {
                ok: res.ok && id != null,
                status: res.status,
                error: data?.message ?? null,
                id,
                name:
                    data?.project_group?.name ??
                    data?.data?.name ??
                    data?.name ??
                    groupName,
            }
        },
        { apiUrl, groupName }
    )

    if (!result.ok || result.id == null) {
        throw new Error(
            `createE2EProjectGroup failed (status=${result.status}): ${result.error ?? 'unknown'}`
        )
    }

    return { id: result.id, name: result.name }
}

/** First frame user available for assignee / user-edge seeding. */
export async function getFirstAssignableUser(
    page: Page
): Promise<{ id: string; name: string }> {
    const apiUrl = `${apiBaseUrl()}/api/management/get-users`
    const result = await page.evaluate(async apiUrl => {
        const token = localStorage.getItem('token')
        if (!token) {
            return {
                ok: false as const,
                error: 'missing token',
                id: null as string | null,
                name: null as string | null,
            }
        }

        const res = await fetch(apiUrl, {
            headers: {
                Authorization: `Bearer ${token}`,
                Accept: 'application/json',
            },
        })
        const data = (await res.json().catch(() => null)) as {
            data?: Array<{ id?: string; name?: string }>
            users?: Array<{ id?: string; name?: string }>
            message?: string
        } | null

        const list = data?.data ?? data?.users ?? []
        const user = list.find(u => u.id)
        return {
            ok: res.ok && Boolean(user?.id),
            error: data?.message ?? `status=${res.status}`,
            id: user?.id ?? null,
            name: user?.name ?? null,
        }
    }, apiUrl)

    if (!result.ok || !result.id) {
        throw new Error(`getFirstAssignableUser failed: ${result.error}`)
    }

    return { id: result.id, name: result.name ?? result.id }
}

/** First frame user id available for assignee seeding (may be the logged-in user). */
export async function getFirstAssignableUserId(page: Page): Promise<string> {
    const user = await getFirstAssignableUser(page)
    return user.id
}

const HEADER_OPTION_IDS = [
    'status',
    'budget',
    'customer',
    'contact',
    'impact',
    'description',
    'tags',
    'groups',
    'assigned_to',
] as const

/**
 * ProjectHeader defaultConfig (v3) has description:false. Force editable
 * FastAttributeEditor chips on so E2E can open each field.
 *
 * Prefer the columns dropdown (live Vue state) — get-auth-user can overwrite
 * localStorage from the server after a reload.
 */
export async function ensureEditableHeaderFieldsVisible(page: Page) {
    const config = {
        version: 3,
        shown: true,
        default_options: Object.fromEntries(HEADER_OPTION_IDS.map(k => [k, true])),
        dynamic_form_options: {},
    }

    await page.evaluate(cfg => {
        localStorage.setItem('ui_project_header_config', JSON.stringify(cfg))
        const store = (
            window as unknown as {
                store?: {
                    dispatch: (type: string, payload: unknown) => unknown
                }
            }
        ).store
        store?.dispatch('system/LocalStorageSetItem', {
            key: 'ui_project_header_config',
            value: JSON.stringify(cfg),
        })
    }, config)

    // Columns dropdown mutates the live infoSectionConfig (survives auth restore).
    const columnsBtn = page
        .locator('button')
        .filter({ has: page.locator('i.fa-columns') })
        .first()
    if ((await columnsBtn.count()) === 0) return
    if (!(await columnsBtn.isVisible().catch(() => false))) return

    await columnsBtn.click()
    const menu = page.locator('.dropdown-menu.show, .dropdown-menu.p-8').last()
    await expect(menu).toBeVisible({ timeout: 5_000 })

    const shown = menu.locator('#config_shown')
    await expect(shown).toBeVisible({ timeout: 5_000 })
    if (!(await shown.isChecked())) {
        await shown.check()
    }

    // Prefer the visible default-options column (duplicate ids exist in a d-none col).
    const optionsCol = menu.locator('.col').filter({ hasNot: page.locator('.d-none') }).first()
    for (const option of HEADER_OPTION_IDS) {
        const checkbox = optionsCol.locator(`#config_show_${option}`).first()
        if ((await checkbox.count()) === 0) continue
        if (await checkbox.isDisabled()) continue
        if (!(await checkbox.isChecked())) {
            await checkbox.check()
        }
    }
    await page.keyboard.press('Escape')
    await expect(page.locator('.project-header-item').first()).toBeVisible({
        timeout: 10_000,
    })
}

/**
 * ProjectHeader defaultConfig (v3) has description:false. Force it on so
 * Descrição is available for FastAttributeEditor smoke/E2E.
 */
export async function ensureDescriptionHeaderVisible(page: Page) {
    await ensureEditableHeaderFieldsVisible(page)
}

/**
 * Open project overview and click a header chip to show FastAttributeEditor.
 * Uses project find (not media feed) so header chips are available even if the
 * content widget is slow / rate-limited.
 */
export async function openHeaderFastAttributeEditor(
    page: Page,
    projectId: string,
    label: RegExp
): Promise<Locator> {
    await openProjectDetailsTab(page, projectId, 'overview')
    // Wait until project shell is past "Carregando..." (find finished).
    await expect(page.locator('.project-header-item, .fa-columns').first()).toBeVisible({
        timeout: 40_000,
    })
    await ensureEditableHeaderFieldsVisible(page)

    const headerItem = headerItemByLabel(page, label)
    await expect(headerItem).toBeVisible({ timeout: 20_000 })
    // Prefer the fw-light label: customer/contact values are router-links with @click.stop.
    const labelEl = headerItem.locator('.fw-light').first()
    if ((await labelEl.count()) > 0) {
        await labelEl.click()
    } else {
        await headerItem.click()
    }

    // Never leave project details via a nested router-link.
    await expect(page).toHaveURL(new RegExp(`/projects/${projectId}/details`), {
        timeout: 5_000,
    })

    const editor = fastAttributeEditor(page)
    await expect(editor).toBeVisible({ timeout: 10_000 })
    return editor
}

/**
 * Open project overview and click Descrição to show FastAttributeEditor.
 */
export async function openDescriptionFastAttributeEditor(
    page: Page,
    projectId: string
): Promise<Locator> {
    return openHeaderFastAttributeEditor(page, projectId, HEADER_FIELD_LABEL.description)
}

export async function fillFastAttributeTextarea(
    editor: Locator,
    value: string
): Promise<void> {
    const field = editor.locator('textarea, input').first()
    await expect(field).toBeVisible({ timeout: 5_000 })
    await field.click()
    await field.fill(value)
    await expect(field).toHaveValue(value)
}

/** Wait for PUT /projects/{id} after Salvar and return the response. */
export async function waitForProjectPut(
    page: Page,
    projectId: string,
    action: () => Promise<void>
) {
    const saveResponse = page.waitForResponse(
        r => {
            if (r.request().method() !== 'PUT') return false
            try {
                return new URL(r.url()).pathname.endsWith(`/projects/${projectId}`)
            } catch {
                return false
            }
        },
        { timeout: 30_000 }
    )
    await action()
    return saveResponse
}


export type E2EFormEdge = {
    id: number
    type: string
    label: string
    required?: boolean
    is_multiple?: boolean
    options?: unknown
    form_id?: number
}

/** Create a disposable dynamic form with the given edges via POST /save-form. */
export async function createE2EDynamicForm(
    page: Page,
    options: {
        title?: string
        edges: Array<{
            label: string
            type: string
            required?: boolean
            is_multiple?: boolean
            index?: number
        }>
    }
): Promise<{ formId: number; edges: E2EFormEdge[] }> {
    const title = options.title ?? `e2e-form-${Date.now()}`
    const apiUrl = `${apiBaseUrl()}/api/management/save-form`
    const result = await page.evaluate(
        async ({ apiUrl, title, edges }) => {
            const token = localStorage.getItem('token')
            if (!token) {
                return { ok: false, status: 0, error: 'missing token', formId: null, edges: [] as unknown[] }
            }

            const res = await fetch(apiUrl, {
                method: 'POST',
                headers: {
                    Authorization: `Bearer ${token}`,
                    'Content-Type': 'application/json',
                    Accept: 'application/json',
                },
                body: JSON.stringify({
                    title,
                    edges: edges.map((edge, index) => ({
                        label: edge.label,
                        type: edge.type,
                        required: edge.required ?? false,
                        is_multiple: edge.is_multiple ?? false,
                        index: edge.index ?? index,
                    })),
                }),
            })

            const data = (await res.json().catch(() => null)) as {
                response?: boolean
                form?: { id?: number; edges?: E2EFormEdge[] }
                message?: string
            } | null

            return {
                ok: res.ok && Boolean(data?.response && data?.form?.id),
                status: res.status,
                error: data?.message ?? null,
                formId: data?.form?.id ?? null,
                edges: data?.form?.edges ?? [],
            }
        },
        { apiUrl, title, edges: options.edges }
    )

    if (!result.ok || result.formId == null) {
        throw new Error(
            `createE2EDynamicForm failed (status=${result.status}): ${result.error ?? 'unknown'}`
        )
    }

    return { formId: result.formId, edges: result.edges as E2EFormEdge[] }
}

/**
 * Open FastAttributeEditor for a dynamic-form edge via store dispatch.
 * Avoids kanban card-config setup; still uses the real editor + DynamicInputPreview.
 */
export async function openDynamicFormFastAttributeEditor(
    page: Page,
    edge: E2EFormEdge,
    modelValue: unknown
): Promise<Locator> {
    // Close any open editor first.
    const existing = fastAttributeEditor(page)
    if ((await existing.count()) > 0) {
        const cancel = fastAttributeCancelButton(existing)
        if ((await cancel.count()) > 0) {
            await cancel.click()
        }
        await expect(fastAttributeEditor(page)).toHaveCount(0, { timeout: 10_000 })
    }

    await page.evaluate(
        ({ edge, modelValue }) => {
            const store = (
                window as unknown as {
                    store?: {
                        dispatch: (type: string, payload: unknown) => unknown
                    }
                }
            ).store
            if (!store) throw new Error('Vuex store not found on window')

            // Anchor in the main content area so OverlayPanel is not under the sidebar.
            let anchor = document.getElementById('e2e-fae-anchor') as HTMLButtonElement | null
            if (!anchor) {
                anchor = document.createElement('button')
                anchor.id = 'e2e-fae-anchor'
                anchor.type = 'button'
                anchor.setAttribute('aria-hidden', 'true')
                document.body.appendChild(anchor)
            }
            anchor.style.cssText =
                'position:fixed;left:min(55vw,720px);top:min(40vh,320px);width:48px;height:48px;opacity:0.01;z-index:9998;border:0;padding:0;margin:0'

            return new Promise<void>((resolve, reject) => {
                const onClick = (event: MouseEvent) => {
                    try {
                        store.dispatch('system/InitFastAttributeEdit', {
                            model: 'ProjectDynamicForm',
                            dynamicFormEdge: edge,
                            attribute: edge.id,
                            modelValue,
                            event,
                            saveCallback: () => undefined,
                            showButtons: true,
                        })
                        resolve()
                    } catch (err) {
                        reject(err)
                    }
                }
                anchor!.addEventListener('click', onClick, { once: true })
                anchor!.click()
            })
        },
        { edge, modelValue }
    )

    const editor = fastAttributeEditor(page)
    await expect(editor).toBeVisible({ timeout: 10_000 })
    return editor
}

/** TipTap doc with a single text paragraph (rich_text answer shape). */
export function richTextAnswerDoc(text: string) {
    return {
        type: 'doc',
        content: [
            {
                type: 'paragraph',
                content: [{ type: 'text', text }],
            },
        ],
    }
}
