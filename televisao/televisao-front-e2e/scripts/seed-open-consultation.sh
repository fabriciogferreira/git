#!/usr/bin/env bash
# Seed an in-progress (not ended) consultation for doctor1 — TV-232 locked "Nova receita".
# Prints the consultation ULID on stdout.
set -euo pipefail

CONTAINER="${E2E_API_CONTAINER:-televisao-backend}"
DOCTOR_EMAIL="${E2E_DOCTOR_USER:-doctor1@doctor.test}"

if ! docker exec "$CONTAINER" php -v >/dev/null 2>&1; then
    echo "error: container $CONTAINER not running (start televisao-api compose)" >&2
    exit 1
fi

docker exec "$CONTAINER" php artisan tinker --execute "
\$doctor = \\App\\Models\\Doctor::whereHas('user', fn (\$q) => \$q->where('email', '${DOCTOR_EMAIL}'))->firstOrFail();
\$clinic = \\App\\Models\\Clinic::query()->firstOrFail();
\$patient = \\App\\Models\\Patient::query()->firstOrFail();
\$start = now()->subDays(12)->startOfDay()->addMinutes(40 + random_int(0, 20 * 60 - 1));
\$c = \\App\\Models\\Consultation::factory()->create([
  'doctor_id' => \$doctor->id,
  'clinic_id' => \$clinic->id,
  'patient_id' => \$patient->id,
  'created_by_id' => \$clinic->id,
  'created_by_type' => \\App\\Models\\Clinic::class,
  'expected_started_at' => \$start,
  'expected_ended_at' => \$start->copy()->addMinutes(15),
  'duration_in_minutes' => 15,
  'started_at' => \$start,
  'ended_at' => null,
  'doctor_left_at' => null,
  'checkout_completed_at' => null,
  'note' => 'E2E TV-232 open ' . now()->format('YmdHis'),
]);
echo \$c->id;
"
