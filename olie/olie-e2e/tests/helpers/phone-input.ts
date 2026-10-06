import { type Locator, type Page, expect } from '@playwright/test'
import { requireVisible } from './feature'
import { resolvePageOrigin } from './navigation'

const CREATE_CONTACT = /Criar contato|Create contact|Novo contato|New contact/i
const CONTACT_MODAL_TITLE = /Criar contato|Create contact/i
const CREATE_CUSTOMER = /Adicionar cliente|Add client|Criar cliente|Create customer/i
const CUSTOMER_MODAL_TITLE = /Criar cliente|Create customer|Create client/i
const BILLING_HEADING = /Dados de cobrança|Billing data/i

/** Compact hides DDI below this (PhoneInput COMPACT_MAX_WIDTH_PX). */
export const PHONE_INPUT_COMPACT_MAX_PX = 300

/** Shared PhoneInput country Select (PrimeVue). */
export function phoneCountrySelect(scope: Page | Locator) {
    return scope.locator('.phone-input__country').first()
}

export function phoneNationalInput(scope: Page | Locator) {
    return scope.locator('input[type="tel"]').first()
}

export function phoneInputRoot(scope: Page | Locator) {
    return scope.locator('.phone-input').first()
}

export function phoneCallingCode(scope: Page | Locator) {
    return phoneInputRoot(scope).locator('.phone-input__calling-code')
}

export function contactFormModal(page: Page) {
    return page.locator('#contact_form_modal')
}

export function customerFormModal(page: Page) {
    return page.locator('#customer_form_modal')
}

/**
 * Isolated / empty frames land on ContactsIntro; frames with contacts show the list
 * "Novo contato" button. Both dispatch the same Bootstrap `#contact_form_modal`.
 */
export async function openContactCreatePhoneInput(page: Page) {
    await page.goto(`${resolvePageOrigin(page)}/contacts/index`)

    const createBtn = page.getByRole('button', { name: CREATE_CONTACT })
    await requireVisible(page, 'OS-557 contact create', createBtn, 20_000)
    await createBtn.first().click()

    const modal = contactFormModal(page)
    await requireVisible(page, 'OS-557 contact form modal', modal, 15_000)
    await expect(modal.getByRole('heading', { name: CONTACT_MODAL_TITLE })).toBeVisible({
        timeout: 10_000,
    })

    await requireVisible(page, 'OS-557 PhoneInput', phoneCountrySelect(modal), 10_000)

    return modal
}

export async function openCustomerCreatePhoneInput(page: Page) {
    await page.goto(`${resolvePageOrigin(page)}/customers/index`)

    const createBtn = page.getByRole('button', { name: CREATE_CUSTOMER })
    await requireVisible(page, 'OS-557 customer create', createBtn, 20_000)
    await createBtn.first().click()

    const modal = customerFormModal(page)
    await requireVisible(page, 'OS-557 customer form modal', modal, 15_000)
    await expect(modal.getByRole('heading', { name: CUSTOMER_MODAL_TITLE })).toBeVisible({
        timeout: 10_000,
    })

    await requireVisible(page, 'OS-557 PhoneInput', phoneCountrySelect(modal), 10_000)

    return modal
}

/** Ticket screenshot surface — skip when the e2e user cannot open billing. */
export async function openBillingDataPhoneInput(page: Page) {
    await page.goto(`${resolvePageOrigin(page)}/frame/billing/billing-data`)

    const heading = page.getByRole('heading', { name: BILLING_HEADING }).first()
    await requireVisible(page, 'OS-557 billing data', heading, 20_000)
    await requireVisible(page, 'OS-557 billing PhoneInput', phoneInputRoot(page), 10_000)

    return phoneInputRoot(page)
}

export async function expectPhoneCountryBorder(country: Locator) {
    const width = await country.evaluate(el => getComputedStyle(el).borderTopWidth)
    expect(width, 'country Select should show a 1px form-control-like border').toBe('1px')
}

export async function expectCallingCodeShown(scope: Page | Locator, shown: boolean) {
    const code = phoneCallingCode(scope)
    if (shown) {
        await expect(code).toBeVisible()
        await expect(code).toContainText('+')
    } else {
        await expect(code).toBeHidden()
    }
}

/** Force the shared control width so compact (container query + ResizeObserver) can be asserted. */
export async function setPhoneInputWidth(root: Locator, px: number | null) {
    await root.evaluate((el, width) => {
        if (width == null) {
            el.style.width = ''
            el.style.maxWidth = ''
            return
        }

        el.style.width = `${width}px`
        el.style.maxWidth = `${width}px`
    }, px)
}
