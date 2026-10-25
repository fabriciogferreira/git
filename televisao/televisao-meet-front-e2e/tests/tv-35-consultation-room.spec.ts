import { test, expect } from '@playwright/test'

const consultationId = '01ARZ3NDEKTSV4RRFFQ69G5FAV'

/**
 * TV-35 — a consultation URL without a token stays on that consultation
 * and does not open the shared /meet/:id guest lobby.
 */
test.describe('TV-35 consultation room', () => {
    test.describe.configure({ timeout: 90_000 })

    test('consultation link without a token does not open the shared guest lobby', async ({
        page,
    }) => {
        await page.goto(`/consultation/${consultationId}`)

        await expect(page.getByText('Link da consulta inválido')).toBeVisible({
            timeout: 30_000,
        })
        await expect(page.getByText(/Nome do Paciente/i)).toHaveCount(0)
        await expect(page.locator('#participant-name')).toHaveCount(0)
        await expect(page.locator('#toggle-theme-button')).toHaveCount(0)
        await expect(page.locator('#open-navigation-menu-button')).toHaveCount(0)
        await expect(page).toHaveURL(new RegExp(`/consultation/${consultationId}$`))
    })
})
