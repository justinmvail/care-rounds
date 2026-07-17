import 'package:carerounds/db/database.dart';
import 'package:carerounds/models/care_shift.dart';
import 'package:carerounds/providers/care_shifts_provider.dart';
import 'package:carerounds/providers/storage_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

CareShift _shift({
  required String id,
  required String caregiverId,
  required String patientId,
  required DateTime start,
}) =>
    CareShift(
      id: id,
      caregiverId: caregiverId,
      start: start,
      end: start.add(const Duration(hours: 2)),
      patientId: patientId,
    );

void main() {
  group('listShiftsForCaregiver (Care Rounds — My Rounds)', () {
    late CareRoundsDatabase db;
    late CareShiftsRepository repo;

    setUp(() {
      db = CareRoundsDatabase(NativeDatabase.memory());
      repo = CareShiftsRepository(db);
    });
    tearDown(() async => db.close());

    test("returns a caregiver's shifts across ALL clients, earliest first",
        () async {
      // Two clients (A, B), two caregivers (me, other).
      await repo.upsertShift(_shift(
          id: 's1',
          caregiverId: 'me',
          patientId: 'clientB',
          start: DateTime.utc(2026, 6, 1, 14)));
      await repo.upsertShift(_shift(
          id: 's2',
          caregiverId: 'me',
          patientId: 'clientA',
          start: DateTime.utc(2026, 6, 1, 8)));
      await repo.upsertShift(_shift(
          id: 's3',
          caregiverId: 'other',
          patientId: 'clientA',
          start: DateTime.utc(2026, 6, 1, 9)));

      final List<CareShift> mine = await repo.listShiftsForCaregiver('me');

      // Only my shifts, spanning both clients, sorted by start time.
      expect(mine.map((CareShift s) => s.id).toList(), <String>['s2', 's1']);
      expect(mine.map((CareShift s) => s.patientId).toSet(),
          <String>{'clientA', 'clientB'});
    });

    test('is empty for a caregiver with no shifts', () async {
      await repo.upsertShift(_shift(
          id: 's1',
          caregiverId: 'someone',
          patientId: 'clientA',
          start: DateTime.utc(2026, 6, 1, 8)));
      expect(await repo.listShiftsForCaregiver('nobody'), isEmpty);
    });
  });

  group('self-caregiver pointer (Care Rounds)', () {
    late CareRoundsDatabase db;
    late DriftStorageProvider storage;

    setUp(() {
      db = CareRoundsDatabase(NativeDatabase.memory());
      storage = DriftStorageProvider(db);
    });
    tearDown(() async => db.close());

    test('defaults to null and round-trips through app_settings', () async {
      expect(await storage.getSelfCaregiverId(), isNull);
      await storage.setSelfCaregiverId('me');
      expect(await storage.getSelfCaregiverId(), 'me');
    });

    test('does not collide with the active-patient pointer', () async {
      await storage.setActivePatientId('patient-x');
      await storage.setSelfCaregiverId('caregiver-y');
      expect(await storage.getActivePatientId(), 'patient-x');
      expect(await storage.getSelfCaregiverId(), 'caregiver-y');
    });
  });
}
