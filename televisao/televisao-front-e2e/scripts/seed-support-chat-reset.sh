#!/usr/bin/env bash
# Reset the seeded clinic-admin support chat so TV-16 can assert create-on-first-message.
# Also seeds a second clinic chat with a unique body for cross-clinic isolation UI checks.
# Prints: "<isolation_marker>" on stdout.
set -euo pipefail

CONTAINER="${E2E_API_CONTAINER:-televisao-backend}"
CLINIC_ADMIN_EMAIL="${E2E_CLINIC_ADMIN_USER:-clinic-admin@clinic.com}"

if ! docker exec "$CONTAINER" php -v >/dev/null 2>&1; then
    echo "error: container $CONTAINER not running (start televisao-api compose)" >&2
    exit 1
fi

# artisan tinker often exits 0 even on ModelNotFoundException — capture and fail hard.
out="$(
  docker exec "$CONTAINER" php artisan tinker --execute "
\$admin = \\App\\Models\\User::query()->where('email', '${CLINIC_ADMIN_EMAIL}')->firstOrFail();
\$clinicId = \$admin->collaborator?->clinic_id;
throw_if(\$clinicId === null, new \\RuntimeException('clinic admin has no clinic'));
\$clinic = \\App\\Models\\Clinic::query()->findOrFail(\$clinicId);

if (\$clinic->support_chat_id !== null) {
  \$chatId = \$clinic->support_chat_id;
  \$clinic->forceFill(['support_chat_id' => null])->save();
  \\App\\Models\\SupportChatRead::withTrashed()->where('support_chat_id', \$chatId)->forceDelete();
  \\App\\Models\\SupportMessage::withTrashed()->where('support_chat_id', \$chatId)->forceDelete();
  \\App\\Models\\SupportChat::withTrashed()->whereKey(\$chatId)->forceDelete();
}

\$marker = 'E2E_ISOLATION_' . now()->format('YmdHis') . '_' . random_int(1000, 9999);
\$otherClinic = \\App\\Models\\Clinic::factory()->create([
  'name' => 'E2E Isolation Clinic ' . now()->format('His'),
]);
\$otherChat = \\App\\Models\\SupportChat::factory()->create();
\$otherClinic->forceFill(['support_chat_id' => \$otherChat->id])->save();
\\App\\Models\\SupportMessage::factory()->create([
  'support_chat_id' => \$otherChat->id,
  'sender_id' => \$otherClinic->owner_id,
  'body' => \$marker,
]);

echo \$marker;
" 2>&1
)" || true

if [[ "$out" == *"Exception"* ]] || [[ "$out" == *"Error"* ]]; then
  echo "error: support-chat seed failed for ${CLINIC_ADMIN_EMAIL}" >&2
  echo "$out" >&2
  echo "hint: seed the API DB (ClinicSeeder) so that user exists" >&2
  exit 1
fi

marker="$(printf '%s\n' "$out" | grep -oE 'E2E_ISOLATION_[A-Za-z0-9_]+' | tail -n1 || true)"
if [[ -z "$marker" ]]; then
  echo "error: support-chat seed produced no isolation marker" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$marker"