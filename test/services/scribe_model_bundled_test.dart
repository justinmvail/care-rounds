import 'package:carerounds/services/sherpa_ambient_scribe.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The scribe transcribes ON THE HANDSET, which is only true if the model
/// actually ships inside the app. If these assets ever fall out of pubspec, the
/// feature silently stops working on a real device while every other test stays
/// green — and the packet's on-device privacy claim becomes false.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every file the recognizer needs is bundled and loadable', () async {
    for (final String name in SherpaAmbientScribe.requiredFiles) {
      final ByteData data =
          await rootBundle.load('${SherpaAmbientScribe.assetDir}/$name');
      expect(data.lengthInBytes, greaterThan(0), reason: '$name is empty');
    }
  });

  test('the encoder is the real model, not a placeholder or an LFS pointer',
      () async {
    final ByteData enc = await rootBundle
        .load('${SherpaAmbientScribe.assetDir}/encoder.onnx');
    // The int8 encoder is ~41 MB. A truncated download or a git-lfs stub would
    // be kilobytes and would fail only on a device, mid-visit.
    expect(enc.lengthInBytes, greaterThan(20 * 1024 * 1024));
    // ONNX is protobuf carrying the producer string "onnx".
    final String head = String.fromCharCodes(
        enc.buffer.asUint8List(enc.offsetInBytes, 32));
    expect(head.contains('onnx'), isTrue, reason: 'not an ONNX graph');
  });

  test('the token table is the vocabulary the model was trained with',
      () async {
    final String tokens = await rootBundle
        .loadString('${SherpaAmbientScribe.assetDir}/tokens.txt');
    final List<String> lines =
        tokens.split('\n').where((String l) => l.trim().isNotEmpty).toList();
    expect(lines.length, greaterThan(400));
    expect(lines.first, startsWith('<blk>'),
        reason: 'a transducer vocabulary starts with the blank symbol');
  });
}
