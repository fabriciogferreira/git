#!/usr/bin/env bash
# Reset seeded clinic-admin + doctor1 support chats so TV-16 / TV-41 can assert
# create-on-first-message. Also seeds a second clinic chat with a unique body for
# cross-owner isolation UI checks.
# Prints: "<isolation_marker>" on stdout.
# Problema: support_chats é morph (supportable); clinic.support_chat_id não existe mais.
set -euo pipefail

CONTAINER="${E2E_API_CONTAINER:-televisao-backend}"
CLINIC_ADMIN_EMAIL="${E2E_CLINIC_ADMIN_USER:-clinic-admin@clinic.com}"
DOCTOR_EMAIL="${E2E_DOCTOR_USER:-doctor1@doctor.test}"

if ! docker exec "$CONTAINER" php -v >/dev/null 2>&1; then
    echo "error: container $CONTAINER not running (start televisao-api compose)" >&2
    exit 1
fi

# artisan tinker often exits 0 even on ModelNotFoundException — capture and fail hard.
out="$(
  docker exec "$CONTAINER" php artisan tinker --execute "
\$purgeChat = function (?\\App\\Models\\SupportChat \$chat): void {
  if (\$chat === null) {
    return;
  }
  \$chatId = \$chat->id;
  \\App\\Models\\SupportChatRead::withTrashed()->where('support_chat_id', \$chatId)->forceDelete();
  \\App\\Models\\SupportMessage::withTrashed()->where('support_chat_id', \$chatId)->forceDelete();
  \\App\\Models\\SupportChat::withTrashed()->whereKey(\$chatId)->forceDelete();
};

\$admin = \\App\\Models\\User::query()->where('email', '${CLINIC_ADMIN_EMAIL}')->firstOrFail();
\$clinicId = \$admin->collaborator?->clinic_id;
throw_if(\$clinicId === null, new \\RuntimeException('clinic admin has no clinic'));
\$clinic = \\App\\Models\\Clinic::query()->findOrFail(\$clinicId);
\$purgeChat(\$clinic->supportChat()->withTrashed()->first());

\$doctorUser = \\App\\Models\\User::query()->where('email', '${DOCTOR_EMAIL}')->firstOrFail();
\$doctor = \$doctorUser->doctor;
throw_if(\$doctor === null, new \\RuntimeException('doctor user has no doctor row'));
\$purgeChat(\$doctor->supportChat()->withTrashed()->first());

\$marker = 'E2E_ISOLATION_' . now()->format('YmdHis') . '_' . random_int(1000, 9999);
\$otherClinic = \\App\\Models\\Clinic::factory()->create([
  'name' => 'E2E Isolation Clinic ' . now()->format('His'),
]);
\\App\\Models\\SupportChat::factory()
  ->forClinic(\$otherClinic)
  ->withInitialMessage(
    \\App\\Models\\User::query()->find(\$otherClinic->owner_id) ?? \$admin,
    \$marker,
  )
  ->create();

echo \$marker;
" 2>&1
)" || true

if [[ "$out" == *"Exception"* ]] || [[ "$out" == *"Error"* ]]; then
  echo "error: support-chat seed failed for ${CLINIC_ADMIN_EMAIL} / ${DOCTOR_EMAIL}" >&2
  echo "$out" >&2
  echo "hint: seed the API DB (ClinicSeeder / UserSeeder) so those users exist" >&2
  exit 1
fi

marker="$(printf '%s\n' "$out" | grep -oE 'E2E_ISOLATION_[A-Za-z0-9_]+' | tail -n1 || true)"
if [[ -z "$marker" ]]; then
  echo "error: support-chat seed produced no isolation marker" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$marker"
