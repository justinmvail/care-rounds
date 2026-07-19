/// The historical single-install patient id. Before Care Rounds went
/// multi-client, every clinical row (medication, appointment, journal entry)
/// implicitly belonged to "the one patient". These rows carry no explicit
/// owner, so the model default + the table-column default below stamp them
/// with this id, and the multi-client backfill migration does the same — so
/// legacy data lands on the seeded demo client rather than leaking across a
/// real caseload.
///
/// New multi-client writes set `patientId` explicitly (from the active
/// client). Mirrors `fallbackPatientId` in `care_events_provider.dart`.
const String demoFallbackPatientId = 'demo-patient-mary';
