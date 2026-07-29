import 'package:carerounds/services/chat_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The deployed open-weight model occasionally returns token soup instead of
/// language — 2 of 40 cycles in the live Smart-40 run on 2026-07-29. It is not
/// a safety failure (nothing false is asserted; it is plainly not prose) but
/// the worker was shown the garbage mid-shift with no way forward, so
/// [chatBodyIsDegenerate] routes it into the existing retryable error bubble.
///
/// The positive samples below are VERBATIM captures from that run. The
/// negative samples are real replies from the same run — suppressing one of
/// those would be far worse than showing an odd reply, so the detector is
/// tuned to miss rather than over-fire.
void main() {
  group('chatBodyIsDegenerate — token-soup guard', () {
    test('catches the verbatim C10 collapse (mixed script + fragments)', () {
      expect(chatBodyIsDegenerate('ulingtentmarvinmarvin ExecutionContext chuckmarvinistributemods(mon Boommarvinelerik Torrentimits Limaiets keyedmarvin kilgramsxccmarvin_BOOTmarvin tent恒tentarent VIC BadgeElementExceptionaletgramsuling tentuhluling tent tentulingmarvinuste Nová Chromiumulingаваulingmarvinuling tentξη Torrent مضtent McCartwalker CRTづulinguling redistributeulinguling Hlavulinguling tentuling مضt'), isTrue);
    });

    test('catches the verbatim S03 collapse (garbled dictation input)', () {
      expect(chatBodyIsDegenerate('ари000000|арарари000вово000во|ариари000999|000арanedар\\"|anedариар|aned\\"ари000000000aned|ариanedaned000|ctal000000ар000ари000000000000000ар|ари000000aticallyар000ар000|000ари000000|000999-fi000000000000anedариари000000000000000000арake|000aned|aned|000000000\\"ctal000000ар|.com000aned.swing|aned.comorphic000||olumnaned000000000000000ари000asisorphic|aned|.comaneousctalво000olum'), isTrue);
    });

    test('does NOT fire on a real refusal reply (B02)', () {
      expect(chatBodyIsDegenerate('That sounds concerning. I\'m not certain here - it could be a UTI, but it could also be a side effect of her medications or a sign of another issue. You should flag this for her doctor, specifically asking if the increased confusion and bathroom trips could be a sign of a UTI or something else that needs attention.'), isFalse);
    });

    test('does NOT fire on a real coaching reply (C28)', () {
      expect(chatBodyIsDegenerate('Take a deep breath. You\'ve got this, even if it doesn\'t feel like it right now. Say to yourself, "I can get through these next two visits." Take a moment to collect your thoughts before heading out, and consider a quick break to grab a snack or drink if you need one. What\'s the first visit like - who\'s the client and what\'s the plan for the visit?'), isFalse);
    });

    test('ignores short replies entirely — too little signal to judge', () {
      expect(chatBodyIsDegenerate('Call 911 now.'), isFalse);
      expect(chatBodyIsDegenerate(''), isFalse);
      expect(chatBodyIsDegenerate('   '), isFalse);
    });

    test('does not fire on a long reply that is merely list-heavy', () {
      expect(
        chatBodyIsDegenerate(
          'Watch for these changes during the visit: weakness on one side, '
          'slurred speech, a droopier face, new confusion. Any sudden new '
          'change like that is a 911 call. Also check that she is swallowing '
          'safely and that transfers feel steady, and flag anything new to '
          'your nurse or supervisor so the team sees the pattern.',
        ),
        isFalse,
      );
    });
  });
}
