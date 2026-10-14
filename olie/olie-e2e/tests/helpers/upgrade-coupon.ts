import { execFileSync } from 'node:child_process'
import { type Page, expect } from '@playwright/test'
import { requireVisible } from './feature'
import { resolvePageOrigin } from './navigation'

/** Coupon code attached to the shared `devframe` subscription for DOP-1218 e2e. */
export const DOP1218_COUPON_CODE = 'DOP1218E2E'

/**
 * Idempotent DB fixture for the shared `devframe` seed: active subscription with
 * a permanent percentage coupon that applies to seat upgrades.
 *
 * Runs `docker exec olie-api-main …` when Docker is available (host/`./run.sh`).
 * Inside the e2e container that call is skipped — seed once from the host before
 * the suite if the modal assertions would otherwise skip.
 */
export function ensureDevframeUpgradeCouponFixture() {
    const php = `
use App\\Enums\\Billing\\CouponApplicableToEnum;
use App\\Enums\\Billing\\CouponDiscountTypeEnum;
use App\\Enums\\Billing\\CouponSubscriptionDurationTypeEnum;
use App\\Enums\\Billing\\SubscriptionStatusEnum;
use App\\Models\\Billing\\Coupon;
use App\\Models\\Billing\\Subscription;
use App\\Models\\Billing\\SubscriptionItem;
use App\\Models\\Frame;
use App\\Models\\RoleType;
use Illuminate\\Support\\Carbon;

$frame = Frame::where('subdomain', 'devframe')->firstOrFail();
$role = RoleType::query()->firstOrFail();

$coupon = Coupon::query()->firstOrCreate(
    ['code' => '${DOP1218_COUPON_CODE}'],
    [
        'applicable_to' => CouponApplicableToEnum::SUBSCRIPTION,
        'discount_type' => CouponDiscountTypeEnum::PERCENTAGE,
        'discount_value' => 50,
        'subscription_duration_type' => CouponSubscriptionDurationTypeEnum::PERMANENT,
        'is_active' => true,
        'applies_to_upgrades' => true,
        'created_by' => 1,
    ]
);
$coupon->forceFill([
    'applies_to_upgrades' => true,
    'is_active' => true,
    'discount_value' => 50,
])->save();

$sub = Subscription::where('frame_id', $frame->id)->first();
if (! $sub) {
    $sub = Subscription::factory()->active()->create(['frame_id' => $frame->id]);
}
$sub->forceFill([
    'status' => SubscriptionStatusEnum::ACTIVE,
    'coupon_id' => $coupon->id,
    'legacy_flat_price' => null,
    'interval' => 'month',
    'interval_count' => 1,
    'cycle_start_at' => Carbon::now()->subDays(10),
    'cycle_end_at' => Carbon::now()->addDays(20),
    'cycle' => 1,
    'canceled_at' => null,
])->save();

if (! $sub->subscription_items()->exists()) {
    SubscriptionItem::factory()->create([
        'subscription_id' => $sub->id,
        'role_type_id' => $role->id,
        'quantity' => 3,
    ]);
} else {
    $sub->subscription_items()->update(['role_type_id' => $role->id, 'quantity' => 3]);
}

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

export function upgradeModalRoot(page: Page) {
    return page.locator('.upgrade-modal-wrap')
}

export function couponAppliedLine(page: Page) {
    return upgradeModalRoot(page).locator('.upgrade-summary-line').filter({
        hasText: new RegExp(`Cupom\\s+${DOP1218_COUPON_CODE}\\s+aplicado|Coupon\\s+${DOP1218_COUPON_CODE}\\s+applied`, 'i'),
    })
}

export function couponCodeField(page: Page) {
    return upgradeModalRoot(page).getByText(/Cupom de desconto|Discount coupon|Coupon code/i)
}

/** Open Plan → Aumentar vagas on the shared seed frame. */
export async function openAddSeatsModal(page: Page) {
    await page.goto(`${resolvePageOrigin(page)}/frame/billing/subscriptions`)

    const increase = page.getByRole('button', { name: /Aumentar vagas|Increase seats|Add seats/i }).first()
    await requireVisible(page, 'DOP-1218 subscription upgrade CTA', increase, 25_000)
    await increase.click()

    const modal = upgradeModalRoot(page)
    await requireVisible(page, 'DOP-1218 add-seats modal', modal, 15_000)
    await expect(modal.getByText(/Adicionar vagas|Add seats/i).first()).toBeVisible({
        timeout: 10_000,
    })
    return modal
}

/** Bump the first seat row so preview runs with a positive delta. */
export async function bumpFirstSeatQuantity(page: Page) {
    const modal = upgradeModalRoot(page)
    const plus = modal.locator('.qty-stepper .qty-btn.is-primary').first()
    await expect(plus).toBeVisible({ timeout: 10_000 })
    await plus.click()
}
