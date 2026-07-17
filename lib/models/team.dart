import 'package:freezed_annotation/freezed_annotation.dart';

part 'team.freezed.dart';
part 'team.g.dart';

/// A team of caregivers (Care Rounds).
///
/// The organisational unit above the caregiver roster: a direct-care team,
/// agency, or family that shares a set of clients. A [Caregiver] belongs to a
/// team via `Caregiver.teamId`; the caregiver↔client assignments remain the
/// [CareCircleMembership] rows (which already join `caregiverId` ↔
/// `patientId`, i.e. many-to-many). One team per install today — created
/// lazily by `CareCircleRepository.ensureDefaultTeam()` — but modelled as a
/// first-class row so additional teams land without a migration.
@freezed
abstract class Team with _$Team {
  const factory Team({
    required String id,
    required String name,
    required DateTime createdAt,
  }) = _Team;

  factory Team.fromJson(Map<String, dynamic> json) => _$TeamFromJson(json);
}
