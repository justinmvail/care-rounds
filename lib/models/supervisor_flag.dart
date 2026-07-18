import 'package:freezed_annotation/freezed_annotation.dart';

part 'supervisor_flag.freezed.dart';
part 'supervisor_flag.g.dart';

/// One thing a direct-care worker has escalated to a supervisor (Track-2
/// #17) — the human-in-the-loop channel the flagship's `needs_attention`
/// notes feed into, and that a worker can raise directly.
///
/// A flag names the client ([patientId]), who raised it
/// ([raisedByCaregiverId] — a logical link to the roster, resolved softly at
/// read time, like a shift's assignee), the [message], and when. It stays
/// **open** until a supervisor resolves it ([resolvedAt] set) — so a flag is
/// a task for a human, never an automatic action.
@freezed
abstract class SupervisorFlag with _$SupervisorFlag {
  const factory SupervisorFlag({
    required String id,
    required String patientId,
    required String raisedByCaregiverId,
    required String message,
    required DateTime createdAt,
    DateTime? resolvedAt,
  }) = _SupervisorFlag;

  factory SupervisorFlag.fromJson(Map<String, dynamic> json) =>
      _$SupervisorFlagFromJson(json);
}

extension SupervisorFlagX on SupervisorFlag {
  /// Still awaiting a supervisor — the inbox shows exactly these.
  bool get isOpen => resolvedAt == null;
}
