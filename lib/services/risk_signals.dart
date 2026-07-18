import '../models/risk_signal.dart';
import 'medication_supply.dart';
import 'pattern_detector.dart';

/// A medication's name paired with its computed supply runway — the input
/// the refill rules read.
typedef NamedSupply = ({String medName, MedicationSupply supply});

/// Compose the client's early-warning signals (Track-2 #18) from the
/// existing rule-based detectors: the journal pattern alerts (falls) and the
/// per-medication refill runway. Pure + deterministic so the rules are
/// unit-testable without a widget tree; urgent signals sort ahead of watch.
///
/// Nothing here diagnoses or predicts with a model — each signal is an
/// explainable rule over data the caregiver already entered.
List<RiskSignal> buildRiskSignals({
  required List<PatternAlert> patternAlerts,
  required List<NamedSupply> supplies,
}) {
  final List<RiskSignal> out = <RiskSignal>[];

  for (final PatternAlert a in patternAlerts) {
    out.add(RiskSignal(
      kind: a.kind,
      level: a.severity == PatternSeverity.warning
          ? RiskLevel.urgent
          : RiskLevel.watch,
      title: _titleForAlert(a.kind),
      detail: a.text,
    ));
  }

  for (final NamedSupply s in supplies) {
    switch (s.supply.status) {
      case SupplyStatus.outOfRefills:
        out.add(RiskSignal(
          kind: 'refill_out',
          level: RiskLevel.urgent,
          title: 'No refills left',
          detail: '${s.medName} has no refills left — contact the pharmacy '
              'or prescriber before it runs out.',
        ));
      case SupplyStatus.refillSoon:
        out.add(RiskSignal(
          kind: 'refill_soon',
          level: RiskLevel.watch,
          title: 'Running low',
          detail: _refillDetail(s.medName, s.supply),
        ));
      case SupplyStatus.ok:
      case SupplyStatus.unknown:
        break;
    }
  }

  // Urgent first; otherwise keep insertion order (stable sort).
  out.sort((RiskSignal a, RiskSignal b) => _rank(a.level) - _rank(b.level));
  return List<RiskSignal>.unmodifiable(out);
}

int _rank(RiskLevel l) => l == RiskLevel.urgent ? 0 : 1;

String _titleForAlert(String kind) =>
    kind.startsWith('falls') ? 'Recent falls' : 'Heads up';

String _refillDetail(String medName, MedicationSupply supply) {
  final DateTime? out = supply.runOutDate;
  if (out == null) return '$medName is running low — plan a refill.';
  return '$medName runs out around ${_shortDate(out)} — refill while there '
      'is time.';
}

String _shortDate(DateTime d) {
  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}';
}
