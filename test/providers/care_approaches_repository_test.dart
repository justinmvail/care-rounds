import 'package:carerounds/db/database.dart';
import 'package:carerounds/models/care_approach.dart';
import 'package:carerounds/providers/care_approaches_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

CareApproach _a(
  String id,
  CareSituation s,
  String tried,
  ApproachOutcome o, {
  DateTime? at,
  String patientId = 'p1',
}) =>
    CareApproach(
      id: id,
      patientId: patientId,
      situation: s,
      tried: tried,
      outcome: o,
      at: at ?? DateTime(2026, 7, 20),
    );

void main() {
  late CareRoundsDatabase db;
  late CareApproachesRepository repo;

  setUp(() {
    db = CareRoundsDatabase(NativeDatabase.memory());
    repo = CareApproachesRepository(db);
  });
  tearDown(() => db.close());

  test('records and reads back an approach', () async {
    await repo.record(_a('a1', CareSituation.resistedPersonalCare,
        'warmed the towels', ApproachOutcome.worked));
    final List<CareApproach> out = await repo.forPatient('p1');
    expect(out, hasLength(1));
    expect(out.single.tried, 'warmed the towels');
    expect(out.single.outcome, ApproachOutcome.worked);
  });

  test('returns newest first', () async {
    await repo.record(_a('old', CareSituation.agitatedOrUpset, 'older',
        ApproachOutcome.worked, at: DateTime(2026, 7, 1)));
    await repo.record(_a('new', CareSituation.agitatedOrUpset, 'newer',
        ApproachOutcome.worked, at: DateTime(2026, 7, 25)));
    final List<CareApproach> out = await repo.forPatient('p1');
    expect(out.map((CareApproach a) => a.tried), <String>['newer', 'older']);
  });

  test('keeps one client\'s notes away from another\'s', () async {
    await repo.record(_a('a1', CareSituation.refusedToEat, 'client one',
        ApproachOutcome.worked));
    await repo.record(_a('a2', CareSituation.refusedToEat, 'client two',
        ApproachOutcome.worked, patientId: 'p2'));
    expect((await repo.forPatient('p1')).single.tried, 'client one');
    expect((await repo.forPatient('p2')).single.tried, 'client two');
  });

  test('filters by situation — the mid-visit lookup', () async {
    await repo.record(_a('a1', CareSituation.resistedPersonalCare, 'towels',
        ApproachOutcome.worked));
    await repo.record(_a('a2', CareSituation.refusedMedication, 'came back',
        ApproachOutcome.worked));
    final List<CareApproach> out =
        await repo.forSituation('p1', CareSituation.refusedMedication);
    expect(out, hasLength(1));
    expect(out.single.tried, 'came back');
  });

  test('re-recording the same id updates rather than duplicating', () async {
    await repo.record(_a('a1', CareSituation.agitatedOrUpset, 'first take',
        ApproachOutcome.partly));
    await repo.record(_a('a1', CareSituation.agitatedOrUpset, 'corrected',
        ApproachOutcome.worked));
    final List<CareApproach> out = await repo.forPatient('p1');
    expect(out, hasLength(1));
    expect(out.single.tried, 'corrected');
  });

  test('deletes', () async {
    await repo.record(_a('a1', CareSituation.other, 'x',
        ApproachOutcome.worked));
    await repo.delete('a1');
    expect(await repo.forPatient('p1'), isEmpty);
  });

  /// A corrupted row must cost the worker ONE entry, never the client's whole
  /// history — the same rule the rest of the app follows for blob payloads.
  test('a row whose payload will not parse is skipped, not fatal', () async {
    await repo.record(_a('good', CareSituation.refusedToEat, 'kept it',
        ApproachOutcome.worked));
    await db.customStatement(
      "INSERT INTO care_approaches (id, patient_id, situation, at_ms, payload) "
      "VALUES ('bad', 'p1', 'refusedToEat', 1, 'not json')",
    );
    final List<CareApproach> out = await repo.forPatient('p1');
    expect(out, hasLength(1));
    expect(out.single.tried, 'kept it');
  });
}
