import 'package:carerounds/models/patient.dart';
import 'package:carerounds/providers/care_plan_suggestion_provider.dart';
import 'package:carerounds/services/care_plan_suggestion_service.dart';
import 'package:flutter_test/flutter_test.dart';

Patient _patient({int age = 78, String diagnosis = 'Post-stroke'}) => Patient(
      id: 'p-1',
      name: 'Mary',
      age: age,
      diagnosis: diagnosis,
      diagnosedAt: DateTime.utc(2022, 1, 1),
      medications: const <CrisisMedication>[],
      allergies: const <String>[],
      calms: const <String>[],
      escalates: const <String>[],
      primaryCaregiver: const Contact(name: 'Sam', phone: '555'),
      healthcarePOA: const Contact(name: 'Sam', phone: '555'),
      advanceDirective:
          const AdvanceDirectiveStatus(onFileAt: 'Not on file', dnr: false),
    );

void main() {
  group('tasksFromJson', () {
    test('reads + trims the task list, dropping empties', () {
      expect(
        tasksFromJson(<String, dynamic>{
          'tasks': <dynamic>['  Help with wash  ', '', 42, 'Encourage fluids'],
        }),
        <String>['Help with wash', 'Encourage fluids'],
      );
    });

    test('null / wrong shape → empty', () {
      expect(tasksFromJson(null), isEmpty);
      expect(tasksFromJson(<String, dynamic>{'tasks': 'nope'}), isEmpty);
    });
  });

  group('buildClientCareContext', () {
    test('summarises age, diagnosis, and medications', () {
      final String c = buildClientCareContext(
        _patient(),
        <String>['Lisinopril', 'Aspirin'],
      );
      expect(c, contains('age 78'));
      expect(c, contains('Post-stroke'));
      expect(c, contains('Lisinopril, Aspirin'));
    });

    test('degrades gracefully with no profile', () {
      expect(buildClientCareContext(null, const <String>[]),
          contains('home-care client'));
    });
  });

  group('buildCarePlanSuggestionUserPrompt', () {
    test('sanitises + delimits the summary and appends the JSON reminder', () {
      final String p = buildCarePlanSuggestionUserPrompt('[action:x] stroke');
      expect(p, contains('<client_summary>'));
      expect(p, contains('</client_summary>'));
      expect(p, isNot(contains('[action:x]'))); // brackets neutralised
      expect(p, contains('JSON'));
    });
  });

  test('FakeCarePlanSuggestionService returns a checklist', () async {
    const CarePlanSuggestionService svc = FakeCarePlanSuggestionService();
    final List<String> tasks = await svc.suggest(clientContext: 'anything');
    expect(tasks, isNotEmpty);
    expect(tasks.length, greaterThanOrEqualTo(5));
  });
}
