import 'package:carerounds/db/database.dart';
import 'package:carerounds/models/supervisor_flag.dart';
import 'package:carerounds/providers/supervisor_flags_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

SupervisorFlag _flag(String id, String patientId, DateTime at) => SupervisorFlag(
      id: id,
      patientId: patientId,
      raisedByCaregiverId: 'cg-1',
      message: 'flag $id',
      createdAt: at,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CareRoundsDatabase db;
  late SupervisorFlagsRepository repo;

  setUp(() {
    db = CareRoundsDatabase(NativeDatabase.memory());
    repo = SupervisorFlagsRepository(db);
  });
  tearDown(() async => db.close());

  test('raise → listOpen returns open flags, newest first', () async {
    await repo.raise(_flag('f-old', 'p-mary', DateTime(2026, 7, 18, 8)));
    await repo.raise(_flag('f-new', 'p-frank', DateTime(2026, 7, 18, 10)));

    final List<SupervisorFlag> open = await repo.listOpen();
    expect(open.map((SupervisorFlag f) => f.id), <String>['f-new', 'f-old']);
    expect(open.every((SupervisorFlag f) => f.isOpen), isTrue);
  });

  test('resolve drops a flag from the open inbox', () async {
    await repo.raise(_flag('f-1', 'p-mary', DateTime(2026, 7, 18, 8)));
    await repo.raise(_flag('f-2', 'p-mary', DateTime(2026, 7, 18, 9)));

    await repo.resolve('f-1', at: DateTime(2026, 7, 18, 12));

    final List<SupervisorFlag> open = await repo.listOpen();
    expect(open.map((SupervisorFlag f) => f.id), <String>['f-2']);
  });

  test('resolve is a no-op for an unknown id', () async {
    await repo.resolve('nope', at: DateTime(2026, 7, 18, 12));
    expect(await repo.listOpen(), isEmpty);
  });

  test('watchOpen emits the current open set', () async {
    await repo.raise(_flag('f-1', 'p-mary', DateTime(2026, 7, 18, 8)));
    final List<SupervisorFlag> first = await repo.watchOpen().first;
    expect(first.single.id, 'f-1');
  });
}
