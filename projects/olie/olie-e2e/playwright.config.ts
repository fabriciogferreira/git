import { defineConfig, devices } from '@playwright/test'
import { execSync } from 'node:child_process'
import dotenv from 'dotenv'
import path from 'path'

/**
 * Read environment variables from file.
 * https://github.com/motdotla/dotenv
 */
dotenv.config({ path: path.resolve(__dirname, '.env') })

/**
 * Inside Docker (e.g. front-* or a dedicated e2e container), `*.olie.localhost`
 * resolves to loopback (::1) and Traefik is unreachable. Map those hosts to the
 * Traefik service IP so Chromium hits the real gateway (Host header / baseURL
 * stay as `devframe.olie.localhost`). On the host this no-ops if olie-traefik
 * is not in /etc/hosts.
 */
function traefikHostResolverArg(): string | undefined {
    try {
        const line = execSync('getent hosts olie-traefik', { encoding: 'utf8' }).trim()
        const address = line.split(/\s+/)[0]
        if (!address) return undefined
        return `--host-resolver-rules=MAP *.olie.localhost ${address}, EXCLUDE localhost`
    } catch {
        return undefined
    }
}

const traefikResolver = traefikHostResolverArg()

/**
 * Local E2E against management (Traefik).
 * Override with E2E_BASE_URL if your subdomain differs.
 *
 * Requires the olie stack running (docker-workspace). This package does not
 * start the frontends.
 */
export default defineConfig({
    testDir: './tests',
    /**
     * Specs that call `loginAsIsolatedE2EUser` get a fresh user + work frame per
     * worker and are safe to run in parallel. Shared-seed specs (`loginAsE2EUser`
     * on devframe) should run with E2E_WORKERS=1 to avoid auth/data races.
     *
     *   # isolated / parallel-friendly file
     *   docker compose exec e2e npx playwright test --workers=3 tests/features/step-forms-before-create.spec.ts
     *
     *   # full suite on shared seed
     *   E2E_WORKERS=1 docker compose exec e2e npx playwright test --project=chromium
     */
    fullyParallel: true,
    forbidOnly: !!process.env.CI,
    retries: process.env.CI ? 2 : 0,
    workers: process.env.E2E_WORKERS ? Number(process.env.E2E_WORKERS) : 3,
    timeout: 90_000,
    reporter: 'html',
    use: {
        baseURL: process.env.E2E_BASE_URL ?? 'http://devframe.olie.localhost',
        trace: 'on',
        screenshot: 'only-on-failure',
        actionTimeout: 15_000,
        navigationTimeout: 45_000,
    },
    projects: [
        {
            name: 'chromium',
            use: {
                ...devices['Desktop Chrome'],
                ...(traefikResolver
                    ? { launchOptions: { args: [traefikResolver] } }
                    : {}),
            },
        },
    ],
})
