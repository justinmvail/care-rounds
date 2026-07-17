import 'package:carerounds/db/database.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

/// v21 schema work (Care Rounds): a `teams` table + a nullable
/// `caregivers.team_id` column, so caregivers group into teams. The step is
/// purely structural and MUST be safe to run twice — drift doesn't wrap
/// migrations in a transaction and re-runs an interrupted one from the same
/// version, so a bare `ALTER TABLE ADD COLUMN` (which throws "duplicate column
/// name") would brick the database forever. `createTable` emits
/// `CREATE TABLE IF NOT EXISTS` and the column goes through
/// `_addColumnIfMissing`, which is what this pins.
void main() {
  test('the v21 upgrade step is IDEMPOTENT — re-running it over a database '
      'that already has the teams table + team_id column must NOT throw',
      () async {
    final CareRoundsDatabase db = CareRoundsDatabase.testInstance();
    addTearDown(db.close);
    // Materialise the full v21 schema (teams table + caregivers.team_id).
    await db.customSelect('SELECT 1').get();

    final Migrator m = Migrator(db);
    await expectLater(
      db.migration.onUpgrade(m, 20, 21),
      completes,
      reason: 'a re-run of the v21 upgrade must not throw',
    );
    // And a second time, to be sure.
    await expectLater(
      db.migration.onUpgrade(Migrator(db), 20, 21),
      completes,
      reason: 'twice must still be safe',
    );
  });

  test('a fresh install carries the teams table and caregivers.team_id',
      () async {
    final CareRoundsDatabase db = CareRoundsDatabase.testInstance();
    addTearDown(db.close);

    final List<QueryRow> tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'teams'",
        )
        .get();
    expect(tables, hasLength(1), reason: 'the teams table must exist');

    final List<QueryRow> cols =
        await db.customSelect('PRAGMA table_info(caregivers)').get();
    final Set<String> names =
        cols.map((QueryRow r) => r.read<String>('name')).toSet();
    expect(names, contains('team_id'),
        reason: 'caregivers must carry the team_id column');
  });
}
