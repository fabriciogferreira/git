import { type Locator, type Page, expect } from '@playwright/test'
import { requireVisible } from './feature'
import { resolvePageOrigin } from './navigation'

const CREATE_CONTACT = /Criar contato|Create contact|Novo contato|New contact/i
const CONTACT_MODAL_TITLE = /Criar contato|Create contact/i
const CREATE_CUSTOMER = /Adicionar cliente|Add client|Criar cliente|Create customer/i
const CUSTOMER_MODAL_TITLE = /Criar cliente|Create customer|Create client/i
const BILLING_HEADING = /Dados de cobrança|Billing data/i

/** Compact hides DDI below this (@container phone-input max-width: 300px). */
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
    await createBtn.first().click({ force: true })

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
    await createBtn.first().click({ force: true })

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

/**
 * Country Select must expose name + DDI for screen readers and hover when the
 * visual calling code is hidden in compact mode.
 * PrimeVue puts `aria-label` on the inner combobox; `title` is on the Select root.
 */
export async function expectCountrySelectAccessibleLabel(scope: Page | Locator) {
    const country = phoneCountrySelect(scope)
    await expect(country).toBeVisible()

    const combobox = country.locator('[role="combobox"]').first()
    const ariaLabel = await combobox.getAttribute('aria-label')
    const title = await country.getAttribute('title')

    expect(ariaLabel, 'country combobox needs aria-label with name + calling code').toBeTruthy()
    expect(title, 'country Select root needs title with name + calling code').toBeTruthy()
    expect(ariaLabel).toMatch(/\+\d+/)
    expect(title).toMatch(/\+\d+/)
    expect(ariaLabel).toBe(title)
    expect(ariaLabel!.length).toBeGreaterThan(3)
}

/**
 * Force the shared control width so compact (@container) layout can be asserted.
 * Expands ancestors too — a narrow modal column would otherwise clamp the container
 * and keep the DDI hidden even when this node asks for a wide width.
 */
export async function setPhoneInputWidth(root: Locator, px: number | null) {
    await root.evaluate((el, width) => {
        const nodes: HTMLElement[] = []
        let node: HTMLElement | null = el
        for (let i = 0; i < 8 && node; i++) {
            nodes.push(node)
            if (node.classList.contains('modal-dialog') || node.id === 'contact_form_modal' || node.id === 'customer_form_modal') {
                break
            }
            node = node.parentElement
        }

        for (const target of nodes) {
            if (width == null) {
                target.style.width = ''
                target.style.minWidth = ''
                target.style.maxWidth = ''
                continue
            }

            target.style.width = `${width}px`
            target.style.minWidth = `${width}px`
            target.style.maxWidth = 'none'
        }
    }, px)
}

/** Toggle the app theme via the user menu (idempotent toward dark). */
export async function ensureDarkMode(page: Page) {
    const alreadyDark = await page.locator('html.dark-mode').count()
    if (alreadyDark > 0) {
        return
    }

    const userMenu = page.getByRole('button', { name: /Test User|tester/i }).first()
    await requireVisible(page, 'OS-557 user menu', userMenu, 15_000)
    await userMenu.click()

    const themeBtn = page.getByRole('button', { name: /Mudar tema|Change theme|Toggle theme/i })
    await requireVisible(page, 'OS-557 theme toggle', themeBtn, 10_000)
    await themeBtn.click()
    await expect(page.locator('html.dark-mode')).toHaveCount(1, { timeout: 10_000 })
}

/**
 * Solid country DDI must follow Olie theme tokens (`--system-input-solid-color`),
 * same as `.form-control-solid` — dark text in light theme, light text in dark theme.
 * QA: hardcoded/PrimeVue color left DDI nearly invisible on dark solid backgrounds.
 */
export async function expectSolidCallingCodeFollowsTheme(scope: Page | Locator) {
    const country = phoneCountrySelect(scope)
    const code = phoneCallingCode(scope)
    await expect(code).toBeVisible()

    const { textColor, themeColor } = await country.evaluate(el => {
        const codeEl = el.querySelector('.phone-input__calling-code') as HTMLElement | null
        const cs = getComputedStyle(el)
        return {
            textColor: codeEl ? getComputedStyle(codeEl).color : '',
            themeColor: cs.getPropertyValue('--system-input-solid-color').trim(),
        }
    })

    const themeRgb = await country.evaluate((_, token) => {
        const probe = document.createElement('span')
        probe.style.color = token
        document.body.appendChild(probe)
        const rgb = getComputedStyle(probe).color
        probe.remove()
        return rgb
    }, themeColor || 'inherit')

    expect(
        textColor,
        `DDI must use --system-input-solid-color (${themeColor}), not a fixed light-theme color`
    ).toBe(themeRgb)
}
