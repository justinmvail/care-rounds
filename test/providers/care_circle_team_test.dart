import 'package:carerounds/db/database.dart';
import 'package:carerounds/models/caregiver.dart';
import 'package:carerounds/models/team.dart';
import 'package:carerounds/providers/care_circle_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Care Rounds v21: caregivers group into teams. The caregiver↔client
/// many-to-many stays on the membership rows; a [Team] is the container above
/// the roster.
void main() {
  group('CareCircleRepository — Teams (Care Rounds)', () {
    late CareRoundsDatabase db;
    late CareCircleRepository repo;

    setUp(() {
      db = CareRoundsDatabase(NativeDatabase.memory());
      repo = CareCircleRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('team round-trips through typed columns', () async {
      final Team team = Team(
        id: 't1',
        name: 'Sunrise Home Care',
        createdAt: DateTime.utc(2026, 5, 1),
      );
      await repo.upsertTeam(team);

      final Team? loaded = await repo.getTeam('t1');
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Sunrise Home Care');
      expect(loaded.createdAt, DateTime.utc(2026, 5, 1));
    });

    test('listTeams is ordered oldest-first', () async {
      await repo.upsertTeam(Team(
          id: 'b', name: 'B', createdAt: DateTime.utc(2026, 6, 1)));
      await repo.upsertTeam(Team(
          id: 'a', name: 'A', createdAt: DateTime.utc(2026, 5, 1)));

      final List<Team> teams = await repo.listTeams();
      expect(teams.map((t) => t.id).toList(), <String>['a', 'b']);
    });

    test('ensureDefaultTeam creates one team and is idempotent', () async {
      final Team first = await repo.ensureDefaultTeam();
      final Team second = await repo.ensureDefaultTeam();

      expect(first.id, second.id, reason: 'must reuse the existing team');
      expect(await repo.listTeams(), hasLength(1),
          reason: 'must not create a second team');
    });

    test('assignCaregiverToTeam groups a caregiver into a team', () async {
      await repo.upsertCaregiver(const Caregiver(
        id: 'c1',
        displayName: 'Aide One',
        role: CaregiverRole.aide,
      ));
      final Team team = await repo.ensureDefaultTeam();

      await repo.assignCaregiverToTeam('c1', team.id);

      final Caregiver? loaded = await repo.getCaregiver('c1');
      expect(loaded?.teamId, team.id);
    });

    test('assignCaregiverToTeam is a no-op for an unknown caregiver', () async {
      final Team team = await repo.ensureDefaultTeam();
      await expectLater(
        repo.assignCaregiverToTeam('ghost', team.id),
        completes,
      );
      expect(await repo.getCaregiver('ghost'), isNull);
    });

    test('teamId round-trips on the caregiver itself', () async {
      await repo.upsertCaregiver(const Caregiver(
        id: 'c2',
        displayName: 'Aide Two',
        role: CaregiverRole.aide,
        teamId: 'team-default',
      ));
      final Caregiver? loaded = await repo.getCaregiver('c2');
      expect(loaded?.teamId, 'team-default');
    });
  });
}
