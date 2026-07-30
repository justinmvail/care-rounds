import 'package:carerounds/models/visit_note_draft.dart';
import 'package:flutter_test/flutter_test.dart';

/// The worker approves the note line by line, so observations have to ARRIVE
/// as lines. The prompt now asks for that — but the deployed model previously
/// returned one comma-joined sentence, and the parser has to keep handling it.
void main() {
  group('VisitNoteDraft.fromModelJson — observations become approvable lines',
      () {
    test('takes a list of observations as-is', () {
      final VisitNoteDraft d = VisitNoteDraft.fromModelJson(
        <String, dynamic>{
          'observations': <dynamic>['Ate most of breakfast', 'Seemed steady'],
        },
      );
      expect(d.observations, <String>['Ate most of breakfast', 'Seemed steady']);
    });

    test('splits the VERBATIM blob the deployed model returned', () {
      // Captured 2026-07-29 from the live run (cycle V1-routine).
      final VisitNoteDraft d = VisitNoteDraft.fromModelJson(<String, dynamic>{
        'observations': 'He was up and dressed already, ate most of his '
            'oatmeal, and was in a good mood, joking about the weather',
      });
      expect(d.observations.length, greaterThan(1),
          reason: 'a single blob cannot be approved or rejected in parts');
      expect(d.observations.first,
          'He was up and dressed already, ate most of his oatmeal');
      expect(d.observations.last, 'was in a good mood, joking about the weather');
    });

    test('splits on sentence ends and semicolons too', () {
      final VisitNoteDraft d = VisitNoteDraft.fromModelJson(<String, dynamic>{
        'observations': 'She ate well. She was steady; mood was good',
      });
      expect(d.observations,
          <String>['She ate well.', 'She was steady', 'mood was good']);
    });

    test('drops empties and tolerates a missing field', () {
      expect(
        VisitNoteDraft.fromModelJson(<String, dynamic>{'observations': '   '})
            .observations,
        isEmpty,
      );
      expect(VisitNoteDraft.fromModelJson(<String, dynamic>{}).observations,
          isEmpty);
      expect(
        VisitNoteDraft.fromModelJson(<String, dynamic>{
          'observations': <dynamic>['ok', '', 42],
        }).observations,
        <String>['ok'],
      );
    });

    test('an all-empty reply is still recognised as empty', () {
      expect(VisitNoteDraft.fromModelJson(<String, dynamic>{}).isEmpty, isTrue);
    });
  });
}
