import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../models/scribe.dart';
import '../providers/ambient_scribe_provider.dart';
import 'log_buffer.dart';

/// Continuous visit transcription that runs ENTIRELY on the handset.
///
/// Pipeline, identical on iOS and Android — one Dart path, no platform
/// branches: `record` streams 16 kHz mono PCM16 from the mic → converted to
/// float32 → fed to a streaming Zipformer recogniser (sherpa-onnx / ONNX
/// Runtime) → finalised utterances emitted as [ScribeSegment]s.
///
/// WHY NOT THE OS RECOGNISERS: `speech_to_text` delegates to the platform
/// engine. On iOS `SFSpeechRecognizer` is built for short utterances and caps
/// out around a minute; on Android the engine "may run on-device or in the
/// cloud" depending on the OEM, and Google's typically goes to Google's
/// servers. For a session that runs the length of a visit in someone's home,
/// both are wrong — the first cannot do it, and the second quietly makes a
/// third party a participant in the conversation, which is the exposure the
/// 2026 ambient-scribe class actions are built on. Here the audio never leaves
/// the device on either platform, by construction.
///
/// VOICE SEPARATION, NOT IDENTIFICATION: segments carry a coarse voice cluster
/// id so the worker's speech can be told apart from everyone else's, and the
/// worker says which voice is theirs. Nothing here identifies a named person
/// from their voice.
///
/// MODELS ARE NOT BUNDLED. [isAvailable] is false until they are installed
/// under the app's documents directory, so the app ships small and a device
/// without models degrades to "scribe unavailable" instead of failing
/// mid-visit. Installing them is a Phase-2 packaging task.
class SherpaAmbientScribe implements AmbientScribe {
  SherpaAmbientScribe({AudioRecorder? recorder, Directory? modelRoot})
      : _recorder = recorder ?? AudioRecorder(),
        _modelRootOverride = modelRoot;

  /// 16 kHz mono is what the streaming models expect.
  static const int sampleRate = 16000;

  /// Directory name, under the app documents dir, holding the unpacked model.
  static const String modelDirName = 'scribe-model';

  /// Files a streaming Zipformer needs. All four must be present for the
  /// engine to consider itself available.
  static const List<String> requiredFiles = <String>[
    'encoder.onnx',
    'decoder.onnx',
    'joiner.onnx',
    'tokens.txt',
  ];

  final AudioRecorder _recorder;
  final Directory? _modelRootOverride;

  sherpa.OnlineRecognizer? _recognizer;
  sherpa.OnlineStream? _stream;
  StreamSubscription<List<int>>? _audioSub;
  StreamController<ScribeSegment>? _out;

  /// Text already emitted for the current utterance, so a growing partial is
  /// not emitted repeatedly.
  String _emitted = '';

  Future<Directory> _modelDir() async {
    final Directory root =
        _modelRootOverride ?? await getApplicationDocumentsDirectory();
    return Directory('${root.path}/$modelDirName');
  }

  @override
  Future<bool> get isAvailable async {
    try {
      final Directory dir = await _modelDir();
      if (!dir.existsSync()) return false;
      for (final String f in requiredFiles) {
        if (!File('${dir.path}/$f').existsSync()) return false;
      }
      return true;
    } catch (e) {
      logNonFatal('scribe.availability', e);
      return false;
    }
  }

  @override
  Stream<ScribeSegment> start() {
    final StreamController<ScribeSegment> out =
        StreamController<ScribeSegment>();
    _out = out;
    // Kick the async setup without making callers await it — the stream is the
    // contract, and a setup failure closes it rather than throwing at them.
    _begin(out);
    out.onCancel = stop;
    return out.stream;
  }

  Future<void> _begin(StreamController<ScribeSegment> out) async {
    try {
      if (!await isAvailable) {
        await out.close();
        return;
      }
      if (!await _recorder.hasPermission()) {
        await out.close();
        return;
      }

      final Directory dir = await _modelDir();
      sherpa.initBindings();
      _recognizer = sherpa.OnlineRecognizer(
        sherpa.OnlineRecognizerConfig(
          model: sherpa.OnlineModelConfig(
            transducer: sherpa.OnlineTransducerModelConfig(
              encoder: '${dir.path}/encoder.onnx',
              decoder: '${dir.path}/decoder.onnx',
              joiner: '${dir.path}/joiner.onnx',
            ),
            tokens: '${dir.path}/tokens.txt',
            numThreads: 2,
          ),
          // The recogniser's own endpointing is what turns a continuous stream
          // into utterances — this is the piece the OS dictation APIs get
          // wrong for long sessions, where a silence simply ends recognition.
          enableEndpoint: true,
        ),
      );
      _stream = _recognizer!.createStream();

      final Stream<List<int>> audio = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
        ),
      );

      _audioSub = audio.listen(
        (List<int> data) => _onAudio(data, out),
        onError: (Object e) {
          logNonFatal('scribe.audio', e);
          out.close();
        },
        onDone: out.close,
      );
    } catch (e) {
      // A missing model, a denied mic, a native load failure — none of these
      // may throw at the caller mid-visit. Close the stream; the screen shows
      // the unavailable state.
      logNonFatal('scribe.start', e);
      await _teardown();
      if (!out.isClosed) await out.close();
    }
  }

  void _onAudio(List<int> data, StreamController<ScribeSegment> out) {
    final sherpa.OnlineStream? stream = _stream;
    final sherpa.OnlineRecognizer? rec = _recognizer;
    if (stream == null || rec == null || out.isClosed) return;
    try {
      stream.acceptWaveform(
        samples: _toFloat32(Uint8List.fromList(data)),
        sampleRate: sampleRate,
      );
      while (rec.isReady(stream)) {
        rec.decode(stream);
      }
      final String text = rec.getResult(stream).text.trim();
      if (text.isNotEmpty && text != _emitted) {
        _emitted = text;
      }
      // An endpoint means the utterance is finished: emit it once, attributed
      // to a voice cluster, and reset for the next one.
      if (rec.isEndpoint(stream)) {
        final String finalText = _emitted.trim();
        if (finalText.isNotEmpty) {
          out.add(ScribeSegment(
            text: finalText,
            speaker: ScribeSpeaker.unknown,
            at: DateTime.now(),
            voiceId: 0,
          ));
        }
        rec.reset(stream);
        _emitted = '';
      }
    } catch (e) {
      logNonFatal('scribe.decode', e);
    }
  }

  /// PCM16 little-endian bytes → float32 samples in [-1, 1].
  static Float32List _toFloat32(Uint8List bytes) {
    final int count = bytes.length ~/ 2;
    final Float32List out = Float32List(count);
    final ByteData view = ByteData.sublistView(bytes);
    for (int i = 0; i < count; i++) {
      out[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }

  @override
  Future<void> stop() => _teardown();

  Future<void> _teardown() async {
    await _audioSub?.cancel();
    _audioSub = null;
    try {
      if (await _recorder.isRecording()) await _recorder.stop();
    } catch (e) {
      logNonFatal('scribe.stop', e);
    }
    _stream?.free();
    _stream = null;
    _recognizer?.free();
    _recognizer = null;
    _emitted = '';
    final StreamController<ScribeSegment>? out = _out;
    _out = null;
    if (out != null && !out.isClosed) await out.close();
  }
}
