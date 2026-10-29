#!/usr/bin/env bash
# Seed consultations for TV-201 join-window E2E (doctor1).
# Prints two ULIDs on stdout: inside_window outside_window
# inside: expected start = now+5min (button must show; meeting-token must succeed).
# outside: expected start = now+20min (button must stay hidden).
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
\$stamp = now()->format('YmdHis');
\$insideStart = now()->addMinutes(5)->startOfSecond();
\$inside = \\App\\Models\\Consultation::factory()->create([
  'doctor_id' => \$doctor->id,
  'clinic_id' => \$clinic->id,
  'patient_id' => \$patient->id,
  'created_by_id' => \$clinic->id,
  'created_by_type' => \\App\\Models\\Clinic::class,
  'expected_started_at' => \$insideStart,
  'expected_ended_at' => \$insideStart->copy()->addMinutes(15),
  'duration_in_minutes' => 15,
  'note' => 'E2E TV-201 inside ' . \$stamp,
]);
\$outsideStart = now()->addMinutes(20)->startOfSecond();
\$outside = \\App\\Models\\Consultation::factory()->create([
  'doctor_id' => \$doctor->id,
  'clinic_id' => \$clinic->id,
  'patient_id' => \$patient->id,
  'created_by_id' => \$clinic->id,
  'created_by_type' => \\App\\Models\\Clinic::class,
  'expected_started_at' => \$outsideStart,
  'expected_ended_at' => \$outsideStart->copy()->addMinutes(15),
  'duration_in_minutes' => 15,
  'note' => 'E2E TV-201 outside ' . \$stamp,
]);
echo \$inside->id . ' ' . \$outside->id;
"
