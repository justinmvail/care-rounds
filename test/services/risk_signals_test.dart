import 'package:carerounds/models/risk_signal.dart';
import 'package:carerounds/services/medication_supply.dart';
import 'package:carerounds/services/pattern_detector.dart';
import 'package:carerounds/services/risk_signals.dart';
import 'package:flutter_test/flutter_test.dart';

NamedSupply _supply(String name, SupplyStatus status, {DateTime? runOut}) =>
    (medName: name, supply: MedicationSupply(status: status, runOutDate: runOut));

void main() {
  test('no alerts and healthy supplies → no signals', () {
    expect(
      buildRiskSignals(
        patternAlerts: const <PatternAlert>[],
        supplies: <NamedSupply>[_supply('Lisinopril', SupplyStatus.ok)],
      ),
      isEmpty,
    );
  });

  test('a fall alert becomes an urgent signal', () {
    final List<RiskSignal> s = buildRiskSignals(
      patternAlerts: const <PatternAlert>[
        PatternAlert(
          kind: 'falls_3plus_7d',
          text: '3+ falls this week.',
          severity: PatternSeverity.warning,
        ),
      ],
      supplies: const <NamedSupply>[],
    );
    expect(s, hasLength(1));
    expect(s.single.level, RiskLevel.urgent);
    expect(s.single.title, 'Recent falls');
    expect(s.single.detail, contains('falls'));
  });

  test('out-of-refills is urgent, refill-soon is watch', () {
    final List<RiskSignal> s = buildRiskSignals(
      patternAlerts: const <PatternAlert>[],
      supplies: <NamedSupply>[
        _supply('Aspirin', SupplyStatus.refillSoon,
            runOut: DateTime(2026, 7, 22)),
        _supply('Atorvastatin', SupplyStatus.outOfRefills),
      ],
    );
    final RiskSignal out =
        s.firstWhere((RiskSignal x) => x.kind == 'refill_out');
    final RiskSignal soon =
        s.firstWhere((RiskSignal x) => x.kind == 'refill_soon');
    expect(out.level, RiskLevel.urgent);
    expect(out.detail, contains('Atorvastatin'));
    expect(soon.level, RiskLevel.watch);
    expect(soon.detail, contains('Jul 22'));
  });

  test('urgent signals sort ahead of watch signals', () {
    final List<RiskSignal> s = buildRiskSignals(
      patternAlerts: const <PatternAlert>[],
      supplies: <NamedSupply>[
        _supply('Aspirin', SupplyStatus.refillSoon,
            runOut: DateTime(2026, 7, 22)), // watch
        _supply('Atorvastatin', SupplyStatus.outOfRefills), // urgent
      ],
    );
    expect(s.first.level, RiskLevel.urgent);
    expect(s.last.level, RiskLevel.watch);
  });
}
