import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/patient.dart';
import '../services/care_plan_suggestion_service.dart';
import '../services/forum_api_client.dart'
    show forumApiBaseUrl, forumBackendConfigured;
import 'forum_jwt_provider.dart' show forumSessionManagerProvider;
import 'llm_provider.dart' show useFakeLLMEngine;

/// Build-mode-selected [CarePlanSuggestionService] (Track-2 #19) — the same
/// selection contract as the scanners / visit-note service.
final carePlanSuggestionServiceProvider =
    Provider<CarePlanSuggestionService>((ref) {
  if (useFakeLLMEngine) return const FakeCarePlanSuggestionService();
  if (forumBackendConfigured) {
    return ApiCarePlanSuggestionService(
      baseUrl: forumApiBaseUrl,
      tokenLoader: ref.watch(forumSessionManagerProvider).currentToken,
    );
  }
  return const ShimCarePlanSuggestionService();
});

/// A short, grounding summary of a client for the care-plan suggestion prompt
/// — age, diagnosis, and the medications on file. Pure so it's testable and
/// so the exact text fed to the model stays inspectable.
String buildClientCareContext(Patient? patient, List<String> medicationNames) {
  final List<String> lines = <String>[];
  if (patient != null) {
    final List<String> who = <String>[
      if (patient.age > 0) 'age ${patient.age}',
      if (patient.diagnosis.trim().isNotEmpty) patient.diagnosis.trim(),
    ];
    if (who.isNotEmpty) lines.add('Client: ${who.join(', ')}.');
  }
  if (medicationNames.isNotEmpty) {
    lines.add('Medications on file: ${medicationNames.join(', ')}.');
  }
  if (lines.isEmpty) return 'A home-care client. No detailed profile on file.';
  return lines.join('\n');
}
