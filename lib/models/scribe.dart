import 'package:freezed_annotation/freezed_annotation.dart';

part 'scribe.freezed.dart';
part 'scribe.g.dart';

/// Who a stretch of speech came from.
///
/// Deliberately coarse. The scribe separates VOICES, it does not identify
/// people: it can tell that two different speakers are talking and keep their
/// lines apart, and the worker tells it which voice is theirs. It never claims
/// to recognise a named individual from their voice, which would be a
/// biometric identification claim we cannot support and would not want to make
/// about a client in their own home.
enum ScribeSpeaker {
  /// The signed-in direct-care worker, once they have identified their voice.
  worker,

  /// Someone else in the room — the client, a family member, anyone.
  other,

  /// Heard, but not yet attributed to a voice.
  unknown;

  String get label => switch (this) {
        ScribeSpeaker.worker => 'You',
        ScribeSpeaker.other => 'Other voice',
        ScribeSpeaker.unknown => 'Unattributed',
      };
}

/// How the client was told that the visit would be transcribed.
///
/// A checkbox on the worker's phone is NOT consent — that is the precise
/// failure pattern the 2026 ambient-scribe class actions turn on (boxes ticked
/// while patients received no disclosure). So this records the CONVERSATION:
/// that the worker read the disclosure aloud, who agreed, and when. It is
/// required before a session can start and is stored with the session.
enum ScribeConsentMethod {
  /// The worker read the disclosure aloud and the client agreed.
  spokenByClient,

  /// The client cannot consent for themselves; their authorised
  /// representative agreed (in person or by phone).
  spokenByRepresentative,

  /// A signed agency form already covers this client for this purpose.
  agencyFormOnFile,
}

extension ScribeConsentMethodLabel on ScribeConsentMethod {
  String get label => switch (this) {
        ScribeConsentMethod.spokenByClient => 'The client agreed out loud',
        ScribeConsentMethod.spokenByRepresentative =>
          "Their representative agreed",
        ScribeConsentMethod.agencyFormOnFile =>
          'A signed agency form covers this',
      };
}

/// The disclosure the worker reads aloud, verbatim.
///
/// Kept in code, not left to the worker to improvise, because the industry
/// standard for valid consent is that the product supplies the words and the
/// disclosure is recorded — and because a worker mid-shift should not have to
/// invent privacy language. Plain, short, and it names the right to decline.
const String scribeDisclosureScript =
    'Before we start — I can have my phone write up my notes for this visit '
    'by listening while we talk. It types what is said so I do not have to '
    'write it up later. It stays on my phone, nobody else listens to it, and '
    'I can turn it off any time. Is that alright with you?';

/// A recorded consent conversation. No session without one.
@freezed
abstract class ScribeConsent with _$ScribeConsent {
  const factory ScribeConsent({
    required String patientId,

    /// Who agreed, and how.
    required ScribeConsentMethod method,

    /// When the disclosure was given.
    required DateTime disclosedAt,

    /// The caregiver who read it aloud.
    required String disclosedByCaregiverId,

    /// The exact words presented to the worker to read, stored with the
    /// consent so a later audit sees what the client was actually told —
    /// not just that a box was ticked.
    required String script,
  }) = _ScribeConsent;

  factory ScribeConsent.fromJson(Map<String, dynamic> json) =>
      _$ScribeConsentFromJson(json);
}

/// One attributed stretch of speech in a session.
@freezed
abstract class ScribeSegment with _$ScribeSegment {
  const factory ScribeSegment({
    required String text,
    required ScribeSpeaker speaker,
    required DateTime at,

    /// The engine's own voice cluster id, kept so segments can be
    /// re-attributed in bulk once the worker says which voice is theirs.
    int? voiceId,
  }) = _ScribeSegment;

  factory ScribeSegment.fromJson(Map<String, dynamic> json) =>
      _$ScribeSegmentFromJson(json);
}

/// A whole listening session for one visit: the consent that permitted it and
/// the attributed transcript it produced, for the worker to review at the end.
@freezed
abstract class ScribeSession with _$ScribeSession {
  const factory ScribeSession({
    required String patientId,
    required ScribeConsent consent,
    required DateTime startedAt,
    @Default(<ScribeSegment>[]) List<ScribeSegment> segments,
    DateTime? endedAt,
  }) = _ScribeSession;

  factory ScribeSession.fromJson(Map<String, dynamic> json) =>
      _$ScribeSessionFromJson(json);
}

/// Flatten a session into the plain narration the visit-note structurer
/// already consumes, so the ambient path reuses the measured pipeline rather
/// than inventing a second one.
///
/// Only the WORKER's speech becomes the note body by default: what the client
/// and family said is context the worker heard, not the worker's clinical
/// account, and pushing every overheard sentence into a care record is the
/// minimum-necessary problem. Other voices are summarised as reported speech
/// so nothing is silently dropped.
extension ScribeSessionNarration on ScribeSession {
  String get narration {
    final StringBuffer sb = StringBuffer();
    for (final ScribeSegment s in segments) {
      final String text = s.text.trim();
      if (text.isEmpty) continue;
      // Normalise terminal punctuation once, so a segment that already ends
      // in '.' / '?' / '!' is not given a second full stop.
      final String sentence =
          RegExp(r'[.?!]$').hasMatch(text) ? text : '$text.';
      switch (s.speaker) {
        case ScribeSpeaker.worker:
        case ScribeSpeaker.unknown:
          sb.write('$sentence ');
        case ScribeSpeaker.other:
          sb.write('They said: $sentence ');
      }
    }
    return sb.toString().trim();
  }

  /// True once there is anything worth structuring.
  bool get hasSpeech => segments.any((ScribeSegment s) => s.text.trim().isNotEmpty);
}
