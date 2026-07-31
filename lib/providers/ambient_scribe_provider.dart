import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/scribe.dart';
import '../services/sherpa_ambient_scribe.dart';
import 'photo_attacher_provider.dart' show useRealCapture;

part 'ambient_scribe_provider.g.dart';

/// Continuous, fully on-device visit transcription with voice separation —
/// the "scribe" mode a home-care nurse asked for so a long session does not
/// have to be reconstructed from memory at the end.
///
/// Behind an interface with a real impl and a fake, per the project's backend
/// invariant. The real impl ([SherpaAmbientScribe]) runs a streaming ASR model
/// on the handset: audio never leaves the device on either platform, which is
/// the whole point (see the dependency note in pubspec.yaml).
///
/// **Consent is enforced above this layer, not inside it.** The screen will not
/// call [start] without a [ScribeConsent]; keeping the engine ignorant of
/// consent means the engine can never be the thing that decides it is allowed
/// to listen.
abstract class AmbientScribe {
  /// True when this device can actually transcribe — the models are installed
  /// and the platform is supported. False makes the feature hide itself rather
  /// than fail mid-visit.
  Future<bool> get isAvailable;

  /// Begin listening. Emits attributed segments as speech is recognized.
  /// Emitting nothing is a valid outcome (a quiet visit).
  Stream<ScribeSegment> start();

  /// Stop listening and release the microphone. Safe to call when not started.
  Future<void> stop();
}

/// The stand-in used in tests, in demo mode, and on any device without models
/// installed. Reports unavailable and yields nothing, so every caller has to
/// handle the "cannot transcribe" path — which is the common case until models
/// ship.
class UnavailableAmbientScribe implements AmbientScribe {
  const UnavailableAmbientScribe();

  @override
  Future<bool> get isAvailable async => false;

  @override
  Stream<ScribeSegment> start() => const Stream<ScribeSegment>.empty();

  @override
  Future<void> stop() async {}
}

/// Replays a scripted session, so the session/consent/review flow is testable
/// without a microphone, a model, or a device.
class FakeAmbientScribe implements AmbientScribe {
  FakeAmbientScribe(this.segments, {this.available = true, this.gap});

  final List<ScribeSegment> segments;
  final bool available;

  /// Optional delay between segments, for tests that want to observe the
  /// transcript growing rather than arriving all at once.
  final Duration? gap;

  bool stopped = false;
  int started = 0;

  @override
  Future<bool> get isAvailable async => available;

  @override
  Stream<ScribeSegment> start() {
    started++;
    stopped = false;
    return Stream<ScribeSegment>.fromIterable(segments).asyncMap(
      (ScribeSegment s) async {
        if (gap != null) await Future<void>.delayed(gap!);
        return s;
      },
    );
  }

  @override
  Future<void> stop() async => stopped = true;
}

/// Pure selector, split out so both branches are unit-testable without
/// recompiling against the `USE_REAL_CAPTURE` dart-define.
AmbientScribe selectAmbientScribe(bool useReal) =>
    useReal ? SherpaAmbientScribe() : const UnavailableAmbientScribe();

@Riverpod(keepAlive: true)
AmbientScribe ambientScribe(Ref ref) => selectAmbientScribe(useRealCapture);
