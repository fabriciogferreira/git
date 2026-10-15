import { execFileSync } from 'node:child_process'
import { type Page, expect } from '@playwright/test'
import { requireVisible } from './feature'
import { resolvePageOrigin } from './navigation'

/** Global ERP coupon used by DOP-1179 e2e (100% first cycle only). */
export const DOP1179_COUPON_CODE = 'DOP1179E2E'

/**
 * Idempotent coupon + billing-data fixture for an isolated work frame.
 * Host/`./run.sh` reaches `olie-api-main`; inside the e2e container the docker
 * call is skipped — seed from the host before the suite if needed.
 */
export function ensureZeroFirstPaymentCouponFixture(subdomain: string) {
    const php = `
use App\\Enums\\Billing\\CouponApplicableToEnum;
use App\\Enums\\Billing\\CouponDiscountTypeEnum;
use App\\Enums\\Billing\\CouponSubscriptionDurationTypeEnum;
use App\\Enums\\Billing\\InvoiceStatusEnum;
use App\\Enums\\Billing\\SubscriptionStatusEnum;
use App\\Models\\Billing\\Coupon;
use App\\Models\\Billing\\CouponRedemption;
use App\\Models\\Billing\\FrameBillingData;
use App\\Models\\Billing\\Invoice;
use App\\Models\\Billing\\Subscription;
use App\\Models\\Frame;

$frame = Frame::where('subdomain', '${subdomain}')->firstOrFail();

$coupon = Coupon::query()->firstOrCreate(
    ['code' => '${DOP1179_COUPON_CODE}'],
    [
        'applicable_to' => CouponApplicableToEnum::SUBSCRIPTION,
        'discount_type' => CouponDiscountTypeEnum::PERCENTAGE,
        'discount_value' => 100,
        'subscription_duration_type' => CouponSubscriptionDurationTypeEnum::N_CYCLES,
        'subscription_duration_cycles' => 1,
        'is_active' => true,
        'max_redemptions' => null,
        'created_by' => 1,
    ]
);
$coupon->forceFill([
    'applicable_to' => CouponApplicableToEnum::SUBSCRIPTION,
    'discount_type' => CouponDiscountTypeEnum::PERCENTAGE,
    'discount_value' => 100,
    'subscription_duration_type' => CouponSubscriptionDurationTypeEnum::N_CYCLES,
    'subscription_duration_cycles' => 1,
    'is_active' => true,
    'max_redemptions' => null,
])->save();

// Prior e2e runs may have redeemed this code on the shared frame.
CouponRedemption::query()->where('coupon_id', $coupon->id)->where('frame_id', $frame->id)->delete();

if (! $frame->frame_billing_data_id) {
    $billing = FrameBillingData::factory()->create([
        'document_type' => 'cnpj',
        'document_number' => '00.000.000/0000-00',
        'country' => 'BR',
        'state' => 'SP',
        'city' => 'São Paulo',
        'zip' => '01310-100',
        'address' => 'Av. Paulista, 1000',
        'phone' => '+5511987654321',
        'email' => 'e2e-billing@olie.test',
    ]);
    $frame->forceFill(['frame_billing_data_id' => $billing->id])->save();
}

$sub = Subscription::where('frame_id', $frame->id)->first();
if (! $sub) {
    $sub = Subscription::factory()->trial()->create([
        'frame_id' => $frame->id,
        'cycle' => 0,
        'cycle_start_at' => null,
        'cycle_end_at' => null,
    ]);
}
$sub->forceFill([
    'status' => SubscriptionStatusEnum::TRIAL,
    'coupon_id' => null,
    'canceled_at' => null,
])->save();

// A pending invoice makes the wizard jump straight to payment and skip the
// seat/coupon step — cancel leftovers so DOP-1179 can apply the coupon there.
Invoice::query()
    ->where('frame_id', $frame->id)
    ->whereIn('status', [
        InvoiceStatusEnum::PENDING->value,
        InvoiceStatusEnum::WAITING_PAYMENT->value,
        InvoiceStatusEnum::PROCESSING->value,
        InvoiceStatusEnum::FAILED->value,
    ])
    ->update([
        'status' => InvoiceStatusEnum::CANCELED->value,
        'canceled_at' => now(),
    ]);

echo 'ok';
`.replace(/\n/g, ' ')

    try {
        execFileSync(
            'docker',
            ['exec', 'olie-api-main', 'php', 'artisan', 'tinker', '--execute', php],
            { stdio: ['ignore', 'pipe', 'pipe'], timeout: 60_000 }
        )
    } catch {
        // e2e container has no docker CLI — fixture must already be on the API DB.
    }
}

export function subscriptionWizardRoot(page: Page) {
    return page.locator('.wizard')
}

export function zeroTotalNoCardBanner(page: Page) {
    return subscriptionWizardRoot(page).getByText(
        /O cupom cobre a primeira cobrança|The coupon covers the first charge/i
    )
}

/** Open Plan → Contratar agora on the trial subscription index. */
export async function openHireSubscriptionWizard(page: Page) {
    await page.goto(`${resolvePageOrigin(page)}/frame/billing/subscriptions`)

    // Prefer the index hero CTA (btn-lg) over banner / empty-state duplicates.
    const hire = page
        .locator('button.btn-primary.btn-lg')
        .filter({ hasText: /Contratar agora|Hire now|Subscribe now/i })
        .first()
    await requireVisible(page, 'DOP-1179 hire subscription CTA', hire, 25_000)
    await hire.click()

    const wizard = page.locator('.p-dialog .wizard, .wizard-dialog-root .wizard').first()
    await requireVisible(page, 'DOP-1179 subscription wizard', wizard, 20_000)
    return wizard
}

export async function applyCouponInSeatStep(page: Page, code: string) {
    const wizard = subscriptionWizardRoot(page)
    const couponLabel = wizard.getByText(/Cupom de desconto|Discount coupon/i).first()
    await expect(couponLabel).toBeVisible({ timeout: 15_000 })
    await couponLabel.scrollIntoViewIfNeeded()

    // Placeholder is "Insira o código" / "Enter the code" — not the word coupon.
    const couponInput = wizard.getByPlaceholder(/Insira o código|Enter the code|código|code/i)
    await expect(couponInput).toBeVisible({ timeout: 10_000 })
    await couponInput.fill(code)

    const apply = wizard.getByRole('button', { name: /Aplicar|Apply/i })
    await expect(apply).toBeEnabled({ timeout: 5_000 })
    await apply.click()

    await expect(wizard.getByText(new RegExp(code, 'i')).first()).toBeVisible({
        timeout: 15_000,
    })
    // Preview should show R$ 0,00 total once the 100% coupon sticks.
    await expect(wizard.getByText(/R\$\s*0,00|\$\s*0\.00/i).first()).toBeVisible({
        timeout: 20_000,
    })
}

export async function advanceWizardPrimary(page: Page) {
    const wizard = subscriptionWizardRoot(page)
    const primary = wizard
        .locator('.wizard-footer')
        .getByRole('button', { name: /Continuar|Continue|Próximo|Next|Finalizar|Finish|Pay/i })
        .last()
    await expect(primary).toBeEnabled({ timeout: 15_000 })
    await primary.click()
}
