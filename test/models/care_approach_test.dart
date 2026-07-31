import 'package:carerounds/models/care_approach.dart';
import 'package:flutter_test/flutter_test.dart';

CareApproach _a(
  CareSituation s,
  String tried,
  ApproachOutcome o, {
  DateTime? at,
}) =>
    CareApproach(
      id: 'x${tried.hashCode}',
      patientId: 'p1',
      situation: s,
      tried: tried,
      outcome: o,
      at: at ?? DateTime(2026, 7, 20),
    );

/// The briefing a worker (or the coach) reads mid-visit. It has one job: put
/// the thing that has actually worked with THIS person in front of whoever is
/// in the room now — including the aide covering a shift for the first time.
void main() {
  group('summarizeApproaches', () {
    test('is empty when nothing has been recorded', () {
      expect(summarizeApproaches(const <CareApproach>[]), isEmpty);
    });

    test('ranks what WORKED ahead of what did not, within a situation', () {
      final List<String> out = summarizeApproaches(<CareApproach>[
        _a(CareSituation.resistedPersonalCare, 'argued with her',
            ApproachOutcome.didNotWork),
        _a(CareSituation.resistedPersonalCare, 'warmed the towels first',
            ApproachOutcome.worked),
      ]);
      expect(out, hasLength(1));
      expect(out.single, startsWith('Resisted personal care: '));
      expect(
        out.single.indexOf('warmed the towels'),
        lessThan(out.single.indexOf('argued with her')),
        reason: 'the thing that worked must be read first',
      );
    });

    test('breaks ties by recency, newest first', () {
      final List<String> out = summarizeApproaches(<CareApproach>[
        _a(CareSituation.agitatedOrUpset, 'older idea', ApproachOutcome.worked,
            at: DateTime(2026, 7, 1)),
        _a(CareSituation.agitatedOrUpset, 'newer idea', ApproachOutcome.worked,
            at: DateTime(2026, 7, 25)),
      ]);
      expect(out.single.indexOf('newer idea'),
          lessThan(out.single.indexOf('older idea')));
    });

    test('caps each situation so a long history stays readable mid-visit', () {
      final List<String> out = summarizeApproaches(<CareApproach>[
        for (int i = 0; i < 6; i++)
          _a(CareSituation.refusedToEat, 'idea $i', ApproachOutcome.worked,
              at: DateTime(2026, 7, i + 1)),
      ]);
      // Three shown; the rest stay on the screen rather than in the briefing.
      expect(RegExp(r'idea \d').allMatches(out.single).length, 3);
    });

    test('groups by situation and keeps the enum order stable', () {
      final List<String> out = summarizeApproaches(<CareApproach>[
        _a(CareSituation.refusedMedication, 'came back later',
            ApproachOutcome.worked),
        _a(CareSituation.resistedPersonalCare, 'warmed towels',
            ApproachOutcome.worked),
      ]);
      expect(out, hasLength(2));
      expect(out.first, startsWith('Resisted personal care'));
      expect(out.last, startsWith('Refused medication'));
    });

    test('carries the outcome so a reader is never misled about what happened',
        () {
      final List<String> out = summarizeApproaches(<CareApproach>[
        _a(CareSituation.wantedToLeaveOrGoHome, 'told her she lives here',
            ApproachOutcome.didNotWork),
      ]);
      expect(out.single, contains("didn't work"));
    });
  });

  group('CareApproach round-trips through JSON', () {
    test('survives serialisation, including the enums', () {
      final CareApproach a = _a(CareSituation.upAtNightOrRestless,
          'left the hall light on', ApproachOutcome.partly);
      expect(CareApproach.fromJson(a.toJson()), a);
    });
  });
}
