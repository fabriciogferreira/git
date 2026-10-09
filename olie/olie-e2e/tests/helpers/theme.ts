import { type Locator, type Page, expect } from '@playwright/test'

function relativeLuminance(rgb: { r: number; g: number; b: number }): number {
    const channel = (c: number) => {
        const s = c / 255
        return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4
    }
    return 0.2126 * channel(rgb.r) + 0.7152 * channel(rgb.g) + 0.0722 * channel(rgb.b)
}

/** Resolve any CSS color (rgb/lab/oklch) to sRGB via canvas. */
async function resolveRgb(
    page: Page,
    color: string
): Promise<{ r: number; g: number; b: number }> {
    return page.evaluate(cssColor => {
        const canvas = document.createElement('canvas')
        canvas.width = 1
        canvas.height = 1
        const ctx = canvas.getContext('2d')
        if (!ctx) {
            throw new Error('canvas unsupported')
        }
        ctx.fillStyle = '#000000'
        ctx.fillStyle = cssColor
        ctx.fillRect(0, 0, 1, 1)
        const [r, g, b] = ctx.getImageData(0, 0, 1, 1).data
        return { r, g, b }
    }, color)
}

async function sampleColors(locator: Locator): Promise<{ fg: string; bg: string }> {
    return locator.evaluate(el => {
        const fg = getComputedStyle(el).color
        let node: HTMLElement | null = el as HTMLElement
        let bg = 'rgba(0, 0, 0, 0)'
        while (node) {
            const candidate = getComputedStyle(node).backgroundColor
            if (candidate && candidate !== 'rgba(0, 0, 0, 0)' && candidate !== 'transparent') {
                bg = candidate
                break
            }
            node = node.parentElement
        }
        if (bg === 'rgba(0, 0, 0, 0)' || bg === 'transparent') {
            bg = getComputedStyle(document.body).backgroundColor
        }
        return { fg, bg }
    })
}

/** WCAG contrast ratio of locator text vs nearest opaque background. */
export async function measureContrastRatio(locator: Locator): Promise<{
    ratio: number
    fg: string
    bg: string
}> {
    await expect(locator).toBeVisible()
    const page = locator.page()
    const { fg, bg } = await sampleColors(locator)
    const fgRgb = await resolveRgb(page, fg)
    const bgRgb = await resolveRgb(page, bg)
    const l1 = relativeLuminance(fgRgb)
    const l2 = relativeLuminance(bgRgb)
    const ratio = (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05)
    return { ratio, fg, bg }
}

/** Assert text vs ancestor background meets WCAG AA for normal text (4.5:1). */
export async function expectReadableContrast(
    locator: Locator,
    label: string,
    minRatio = 4.5
) {
    const { ratio, fg, bg } = await measureContrastRatio(locator)
    expect(
        ratio,
        `${label}: contrast ${ratio.toFixed(2)}:1 (fg=${fg}, bg=${bg}) must be >= ${minRatio}`
    ).toBeGreaterThanOrEqual(minRatio)
}

/**
 * Force light/dark in management (Metronic + PrimeVue).
 * Mirrors `setSystemTheme` from `@olie/ui` + the Vuex theme mutation.
 */
export async function setResolvedTheme(page: Page, theme: 'light' | 'dark') {
    await page.evaluate(desired => {
        localStorage.setItem('theme', desired)
        document.documentElement.setAttribute('data-theme', desired)
        document.documentElement.classList.toggle('dark-mode', desired === 'dark')
        document.documentElement.style.colorScheme = desired
    }, theme)

    await expect
        .poll(async () =>
            page.evaluate(
                () =>
                    document.documentElement.getAttribute('data-theme') === 'dark' ||
                    document.documentElement.classList.contains('dark-mode')
            )
        )
        .toBe(theme === 'dark')
}
