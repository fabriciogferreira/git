import { defineConfig, devices } from '@playwright/test'
import dotenv from 'dotenv'
import path from 'path'

dotenv.config({ path: path.resolve(__dirname, '.env') })

/**
 * Local E2E against televisao-meet-front (Vite on host :3001 → container :3000).
 * Override with E2E_BASE_URL if your port differs.
 *
 * Requires the Televisão stack running (`televisao-api` docker compose).
 * This package does not start the frontends.
 *
 * Playwright runs with Docker `network_mode: host` so browser `localhost`
 * matches VITE_* URLs pointed at published ports.
 */
export default defineConfig({
    testDir: './tests',
    // Nested under bind-mounted dirs so Playwright can rmdir outputs (cannot rmdir the mount itself).
    outputDir: 'test-results/output',
    fullyParallel: true,
    forbidOnly: !!process.env.CI,
    retries: process.env.CI ? 2 : 0,
    workers: process.env.E2E_WORKERS ? Number(process.env.E2E_WORKERS) : 3,
    timeout: 90_000,
    reporter: [['html', { outputFolder: 'playwright-report/html', open: 'never' }]],
    use: {
        baseURL: process.env.E2E_BASE_URL ?? 'http://localhost:3001',
        trace: 'on',
        screenshot: 'only-on-failure',
        actionTimeout: 15_000,
        navigationTimeout: 45_000,
        // Meet page requests camera/mic; deny so UI stays on the join form.
        permissions: [],
    },
    projects: [
        {
            name: 'chromium',
            use: { ...devices['Desktop Chrome'] },
        },
    ],
})
