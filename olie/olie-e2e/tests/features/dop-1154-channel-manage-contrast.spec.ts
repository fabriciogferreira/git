import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import {
    channelManageOperationSelect,
    openChannelManageAction,
    pickSelectOptionByText,
} from '../helpers/automation'

/**
 * DOP-1154 — contrast of the new automation form hints (light + dark).
 *
 * Measures `text-muted` helper copy against its background via WCAG relative
 * luminance. Reports ratios; does not fail the suite on AA (same pattern as
 * TV-205 theme contrast checks).
 */

type ContrastSample = {
    theme: string
    label: string
    fg: string
    bg: string
    ratio: number
}

function parseRgb(input: string): [number, number, number] | null {
    const m = input.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/i)
    if (!m) return null
    return [Number(m[1]), Number(m[2]), Number(m[3])]
}

function relativeLuminance([r, g, b]: [number, number, number]) {
    const toLin = (c: number) => {
        const s = c / 255
        return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4
    }
    const R = toLin(r)
    const G = toLin(g)
    const B = toLin(b)
    return 0.2126 * R + 0.7152 * G + 0.0722 * B
}

function contrastRatio(fg: string, bg: string): number | null {
    const a = parseRgb(fg)
    const b = parseRgb(bg)
    if (!a || !b) return null
    const L1 = relativeLuminance(a)
    const L2 = relativeLuminance(b)
    const lighter = Math.max(L1, L2)
    const darker = Math.min(L1, L2)
    return (lighter + 0.05) / (darker + 0.05)
}

async function effectiveBackground(page: import('@playwright/test').Page, el: import('@playwright/test').Locator) {
    return el.evaluate(node => {
        let current: Element | null = node
        while (current) {
            const style = getComputedStyle(current)
            const bg = style.backgroundColor
            if (bg && bg !== 'rgba(0, 0, 0, 0)' && bg !== 'transparent') {
                return bg
            }
            current = current.parentElement
        }
        return getComputedStyle(document.body).backgroundColor
    })
}

async function setTheme(page: import('@playwright/test').Page, theme: 'light' | 'dark') {
    await page.evaluate(next => {
        localStorage.setItem('theme', next)
        document.documentElement.setAttribute('data-theme', next)
        document.documentElement.classList.toggle('dark-mode', next === 'dark')
    }, theme)
}

async function sampleMutedHints(page: import('@playwright/test').Page, theme: string): Promise<ContrastSample[]> {
    const muted = page.locator('.col-12 small.text-muted').filter({ hasText: /\S/ })
    const count = await muted.count()
    const samples: ContrastSample[] = []

    for (let i = 0; i < Math.min(count, 4); i++) {
        const el = muted.nth(i)
        if (!(await el.isVisible().catch(() => false))) continue
        const fg = await el.evaluate(node => getComputedStyle(node).color)
        const bg = await effectiveBackground(page, el)
        const ratio = contrastRatio(fg, bg)
        if (ratio == null) continue
        const label = ((await el.innerText()) || '').trim().slice(0, 80)
        samples.push({ theme, label, fg, bg, ratio: Number(ratio.toFixed(2)) })
    }

    return samples
}

test.describe('DOP-1154 channel manage contrast', () => {
    test.describe.configure({ timeout: 120_000 })

    test('measures text-muted hints in light and dark themes', async ({ page }) => {
        await loginAsE2EUser(page)
        await openChannelManageAction(page)

        await pickSelectOptionByText(
            page,
            channelManageOperationSelect(page),
            /^Criar canal$|^Create channel$/i
        )
        await expect(page.getByText(/Tipo de canal|Channel type/i).first()).toBeVisible({
            timeout: 10_000,
        })

        const all: ContrastSample[] = []

        for (const theme of ['light', 'dark'] as const) {
            await setTheme(page, theme)
            await expect(page.locator('html')).toHaveAttribute('data-theme', theme)
            const samples = await sampleMutedHints(page, theme)
            expect(samples.length, `expected muted hints in ${theme}`).toBeGreaterThan(0)
            all.push(...samples)
        }

        // Always print — useful in CI logs even when ratios are below AA.
        console.log('DOP-1154 contrast samples:', JSON.stringify(all, null, 2))

        for (const sample of all) {
            // Sanity: ratio must be computable and > 1 (not same-on-same).
            expect(sample.ratio).toBeGreaterThan(1)
        }
    })
})
