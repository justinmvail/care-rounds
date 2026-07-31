import 'package:carerounds/models/care_approach.dart';
import 'package:carerounds/models/risk_signal.dart';
import 'package:carerounds/services/emergent_pattern_detector.dart';
import 'package:flutter_test/flutter_test.dart';

/// Anchor every fixture to a fixed "now" so window arithmetic is deterministic.
final DateTime _now = DateTime(2026, 7, 31, 20);

CareApproach _a({
  required CareSituation situation,
  required DateTime at,
  ApproachOutcome outcome = ApproachOutcome.didNotWork,
  String tried = 'tried something',
}) =>
    CareApproach(
      id: '${situation.name}-${at.millisecondsSinceEpoch}-$tried',
      patientId: 'p1',
      situation: situation,
      tried: tried,
      outcome: outcome,
      at: at,
    );

/// [n] entries for [situation], one per day back from [_now], each at [hour].
List<CareApproach> _series(
  CareSituation situation,
  int n, {
  required int hour,
  ApproachOutcome outcome = ApproachOutcome.didNotWork,
}) =>
    <CareApproach>[
      for (int i = 0; i < n; i++)
        _a(
          situation: situation,
          at: DateTime(2026, 7, 31 - i, hour),
          outcome: outcome,
          tried: 'attempt $i',
        ),
    ];

void main() {
  const EmergentPatternDetector detector = EmergentPatternDetector();

  group('EmergentPatternDetector — emergence, not a fixed behavior list', () {
    test('finds a clustering situation nobody hardcoded (refused to eat)', () {
      final List<RiskSignal> out = detector.detect(
        _series(CareSituation.refusedToEat, 3,
            hour: 19, outcome: ApproachOutcome.worked),
        now: _now,
      );

      expect(out, hasLength(1));
      expect(out.single.kind, 'emergent_cluster:refusedToEat');
      expect(out.single.title, contains('Refused to eat'));
      expect(out.single.detail, contains('the evening'));
      expect(out.single.detail, contains('earlier in the day'));
    });

    test('finds a morning cluster and plans the opposite way', () {
      final List<RiskSignal> out = detector.detect(
        _series(CareSituation.refusedMedication, 4,
            hour: 8, outcome: ApproachOutcome.partly),
        now: _now,
      );

      expect(out.single.kind, 'emergent_cluster:refusedMedication');
      expect(out.single.detail, contains('the morning'));
      expect(out.single.detail, contains('later in the day'));
    });

    test('the same rules fire on any situation in the enum', () {
      for (final CareSituation s in CareSituation.values) {
        final List<RiskSignal> out = detector.detect(
          _series(s, 3, hour: 19, outcome: ApproachOutcome.worked),
          now: _now,
        );
        expect(out, hasLength(1), reason: 'no signal for ${s.name}');
        expect(out.single.kind, 'emergent_cluster:${s.name}');
      }
    });
  });

  group('EmergentPatternDetector — thresholds', () {
    test('below the threshold is a bad day, not a pattern', () {
      final List<RiskSignal> out = detector.detect(
        _series(CareSituation.agitatedOrUpset, kEmergentThreshold - 1,
            hour: 19),
        now: _now,
      );
      expect(out, isEmpty);
    });

    test('entries older than the window do not count', () {
      final List<CareApproach> old = <CareApproach>[
        for (int i = 0; i < 5; i++)
          _a(
            situation: CareSituation.agitatedOrUpset,
            at: _now.subtract(Duration(days: 20 + i)),
            tried: 'attempt $i',
          ),
      ];
      expect(detector.detect(old, now: _now), isEmpty);
    });

    test('a situation spread evenly across the day does not cluster', () {
      final List<CareApproach> spread = <CareApproach>[
        _a(situation: CareSituation.upAtNightOrRestless,
            at: DateTime(2026, 7, 30, 9), tried: 'a'),
        _a(situation: CareSituation.upAtNightOrRestless,
            at: DateTime(2026, 7, 29, 14), tried: 'b'),
        _a(situation: CareSituation.upAtNightOrRestless,
            at: DateTime(2026, 7, 28, 20), tried: 'c'),
      ];
      final List<RiskSignal> out = detector.detect(spread, now: _now);
      expect(out.single.kind, 'emergent_nothing_working:upAtNightOrRestless');
    });

    test('empty input yields nothing', () {
      expect(detector.detect(const <CareApproach>[], now: _now), isEmpty);
    });
  });

  group('EmergentPatternDetector — which rule wins', () {
    test('nothing-working outranks clustering and escalates', () {
      final List<RiskSignal> out = detector.detect(
        _series(CareSituation.resistedPersonalCare, 3,
            hour: 19, outcome: ApproachOutcome.didNotWork),
        now: _now,
      );

      expect(out.single.kind,
          'emergent_nothing_working:resistedPersonalCare');
      expect(out.single.level, RiskLevel.urgent);
      expect(out.single.detail, contains('supervisor'));
    });

    test('one partial success is enough to stop the escalation', () {
      final List<CareApproach> items = <CareApproach>[
        ..._series(CareSituation.resistedPersonalCare, 2, hour: 19),
        _a(
          situation: CareSituation.resistedPersonalCare,
          at: DateTime(2026, 7, 28, 19),
          outcome: ApproachOutcome.partly,
          tried: 'warmed the towels',
        ),
      ];
      final List<RiskSignal> out = detector.detect(items, now: _now);
      expect(out.single.kind, 'emergent_cluster:resistedPersonalCare');
      expect(out.single.level, RiskLevel.watch);
    });

    test('recurring is the fallback when nothing else fires', () {
      final List<CareApproach> spread = <CareApproach>[
        _a(situation: CareSituation.other,
            at: DateTime(2026, 7, 30, 9),
            outcome: ApproachOutcome.worked, tried: 'a'),
        _a(situation: CareSituation.other,
            at: DateTime(2026, 7, 29, 14), tried: 'b'),
        _a(situation: CareSituation.other,
            at: DateTime(2026, 7, 28, 20), tried: 'c'),
      ];
      final List<RiskSignal> out = detector.detect(spread, now: _now);
      expect(out.single.kind, 'emergent_recurring:other');
      expect(out.single.detail, contains('check what works'));
    });
  });

  group('EmergentPatternDetector — output shape', () {
    test('reports several situations at once, most frequent first', () {
      final List<CareApproach> items = <CareApproach>[
        ..._series(CareSituation.agitatedOrUpset, 5,
            hour: 19, outcome: ApproachOutcome.worked),
        ..._series(CareSituation.refusedToEat, 3,
            hour: 19, outcome: ApproachOutcome.worked),
      ];
      final List<RiskSignal> out = detector.detect(items, now: _now);

      expect(out, hasLength(2));
      expect(out.first.kind, 'emergent_cluster:agitatedOrUpset');
      expect(out.last.kind, 'emergent_cluster:refusedToEat');
    });

    test('caps the list so the Home card stays readable', () {
      final List<CareApproach> items = <CareApproach>[
        for (final CareSituation s in CareSituation.values)
          ..._series(s, 3, hour: 19, outcome: ApproachOutcome.worked),
      ];
      final List<RiskSignal> out = detector.detect(items, now: _now);
      expect(out, hasLength(kMaxEmergentSignals));
    });

    test('the returned list is unmodifiable', () {
      final List<RiskSignal> out = detector.detect(
        _series(CareSituation.agitatedOrUpset, 3, hour: 19),
        now: _now,
      );
      expect(
        () => out.add(const RiskSignal(
            kind: 'x', level: RiskLevel.watch, title: 't', detail: 'd')),
        throwsUnsupportedError,
      );
    });

    test('every signal explains the count it fired on', () {
      final List<RiskSignal> out = detector.detect(
        _series(CareSituation.wantedToLeaveOrGoHome, 4, hour: 19),
        now: _now,
      );
      expect(out.single.detail, contains('4'));
      expect(out.single.detail, contains('${kEmergentWindow.inDays} days'));
    });
  });

  group('Daypart', () {
    test('splits the day at noon and 5pm', () {
      expect(Daypart.of(DateTime(2026, 7, 31, 11)), Daypart.morning);
      expect(Daypart.of(DateTime(2026, 7, 31, 12)), Daypart.afternoon);
      expect(Daypart.of(DateTime(2026, 7, 31, 16)), Daypart.afternoon);
      expect(Daypart.of(DateTime(2026, 7, 31, 17)), Daypart.evening);
    });
  });
}
