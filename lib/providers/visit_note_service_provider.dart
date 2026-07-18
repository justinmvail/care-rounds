import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/forum_api_client.dart'
    show forumApiBaseUrl, forumBackendConfigured;
import '../services/visit_note_service.dart';
import 'forum_jwt_provider.dart' show forumSessionManagerProvider;
import 'llm_provider.dart' show useFakeLLMEngine;

/// Build-mode-selected [VisitNoteService] (Track-2 #16) — deterministic fake
/// under test/demo, local shim in dev, Worker in a shipped build. Same
/// selection contract as the scanners.
final visitNoteServiceProvider = Provider<VisitNoteService>((ref) {
  if (useFakeLLMEngine) return const FakeVisitNoteService();
  if (forumBackendConfigured) {
    return ApiVisitNoteService(
      baseUrl: forumApiBaseUrl,
      tokenLoader: ref.watch(forumSessionManagerProvider).currentToken,
    );
  }
  return const ShimVisitNoteService();
});
