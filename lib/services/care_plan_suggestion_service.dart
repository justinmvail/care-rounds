import 'package:dio/dio.dart';

import '../seed/care_plan_suggestion_prompt.dart';
import 'chat_context_builder.dart' show sanitizeForPrompt;
import 'document_scan_transport.dart';

/// AI-guided care-plan checklist (Track-2 #19). Given a short summary of a
/// client's situation, proposes a checklist of concrete care tasks the worker
/// reviews and selects from before any routine is created. It only suggests
/// practical, in-scope care tasks — no diagnosis, no dosing (see
/// [carePlanSuggestionSystemPrompt]).
///
/// Behind an interface with a fake (tests/demo) + real (dev shim / prod
/// Worker) impls, sharing the text→JSON transport in [document_scan_transport]
/// with the other grounded coach features.
abstract class CarePlanSuggestionService {
  /// Suggest care tasks for a client summarized by [clientContext]; a
  /// best-effort list, or an empty list on failure (the worker can still add
  /// routines by hand). MUST NOT throw for an ordinary failure.
  Future<List<String>> suggest({required String clientContext});
}

/// The user turn: the client summary, sanitized + delimited like every other
/// free-text interpolation into an LLM prompt, then the shared JSON reminder.
String buildCarePlanSuggestionUserPrompt(String clientContext) =>
    '<client_summary>\n${sanitizeForPrompt(clientContext.trim())}\n'
    '</client_summary>\n\nSuggest the care-task checklist as JSON.'
    '$scanJsonOnlyInstruction';

/// Pull the task list out of the model's `{ "tasks": [...] }` reply.
List<String> tasksFromJson(Map<String, dynamic>? map) {
  final Object? raw = map?['tasks'];
  if (raw is! List) return const <String>[];
  return <String>[
    for (final Object? e in raw)
      if (e is String && e.trim().isNotEmpty) e.trim(),
  ];
}

/// Deterministic fake for tests / demo / any `USE_FAKE_LLM=true` build.
class FakeCarePlanSuggestionService implements CarePlanSuggestionService {
  const FakeCarePlanSuggestionService();

  @override
  Future<List<String>> suggest({required String clientContext}) async =>
      const <String>[
        'Help with morning wash and dressing',
        'Encourage fluids through the visit',
        'Remind and observe morning medications',
        'Support a short walk with the walker',
        'Prepare a light breakfast',
        'Tidy the bedside and check for trip hazards',
      ];
}

/// Dev-mode service backed by the local `claude` shim `/extract` route.
class ShimCarePlanSuggestionService implements CarePlanSuggestionService {
  const ShimCarePlanSuggestionService();

  @override
  Future<List<String>> suggest({required String clientContext}) async {
    final Map<String, dynamic>? map = await shimObjectFromPrompt(
      systemPrompt: carePlanSuggestionSystemPrompt,
      userPrompt: buildCarePlanSuggestionUserPrompt(clientContext),
    );
    return tasksFromJson(map);
  }
}

/// Production service routed through the Cloudflare Worker `/extract` route.
class ApiCarePlanSuggestionService implements CarePlanSuggestionService {
  ApiCarePlanSuggestionService({
    required this.baseUrl,
    required this.tokenLoader,
    this.dio,
  });

  final String baseUrl;
  final Future<String> Function() tokenLoader;
  final Dio? dio;

  @override
  Future<List<String>> suggest({required String clientContext}) async {
    final Map<String, dynamic>? map = await workerObjectFromPrompt(
      systemPrompt: carePlanSuggestionSystemPrompt,
      userPrompt: buildCarePlanSuggestionUserPrompt(clientContext),
      baseUrl: baseUrl,
      tokenLoader: tokenLoader,
      dio: dio,
    );
    return tasksFromJson(map);
  }
}
