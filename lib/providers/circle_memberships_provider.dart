import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/care_circle_membership.dart';
import 'care_circle_provider.dart';

part 'circle_memberships_provider.g.dart';

/// Every caregiver↔client membership on file (Care Rounds).
///
/// The membership rows ARE the caregiver↔client many-to-many
/// (`caregiverId` ↔ `patientId`). Grouped by client, they give the
/// per-client assignment counts the Team hub's Clients roster shows.
@Riverpod(keepAlive: true)
Future<List<CareCircleMembership>> circleMemberships(Ref ref) async {
  final CareCircleRepository repo = ref.watch(careCircleRepositoryProvider);
  return repo.listMemberships();
}
