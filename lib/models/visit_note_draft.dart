import 'package:flutter/foundation.dart';

/// The structured visit note the AI proposes from a worker's spoken (or
/// typed) account of a visit — the "note that writes itself" (Track-2 #16,
/// the flagship). A transient draft, not a persisted entity: the worker
/// reviews + edits it, and on save it's written as a [JournalEntry] for the
/// active client. Nothing is ever saved without that review.
///
/// The model only ever STRUCTURES what the worker said — it does not
/// diagnose, dose, or add clinical judgement (see visit_note_prompt.dart).
@immutable
class VisitNoteDraft {
  const VisitNoteDraft({
    this.summary = '',
    this.observations = '',
    this.tasksDone = const <String>[],
    this.concern = '',
    this.needsAttention = false,
  });

  /// A one-line headline of the visit ("Morning visit — steady, ate well").
  final String summary;

  /// The narrative: how the client was, what happened, how they seemed.
  final String observations;

  /// Care tasks the worker completed (helped shower, gave 8am meds, …).
  final List<String> tasksDone;

  /// Anything the worker flagged as a worry / worth passing on. Empty when
  /// the visit was unremarkable.
  final String concern;

  /// The model's read on whether a supervisor should be looped in — true
  /// only when the worker described something that plausibly needs a human
  /// escalation (a fall, a big change, refused care). Feeds the supervisor
  /// flag (#17); never an auto-action.
  final bool needsAttention;

  bool get isEmpty =>
      summary.trim().isEmpty &&
      observations.trim().isEmpty &&
      tasksDone.isEmpty &&
      concern.trim().isEmpty;

  VisitNoteDraft copyWith({
    String? summary,
    String? observations,
    List<String>? tasksDone,
    String? concern,
    bool? needsAttention,
  }) =>
      VisitNoteDraft(
        summary: summary ?? this.summary,
        observations: observations ?? this.observations,
        tasksDone: tasksDone ?? this.tasksDone,
        concern: concern ?? this.concern,
        needsAttention: needsAttention ?? this.needsAttention,
      );

  /// Parse the model's JSON reply. Tolerant of missing / mistyped fields —
  /// anything unreadable degrades to empty rather than throwing, so a
  /// partial extraction still pre-fills what it could.
  factory VisitNoteDraft.fromModelJson(Map<String, dynamic> json) {
    String str(Object? v) => v is String ? v.trim() : '';
    return VisitNoteDraft(
      summary: str(json['summary']),
      observations: str(json['observations']),
      tasksDone: switch (json['tasks_done']) {
        final List<dynamic> l => <String>[
            for (final dynamic e in l)
              if (e is String && e.trim().isNotEmpty) e.trim(),
          ],
        _ => const <String>[],
      },
      concern: str(json['concern']),
      needsAttention: json['needs_attention'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is VisitNoteDraft &&
      other.summary == summary &&
      other.observations == observations &&
      listEquals(other.tasksDone, tasksDone) &&
      other.concern == concern &&
      other.needsAttention == needsAttention;

  @override
  int get hashCode => Object.hash(summary, observations,
      Object.hashAll(tasksDone), concern, needsAttention);
}
