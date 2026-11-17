#!/usr/bin/env bash
# Seed an ended consultation with a PENDING prescription signature for TV-189
# realtime waiting/toast E2E. Prints: "<consultation_id> <prescription_id>"
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
\$start = now()->subDays(182)->startOfDay()->addMinutes(30 + random_int(0, 20 * 60 - 1));
\$c = \\App\\Models\\Consultation::factory()->ended()->create([
  'doctor_id' => \$doctor->id,
  'clinic_id' => \$clinic->id,
  'patient_id' => \$patient->id,
  'created_by_id' => \$clinic->id,
  'created_by_type' => \\App\\Models\\Clinic::class,
  'expected_started_at' => \$start,
  'expected_ended_at' => \$start->copy()->addMinutes(15),
  'duration_in_minutes' => 15,
  'note' => 'E2E TV-189 ' . now()->format('YmdHis'),
]);
\$prescription = \\App\\Models\\Prescription::factory()->create([
  'consultation_id' => \$c->id,
  'name' => 'Receita E2E TV-189',
]);
\\App\\Models\\PrescriptionSignature::factory()->create([
  'prescription_id' => \$prescription->id,
  'user_id' => \$doctor->user_id,
  'status' => \\App\\Enums\\SignatureStatusEnum::PENDING,
  'provider' => \\App\\Enums\\SignatureProviderEnum::AUTENTIQUE,
  'snapshot_path' => 'prescriptions/' . \$prescription->id . '/snapshot.pdf',
  'snapshot_hash' => hash('sha256', 'e2e-tv-189-snapshot'),
]);
echo \$c->id . ' ' . \$prescription->id;
"
