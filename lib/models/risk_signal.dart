import 'package:flutter/foundation.dart';

/// How much attention an early-warning [RiskSignal] wants.
enum RiskLevel {
  /// Keep an eye on it (a refill running low, a mild trend).
  watch,

  /// Act soon (no refills left, a repeated fall).
  urgent,
}

/// One predictive care-need / early-warning signal for a client (Track-2
/// #18). Rule-based and EXPLAINABLE — every signal states the plain reason
/// it fired ([detail]); this surfaces rising need early, it does not
/// diagnose or predict with a black-box model. Composed from the existing
/// pattern detector (falls) + refill-runway estimate.
@immutable
class RiskSignal {
  const RiskSignal({
    required this.kind,
    required this.level,
    required this.title,
    required this.detail,
  });

  /// Stable machine tag for the rule that fired (e.g. `falls_3plus_7d`,
  /// `refill_out`). Used for keys + de-dup, never shown.
  final String kind;

  final RiskLevel level;

  /// Short headline ("Recent falls", "No refills left").
  final String title;

  /// The plain-language reason, shown under the title.
  final String detail;

  @override
  bool operator ==(Object other) =>
      other is RiskSignal &&
      other.kind == kind &&
      other.level == level &&
      other.title == title &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(kind, level, title, detail);
}
