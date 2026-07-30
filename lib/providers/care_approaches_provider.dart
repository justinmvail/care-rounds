import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../db/database.dart';
import '../models/care_approach.dart';
import 'active_patient_provider.dart';

part 'care_approaches_provider.g.dart';

/// Persistence for "what worked last time" — the per-client record of what a
/// worker tried in a hard moment and whether it helped.
///
/// Same blob-with-lifted-keys pattern the flags / shifts repositories use: the
/// freezed [CareApproach] serialises into `payload`, with `patientId`,
/// `situation` and `atMs` lifted so the two reads that matter (everything for a
/// client, and everything for one situation) never decode a blob to filter.
class CareApproachesRepository {
  CareApproachesRepository(this._db);

  final CareRoundsDatabase _db;

  Future<void> close() => _db.close();

  Future<void> record(CareApproach approach) async {
    await _db.into(_db.careApproachesTable).insertOnConflictUpdate(
          CareApproachesTableCompanion.insert(
            id: approach.id,
            patientId: approach.patientId,
            situation: approach.situation.name,
            atMs: approach.at.millisecondsSinceEpoch,
            payload: jsonEncode(approach.toJson()),
          ),
        );
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.careApproachesTable)..where((t) => t.id.equals(id)))
        .go();
  }

  /// Everything recorded for [patientId], newest first.
  Future<List<CareApproach>> forPatient(String patientId) async {
    final List<CareApproachesTableData> rows =
        await (_db.select(_db.careApproachesTable)
              ..where(($CareApproachesTableTable t) =>
                  t.patientId.equals(patientId))
              ..orderBy(<OrderingTerm Function(dynamic)>[
                (t) => OrderingTerm(
                    expression: t.atMs, mode: OrderingMode.desc),
              ]))
            .get();
    return rows.map(_decode).whereType<CareApproach>().toList();
  }

  /// Everything recorded for one [situation] with [patientId], newest first —
  /// the mid-visit lookup ("she's refusing the shower again, what worked?").
  Future<List<CareApproach>> forSituation(
    String patientId,
    CareSituation situation,
  ) async {
    final List<CareApproachesTableData> rows =
        await (_db.select(_db.careApproachesTable)
              ..where(($CareApproachesTableTable t) =>
                  t.patientId.equals(patientId) &
                  t.situation.equals(situation.name))
              ..orderBy(<OrderingTerm Function(dynamic)>[
                (t) => OrderingTerm(
                    expression: t.atMs, mode: OrderingMode.desc),
              ]))
            .get();
    return rows.map(_decode).whereType<CareApproach>().toList();
  }

  /// A row whose payload no longer parses must not sink the whole list — the
  /// worker loses one entry, not the client's entire history.
  CareApproach? _decode(CareApproachesTableData row) {
    try {
      return CareApproach.fromJson(
          jsonDecode(row.payload) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

/// Shared-DB repository (keepAlive), mirroring the flags/shifts indirection —
/// callers reach for [careApproachesRepositoryProvider] and never see drift.
@Riverpod(keepAlive: true)
CareApproachesRepository careApproachesRepositoryBackend(Ref ref) {
  final CareRoundsDatabase db = CareRoundsDatabase.open();
  ref.onDispose(db.close);
  return CareApproachesRepository(db);
}

/// Alias matching the name the screens reach for (and tests override).
final CareApproachesRepositoryBackendProvider careApproachesRepositoryProvider =
    careApproachesRepositoryBackendProvider;

/// The active client's recorded approaches, newest first.
@riverpod
Future<List<CareApproach>> clientCareApproaches(Ref ref) async {
  final String? patientId =
      (await ref.watch(activePatientProvider.future))?.id;
  if (patientId == null) return const <CareApproach>[];
  return ref.watch(careApproachesRepositoryProvider).forPatient(patientId);
}
