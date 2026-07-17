import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/care_shift.dart';
import 'care_shifts_provider.dart';
import 'storage_provider.dart';

part 'my_rounds_provider.g.dart';

/// The caregiver in the roster who is *this device's user* (Care Rounds), or
/// null when it hasn't been chosen yet.
///
/// A family app treats "me" as the account owner; a direct-care team needs to
/// know which roster caregiver is the signed-in worker so "My Rounds" can show
/// *their* shifts. Persisted via [StorageProvider.setSelfCaregiverId]; the
/// picker invalidates this so the app re-reads.
@Riverpod(keepAlive: true)
Future<String?> selfCaregiverId(Ref ref) async {
  final StorageProvider storage = ref.watch(storageProvider);
  return storage.getSelfCaregiverId();
}

/// "My Rounds" — the signed-in worker's shifts across EVERY client, earliest
/// first (Care Rounds; ACL Track 2 use case #1, "matching & scheduling").
///
/// Unlike [CareShifts] (which scopes the coverage board to the *active*
/// client), this scopes to the *caregiver* and spans all clients — a worker's
/// day of visits. Empty until a self caregiver is chosen.
@Riverpod(keepAlive: true)
Future<List<CareShift>> myRounds(Ref ref) async {
  final String? caregiverId = await ref.watch(selfCaregiverIdProvider.future);
  if (caregiverId == null || caregiverId.isEmpty) return const <CareShift>[];
  final CareShiftsRepository repo = ref.watch(careShiftsRepositoryProvider);
  return repo.listShiftsForCaregiver(caregiverId);
}
