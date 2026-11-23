import { test, expect, type Locator } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import { createE2EProject, openProjectDetailsTab, purgeE2EProjects } from '../helpers/project'
import {
    createE2EDynamicForm,
    fastAttributeEditor,
    openDynamicFormFastAttributeEditor,
    type E2EFormEdge,
} from '../helpers/fast-attribute-editor'
import { requireFeature } from '../helpers/feature'
import { setResolvedTheme } from '../helpers/theme'
import path from 'node:path'
import { writeFileSync, mkdirSync } from 'node:fs'
import { tmpdir } from 'node:os'

/**
 * DOP-1288 — attachment fields that allow more than one file must open the
 * OS picker with `multiple` and upload every selected file (with per-file progress).
 * Single-file fields stay single.
 *
 * Exercises AttachmentInput via FastAttributeEditor / DynamicInputPreview
 * (same component as card / funnel / public forms).
 */
test.describe('DOP-1288 multiple file upload on attachment fields', () => {
    test.describe.configure({ timeout: 120_000 })

    let multiEdge: E2EFormEdge
    let singleEdge: E2EFormEdge
    let fixtureA = ''
    let fixtureB = ''

    test.beforeAll(() => {
        const dir = path.join(tmpdir(), 'olie-e2e-dop-1288')
        mkdirSync(dir, { recursive: true })
        fixtureA = path.join(dir, 'dop1288-a.txt')
        fixtureB = path.join(dir, 'dop1288-b.txt')
        writeFileSync(fixtureA, 'e2e dop-1288 file a\n')
        writeFileSync(fixtureB, 'e2e dop-1288 file b\n')
    })

    test.beforeEach(async ({ page }) => {
        await loginAsE2EUser(page)
        const projectId = await createE2EProject(page, {
            name: `e2e-dop1288-${Date.now()}`,
        })
        await openProjectDetailsTab(page, projectId, 'overview')

        const { edges } = await createE2EDynamicForm(page, {
            title: `e2e-dop1288-form-${Date.now()}`,
            edges: [
                {
                    label: 'E2E Anexos multi',
                    type: 'attachment',
                    index: 0,
                    is_multiple: true,
                },
                {
                    label: 'E2E Anexo único',
                    type: 'attachment',
                    index: 1,
                    is_multiple: false,
                },
            ],
        })

        multiEdge = edges.find(e => e.is_multiple)!
        singleEdge = edges.find(e => !e.is_multiple)!
        expect(multiEdge?.type).toBe('attachment')
        expect(singleEdge?.type).toBe('attachment')
    })

    test.afterEach(async ({ page }) => {
        await purgeE2EProjects(page).catch(() => undefined)
    })

    function attachmentFileInput(editor: Locator) {
        return editor.locator('input[type="file"]').first()
    }

    function uploadButton(editor: Locator) {
        return editor.locator('button:has(input[type="file"])').first()
    }

    test('multi field: picker allows multiple files and uploads both', async ({ page }) => {
        const editor = await openDynamicFormFastAttributeEditor(page, multiEdge, [])

        await requireFeature(page, {
            id: 'DOP-1288',
            probe: async () => {
                const input = attachmentFileInput(editor)
                try {
                    await input.waitFor({ state: 'attached', timeout: 8_000 })
                    return (await input.getAttribute('multiple')) !== null
                } catch {
                    return false
                }
            },
        })

        const input = attachmentFileInput(editor)
        await expect(input).toHaveAttribute('multiple', '')

        const uploadResponses: string[] = []
        page.on('response', response => {
            if (
                response.request().method() === 'POST' &&
                /dynamic-forms-answers-file|upload-file/.test(response.url())
            ) {
                uploadResponses.push(`${response.status()}:${response.url()}`)
            }
        })

        await input.setInputFiles([fixtureA, fixtureB])

        await expect.poll(() => uploadResponses.length, { timeout: 45_000 }).toBeGreaterThanOrEqual(2)
        expect(uploadResponses.every(r => r.startsWith('2'))).toBeTruthy()

        await expect(editor.getByText('dop1288-a.txt').first()).toBeVisible({ timeout: 15_000 })
        await expect(editor.getByText('dop1288-b.txt').first()).toBeVisible({ timeout: 15_000 })

        // Button stays usable after the batch (pending counter back to 0)
        await expect(uploadButton(editor)).toBeVisible({ timeout: 15_000 })
        await expect(uploadButton(editor)).not.toHaveClass(/disabled/)
    })

    test('single field: picker stays single and uploads one file', async ({ page }) => {
        const editor = await openDynamicFormFastAttributeEditor(page, singleEdge, [])
        const input = attachmentFileInput(editor)
        await expect(input).toBeAttached({ timeout: 10_000 })
        await expect(input).not.toHaveAttribute('multiple')

        const uploadResponses: string[] = []
        page.on('response', response => {
            if (
                response.request().method() === 'POST' &&
                /dynamic-forms-answers-file|upload-file/.test(response.url())
            ) {
                uploadResponses.push(response.url())
            }
        })

        // Playwright refuses multi setInputFiles when the attribute is absent —
        // that is the OS-level guarantee for single fields.
        await input.setInputFiles([fixtureA])

        await expect.poll(() => uploadResponses.length, { timeout: 30_000 }).toBe(1)
        await expect(editor.getByText('dop1288-a.txt').first()).toBeVisible({ timeout: 15_000 })
    })

    test('multi field: same file can be chosen again after clear value', async ({ page }) => {
        const editor = await openDynamicFormFastAttributeEditor(page, multiEdge, [])
        const input = attachmentFileInput(editor)
        await requireFeature(page, {
            id: 'DOP-1288',
            probe: async () => (await input.getAttribute('multiple')) !== null,
        })

        await input.setInputFiles([fixtureA])
        await expect(editor.getByText('dop1288-a.txt').first()).toBeVisible({ timeout: 20_000 })
        await expect(uploadButton(editor)).toBeVisible({ timeout: 15_000 })
        await expect(uploadButton(editor)).not.toHaveClass(/disabled/)

        // Clearing input value after pick is what allows re-selecting the same path
        await input.setInputFiles([fixtureA])
        await expect(editor.getByText('dop1288-a.txt')).toHaveCount(2, { timeout: 20_000 })
    })

    test('upload button remains legible in light and dark', async ({ page }) => {
        const editor = await openDynamicFormFastAttributeEditor(page, multiEdge, [])
        const btn = uploadButton(editor)
        await expect(btn).toBeVisible()

        for (const theme of ['light', 'dark'] as const) {
            await setResolvedTheme(page, theme)
            await expect(btn).toBeVisible()
            const color = await btn.evaluate(el => getComputedStyle(el).color)
            const bg = await btn.evaluate(el => getComputedStyle(el).backgroundColor)
            expect(color).toBeTruthy()
            expect(bg).toBeTruthy()
            // Smoke: theme swap did not hide the control
            await expect(fastAttributeEditor(page)).toBeVisible()
        }
    })
})
