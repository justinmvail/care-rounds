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

  group('emergent per-client patterns', () {
    const RiskSignal cluster = RiskSignal(
      kind: 'emergent_cluster:refusedToEat',
      level: RiskLevel.watch,
      title: 'Refused to eat — clusters in the evening',
      detail: '3 of 3 times in the last 14 days it was recorded in the '
          'evening.',
    );
    const RiskSignal stuck = RiskSignal(
      kind: 'emergent_nothing_working:resistedPersonalCare',
      level: RiskLevel.urgent,
      title: 'Resisted personal care — nothing has worked yet',
      detail: '4 attempts and none of them helped.',
    );

    test('emergent signals keep their own title and detail', () {
      final List<RiskSignal> s = buildRiskSignals(
        patternAlerts: const <PatternAlert>[],
        supplies: const <NamedSupply>[],
        emergent: const <RiskSignal>[cluster],
      );
      expect(s, hasLength(1));
      expect(s.single.title, 'Refused to eat — clusters in the evening');
      expect(s.single.detail, contains('the last 14 days'));
    });

    test('an emergent escalation sorts with the other urgent signals', () {
      final List<RiskSignal> s = buildRiskSignals(
        patternAlerts: const <PatternAlert>[],
        supplies: <NamedSupply>[
          _supply('Aspirin', SupplyStatus.refillSoon,
              runOut: DateTime(2026, 7, 22)), // watch
        ],
        emergent: const <RiskSignal>[cluster, stuck],
      );
      expect(s.first, stuck);
      expect(s.map((RiskSignal x) => x.level).last, RiskLevel.watch);
    });

    test('omitting emergent leaves the existing signals untouched', () {
      expect(
        buildRiskSignals(
          patternAlerts: const <PatternAlert>[],
          supplies: <NamedSupply>[
            _supply('Atorvastatin', SupplyStatus.outOfRefills),
          ],
        ),
        hasLength(1),
      );
    });
  });
}
