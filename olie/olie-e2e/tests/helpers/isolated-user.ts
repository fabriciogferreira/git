import { type APIRequestContext, type Browser, type Page, type WorkerInfo, expect } from '@playwright/test'
import { stubRecaptchaForPage, loginWithCredentials } from './auth'

const E2E_RECAPTCHA_TOKEN = 'e2e-playwright-token-xxxxxxxxxxxx'
const API_INTERNAL = process.env.E2E_API_INTERNAL || 'http://olie-api-main:8080'
const MAIL_INTERNAL = process.env.E2E_MAIL_INTERNAL || 'http://olie-mailhog:8025'
const APP_HOST = process.env.E2E_APP_HOST || 'olie.localhost'

export type IsolatedE2EUser = {
    email: string
    password: string
    name: string
    subdomain: string
    frameId: string
    frameName: string
    /** Management base URL for this user's company (work frame). */
    baseURL: string
}

function apiHeaders(extra: Record<string, string> = {}) {
    return {
        Host: 'api.olie.localhost',
        Accept: 'application/json',
        'Content-Type': 'application/json',
        Origin: `http://landing-page.${APP_HOST}`,
        ...extra,
    }
}

async function landingApi(
    request: APIRequestContext,
    path: string,
    options: {
        method?: string
        body?: unknown
        token?: string
    } = {}
) {
    const headers = apiHeaders(
        options.token ? { Authorization: `Bearer ${options.token}` } : {}
    )
    const res = await request.fetch(`${API_INTERNAL}${path}`, {
        method: options.method ?? 'GET',
        headers,
        data: options.body,
        failOnStatusCode: false,
    })
    const text = await res.text()
    let json: Record<string, unknown> | null = null
    try {
        json = JSON.parse(text) as Record<string, unknown>
    } catch {
        /* ignore */
    }
    return { status: res.status(), json, text }
}

function uniqueSlug(workerIndex: number) {
    const stamp = Date.now().toString(36)
    const rand = Math.random().toString(36).slice(2, 6)
    return `e2e${workerIndex}${stamp}${rand}`.replace(/[^a-z0-9]/gi, '').slice(0, 24)
}

type MailHogPart = {
    Body?: string
    Headers?: Record<string, string | string[]>
    MIME?: { Parts?: MailHogPart[] }
}

type MailHogMessage = {
    Content?: { Body?: string; Headers?: Record<string, string | string[]> }
    MIME?: { Parts?: MailHogPart[] }
}

function collectMailBodies(item: MailHogMessage): string[] {
    const bodies: string[] = []
    const walk = (part?: MailHogPart | MailHogMessage['Content']) => {
        if (!part) return
        if (typeof part.Body === 'string' && part.Body) bodies.push(part.Body)
        const mimeParts = (part as MailHogPart).MIME?.Parts
        for (const child of mimeParts ?? []) walk(child)
    }
    walk(item.Content)
    for (const part of item.MIME?.Parts ?? []) walk(part)
    return bodies
}

/** Undo quoted-printable soft wraps + common =XX encodings used in verify links. */
function decodeQuotedPrintable(raw: string): string {
    return raw
        .replace(/=\r?\n/g, '')
        .replace(/=3D/gi, '=')
        .replace(/=25/gi, '%')
}

function extractVerifyLink(decoded: string): string | null {
    const match = decoded.match(
        /https?:\/\/[^\s\]"'<>]+\/email\/verify\/[0-9a-f-]+\/[0-9a-f]+(?:\?[^\s\]"'<>]*)?/i
    )
    if (!match?.[0]) return null
    return match[0]
        .replace(/&amp;/g, '&')
        .replace(/[),.;]+$/g, '')
}

/**
 * Pull the latest verification link for `email` from MailHog (docker network).
 * Bodies are quoted-printable with soft line breaks mid-URL — decode before matching.
 */
async function waitForVerificationLink(
    request: APIRequestContext,
    email: string,
    timeoutMs = 20_000
): Promise<string> {
    const deadline = Date.now() + timeoutMs
    const needle = email.toLowerCase()

    while (Date.now() < deadline) {
        const res = await request.get(`${MAIL_INTERNAL}/api/v2/messages`)
        const data = (await res.json()) as { items?: MailHogMessage[] }

        for (const item of data.items ?? []) {
            const haystack = JSON.stringify(item).toLowerCase()
            if (!haystack.includes(needle)) continue

            for (const body of collectMailBodies(item)) {
                const link = extractVerifyLink(decodeQuotedPrintable(body))
                if (link) return link
            }
        }
        await new Promise(r => setTimeout(r, 500))
    }

    throw new Error(`MailHog: no verification email for ${email}`)
}

/**
 * Register a fresh user, verify email via MailHog, create a work frame, and
 * return credentials + subdomain. Isolated per worker — safe for parallel E2E.
 */
export async function provisionIsolatedE2EUser(
    request: APIRequestContext,
    workerInfo?: Pick<WorkerInfo, 'workerIndex'>
): Promise<IsolatedE2EUser> {
    const workerIndex = workerInfo?.workerIndex ?? 0
    const slug = uniqueSlug(workerIndex)
    const email = `e2e-${slug}@olie.test`
    const password = 'E2e-pass1!'
    const name = `E2E Worker ${workerIndex}`
    const frameName = `E2E Co ${slug}`
    const subdomain = slug

    const register = await landingApi(request, '/api/landing-page/register', {
        method: 'POST',
        body: {
            name,
            email,
            password,
            password_confirmation: password,
            recaptchaToken: E2E_RECAPTCHA_TOKEN,
        },
    })
    if (register.status !== 200 || !register.json?.response) {
        throw new Error(
            `register failed (status=${register.status}): ${register.text.slice(0, 300)}`
        )
    }

    const verifyLink = await waitForVerificationLink(request, email)
    // Signed links may point at APP_URL (api.olie.localhost) or the container host.
    const verifyUrl = verifyLink
        .replace(/^https?:\/\/api\.olie\.localhost(?::\d+)?/i, API_INTERNAL)
        .replace(/^https?:\/\/olie-api-main(?::\d+)?/i, API_INTERNAL)
    const verifyRes = await request.fetch(verifyUrl, {
        method: 'GET',
        headers: { Host: 'api.olie.localhost' },
        maxRedirects: 0,
        failOnStatusCode: false,
    })
    if (verifyRes.status() !== 302 && verifyRes.status() !== 200) {
        throw new Error(
            `email verify failed (status=${verifyRes.status()}) link=${verifyLink.slice(0, 120)}`
        )
    }

    const login = await landingApi(request, '/api/landing-page/login', {
        method: 'POST',
        body: {
            username: email,
            password,
            token: E2E_RECAPTCHA_TOKEN,
        },
    })
    const landingToken = login.json?.token as string | undefined
    if (login.status !== 200 || !landingToken) {
        throw new Error(
            `landing login failed (status=${login.status}): ${login.text.slice(0, 300)}`
        )
    }

    const frame = await landingApi(request, '/api/landing-page/frames', {
        method: 'POST',
        token: landingToken,
        body: {
            type: 'work',
            name: frameName,
            subdomain,
        },
    })
    const framePayload = frame.json?.frame as { id?: string; subdomain?: string } | undefined
    if (frame.status !== 200 || !framePayload?.id) {
        throw new Error(
            `create frame failed (status=${frame.status}): ${frame.text.slice(0, 300)}`
        )
    }

    return {
        email,
        password,
        name,
        subdomain: framePayload.subdomain ?? subdomain,
        frameId: framePayload.id,
        frameName,
        baseURL: `http://${framePayload.subdomain ?? subdomain}.${APP_HOST}`,
    }
}

/**
 * Provision an isolated company user and log into management on their subdomain.
 */
export async function loginAsIsolatedE2EUser(
    page: Page,
    request: APIRequestContext,
    workerInfo?: Pick<WorkerInfo, 'workerIndex'>
): Promise<IsolatedE2EUser> {
    const user = await provisionIsolatedE2EUser(request, workerInfo)

    await stubRecaptchaForPage(page)
    await loginWithCredentials(page, user.email, user.password, user.baseURL)

    return user
}

/**
 * Optional: open a blank page from `browser` already pointed at the isolated baseURL.
 * Useful for parallel specs that need a fresh context per worker.
 */
export async function newIsolatedContext(browser: Browser, user: IsolatedE2EUser) {
    const context = await browser.newContext({ baseURL: user.baseURL })
    const page = await context.newPage()
    await stubRecaptchaForPage(page)
    await loginWithCredentials(page, user.email, user.password, user.baseURL)
    return { context, page }
}

/** Assert we left /auth on the isolated company host. */
export async function expectLoggedIntoFrame(page: Page, subdomain: string) {
    await expect(page).not.toHaveURL(/\/auth/)
    expect(page.url()).toContain(`${subdomain}.${APP_HOST}`)
}
