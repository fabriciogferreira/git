#!/usr/bin/env bash
# Seed an ended consultation with a SIGNED prescription for TV-190 Autentique link E2E.
# Prints: "<consultation_id> <prescription_id>"
# Does not set signed_document_url (column may be absent until a proper alter migration ships).
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
\$start = now()->subDays(181)->startOfDay()->addMinutes(30 + random_int(0, 20 * 60 - 1));
\$c = \\App\\Models\\Consultation::factory()->ended()->create([
  'doctor_id' => \$doctor->id,
  'clinic_id' => \$clinic->id,
  'patient_id' => \$patient->id,
  'created_by_id' => \$clinic->id,
  'created_by_type' => \\App\\Models\\Clinic::class,
  'expected_started_at' => \$start,
  'expected_ended_at' => \$start->copy()->addMinutes(15),
  'duration_in_minutes' => 15,
  'note' => 'E2E TV-190 ' . now()->format('YmdHis'),
]);
\$prescription = \\App\\Models\\Prescription::factory()->create([
  'consultation_id' => \$c->id,
  'name' => 'Receita E2E TV-190',
  'signed_by_id' => \$doctor->user_id,
  'signed_at' => now(),
]);
\$path = 'prescriptions/' . \$prescription->id . '/signed.pdf';
\\Illuminate\\Support\\Facades\\Storage::disk('local')->put(\$path, '%PDF-1.4 e2e-signed');
\\App\\Models\\PrescriptionSignature::query()->create([
  'prescription_id' => \$prescription->id,
  'user_id' => \$doctor->user_id,
  'status' => \\App\\Enums\\SignatureStatusEnum::SIGNED,
  'provider' => \\App\\Enums\\SignatureProviderEnum::AUTENTIQUE,
  'provider_document_id' => (string) \\Illuminate\\Support\\Str::uuid(),
  'provider_signer_id' => \\Illuminate\\Support\\Str::lower(\\Illuminate\\Support\\Str::random(32)),
  'snapshot_path' => 'prescriptions/' . \$prescription->id . '/snapshot.pdf',
  'snapshot_hash' => hash('sha256', 'e2e-snapshot'),
  'signed_document_path' => \$path,
  'signed_document_hash' => hash('sha256', '%PDF-1.4 e2e-signed'),
  'sent_at' => now()->subMinute(),
  'signed_at' => now(),
  'metadata' => ['sandbox' => true],
]);
echo \$c->id . ' ' . \$prescription->id;
"
