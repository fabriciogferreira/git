import { type Page } from '@playwright/test'

/**
 * Absolute origin to navigate within the company currently under test.
 *
 * Isolated-frame specs log in on a per-worker subdomain, but the Playwright context `baseURL`
 * stays `devframe` — a relative `page.goto('/x')` would silently leave the company. Prefer the
 * origin the page is already on; fall back to the configured base URL only when the page has no
 * usable origin yet (e.g. `about:blank`).
 */
export function resolvePageOrigin(page: Page): string {
    try {
        const origin = new URL(page.url()).origin
        if (origin && origin !== 'null' && !origin.startsWith('about:')) {
            return origin
        }
    } catch {
        /* fall through to the configured default */
    }

    return (process.env.E2E_BASE_URL || 'http://devframe.olie.localhost').replace(/\/$/, '')
}
