import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../db/database.dart';
import '../models/supervisor_flag.dart';

part 'supervisor_flags_provider.g.dart';

/// Persistence for the supervisor escalation channel (Track-2 #17).
///
/// Same blob-with-lifted-keys pattern the shift / expense repositories use —
/// the freezed [SupervisorFlag] serialises into the row's `payload`, with
/// `createdAtMs` (inbox ordering) and `resolvedAtMs` (open-vs-resolved
/// filter) lifted out so those reads never decode a blob.
///
/// Local-only for now: a flag lives in the on-device DB the whole team app
/// shares. Cross-device sync of flags is a follow-up (it would ride the same
/// sync sink the shifts/tasks use once the Worker whitelists the entity).
class SupervisorFlagsRepository {
  SupervisorFlagsRepository(this._db);

  final CareRoundsDatabase _db;

  Future<void> close() => _db.close();

  /// Insert-or-replace [flag] by id (also used to persist a resolve).
  Future<void> raise(SupervisorFlag flag) async {
    await _db.into(_db.supervisorFlagsTable).insertOnConflictUpdate(
          SupervisorFlagsTableCompanion.insert(
            id: flag.id,
            patientId: flag.patientId,
            createdAtMs: flag.createdAt.millisecondsSinceEpoch,
            resolvedAtMs: Value<int?>(flag.resolvedAt?.millisecondsSinceEpoch),
            payload: jsonEncode(flag.toJson()),
          ),
        );
  }

  /// Mark the flag [id] resolved at [at]. No-op if the flag is absent.
  Future<void> resolve(String id, {required DateTime at}) async {
    final SupervisorFlagsTableData? row =
        await (_db.select(_db.supervisorFlagsTable)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
    if (row == null) return;
    final SupervisorFlag flag = _decode(row).copyWith(resolvedAt: at);
    await raise(flag);
  }

  /// Open flags across every client, newest first — the supervisor inbox.
  Stream<List<SupervisorFlag>> watchOpen() =>
      (_db.select(_db.supervisorFlagsTable)
            ..where((t) => t.resolvedAtMs.isNull())
            ..orderBy(<OrderingTerm Function($SupervisorFlagsTableTable)>[
              (t) => OrderingTerm.desc(t.createdAtMs)
            ]))
          .watch()
          .map((List<SupervisorFlagsTableData> rows) =>
              rows.map(_decode).toList());

  /// Open flags right now (one-shot; for tests + counts).
  Future<List<SupervisorFlag>> listOpen() async {
    final List<SupervisorFlagsTableData> rows =
        await (_db.select(_db.supervisorFlagsTable)
              ..where((t) => t.resolvedAtMs.isNull())
              ..orderBy(<OrderingTerm Function($SupervisorFlagsTableTable)>[
                (t) => OrderingTerm.desc(t.createdAtMs)
              ]))
            .get();
    return rows.map(_decode).toList();
  }

  SupervisorFlag _decode(SupervisorFlagsTableData row) =>
      SupervisorFlag.fromJson(jsonDecode(row.payload) as Map<String, dynamic>);
}

/// Shared-DB [SupervisorFlagsRepository] (keepAlive) — the app reaches for
/// [supervisorFlagsRepositoryProvider] and never sees the concrete drift db,
/// the same indirection the shift / task repositories use.
@Riverpod(keepAlive: true)
SupervisorFlagsRepository supervisorFlagsRepositoryBackend(Ref ref) {
  final CareRoundsDatabase db = CareRoundsDatabase.open();
  ref.onDispose(db.close);
  return SupervisorFlagsRepository(db);
}

/// Alias matching the name the flags screen reaches for.
final SupervisorFlagsRepositoryBackendProvider supervisorFlagsRepositoryProvider =
    supervisorFlagsRepositoryBackendProvider;

/// Open-flag inbox (across clients), newest first. A one-shot read that the
/// raise / resolve handlers `invalidate` to refresh — deliberately NOT a
/// live drift `.watch()` stream, whose query-coalescing timer strands the
/// widget-test binding (and a Future re-read is plenty for an inbox).
@riverpod
Future<List<SupervisorFlag>> openSupervisorFlags(Ref ref) =>
    ref.watch(supervisorFlagsRepositoryProvider).listOpen();
