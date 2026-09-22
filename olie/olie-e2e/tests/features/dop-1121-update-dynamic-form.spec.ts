import { test, expect } from '@playwright/test'
import { loginAsE2EUser } from '../helpers/auth'
import {
    openNewAutomationModal,
    pickFlowComponent,
    requireUpdateDynamicFormAction,
} from '../helpers/automation'

/**
 * DOP-1121 — ação de automação "Preencher formulário dinâmico".
 *
 * On a front without the feature (e.g. develop), requireFeature skips.
 * On feature/DOP-1121-*, the action is selectable and shows location config.
 */
test.describe('DOP-1121 update dynamic form action', () => {
    test.describe.configure({ timeout: 90_000 })

    test('lists and opens Preencher formulário dinâmico action', async ({ page }) => {
        await loginAsE2EUser(page)
        await openNewAutomationModal(page)

        // Actions only appear after a trigger is chosen
        await pickFlowComponent(page, /Projeto movido de etapa|Project moved/i)

        await requireUpdateDynamicFormAction(page)
        await pickFlowComponent(page, /Preencher formulário dinâmico/i)

        await expect(
            page.getByText(/Onde está o formulário\?|Where is the form\?/i)
        ).toBeVisible({ timeout: 15_000 })

        await expect(
            page.getByText(/Formulário do projeto|Project form/i).first()
        ).toBeVisible()
    })
})
