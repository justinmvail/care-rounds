import 'package:dio/dio.dart';

import '../models/visit_note_draft.dart';
import '../seed/visit_note_prompt.dart';
import 'chat_context_builder.dart' show sanitizeForPrompt;
import 'document_scan_transport.dart';

/// Ambient visit documentation (Track-2 #16, the flagship) — "the note that
/// writes itself". Takes a worker's free-form spoken/typed account of a
/// visit and STRUCTURES it into a [VisitNoteDraft] the worker reviews and
/// saves. It only reorganises what the worker said; it never diagnoses,
/// doses, or invents (see [visitNoteSystemPrompt]).
///
/// Behind an interface with a fake (tests/demo) + real (dev shim / prod
/// Worker) impls, sharing the text→JSON transport in
/// [document_scan_transport] with the other grounded coach features.
abstract class VisitNoteService {
  /// Structure [transcript] into a draft note; a best-effort result, or null
  /// on failure (the caller keeps the raw transcript so nothing is lost).
  /// MUST NOT throw for an ordinary failure.
  Future<VisitNoteDraft?> structure({required String transcript});
}

/// The user turn: the worker's account, sanitised + delimited exactly like
/// every other free-text interpolation into an LLM prompt (defence in depth
/// with [sanitizeForPrompt] — a crafted "ignore previous instructions"
/// reaches the model as inert data), then the shared JSON-only reminder.
String buildVisitNoteUserPrompt(String transcript) =>
    '<visit_account>\n${sanitizeForPrompt(transcript.trim())}\n</visit_account>'
    '\n\nWrite the visit note as JSON.$scanJsonOnlyInstruction';

/// Deterministic fake for tests / demo / any `USE_FAKE_LLM=true` build.
class FakeVisitNoteService implements VisitNoteService {
  const FakeVisitNoteService();

  @override
  Future<VisitNoteDraft?> structure({required String transcript}) async {
    if (transcript.trim().isEmpty) return null;
    return const VisitNoteDraft(
      summary: 'Morning visit — steady and in good spirits',
      observations:
          'Client was alert and cooperative. Ate most of breakfast and '
          'walked to the kitchen with the walker without trouble.',
      tasksDone: <String>[
        'Gave 8:00 AM medications',
        'Helped with shower and dressing',
        'Prepared breakfast',
      ],
      concern: 'Left ankle looked a little swollen — worth keeping an eye on.',
      needsAttention: false,
    );
  }
}

/// Dev-mode service backed by the local `claude` shim `/extract` route.
class ShimVisitNoteService implements VisitNoteService {
  const ShimVisitNoteService();

  @override
  Future<VisitNoteDraft?> structure({required String transcript}) async {
    if (transcript.trim().isEmpty) return null;
    final Map<String, dynamic>? map = await shimObjectFromPrompt(
      systemPrompt: visitNoteSystemPrompt,
      userPrompt: buildVisitNoteUserPrompt(transcript),
    );
    return map == null ? null : VisitNoteDraft.fromModelJson(map);
  }
}

/// Production service routed through the Cloudflare Worker `/extract` route
/// (bearer session token). Selected only when a `FORUM_API_URL` is baked in.
class ApiVisitNoteService implements VisitNoteService {
  ApiVisitNoteService({
    required this.baseUrl,
    required this.tokenLoader,
    this.dio,
  });

  final String baseUrl;
  final Future<String> Function() tokenLoader;
  final Dio? dio;

  @override
  Future<VisitNoteDraft?> structure({required String transcript}) async {
    if (transcript.trim().isEmpty) return null;
    final Map<String, dynamic>? map = await workerObjectFromPrompt(
      systemPrompt: visitNoteSystemPrompt,
      userPrompt: buildVisitNoteUserPrompt(transcript),
      baseUrl: baseUrl,
      tokenLoader: tokenLoader,
      dio: dio,
    );
    return map == null ? null : VisitNoteDraft.fromModelJson(map);
  }
}
