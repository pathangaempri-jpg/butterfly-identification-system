import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// A single class prediction from the on-device model.
class Classification {
  const Classification({required this.label, required this.confidence});

  /// Species name as written in labels.txt (output order).
  final String label;

  /// Softmax probability in [0, 1].
  final double confidence;
}

/// ─────────────────────────────────────────────────────────────────────────────
/// BUTTERFLY CLASSIFIER (on-device)
/// Runs a bundled TFLite model entirely on the phone — no network, no API quota.
/// Behind an interface so tests can stub it (the native runtime isn't available
/// on the Dart test VM).
/// ─────────────────────────────────────────────────────────────────────────────

abstract class IButterflyClassifier {
  /// True once the model + labels have loaded successfully.
  Future<bool> ensureLoaded();

  /// Top-[topK] predictions, highest confidence first. Throws
  /// [ClassifierUnavailable] if the model/labels couldn't be loaded.
  Future<List<Classification>> classify(File image, {int topK = 3});

  void dispose();
}

class ClassifierUnavailable implements Exception {
  ClassifierUnavailable([this.message = 'On-device model is not installed.']);
  final String message;
  @override
  String toString() => message;
}

class TFLiteButterflyClassifier implements IButterflyClassifier {
  TFLiteButterflyClassifier({
    this.modelAsset = 'assets/models/butterfly_model.tflite',
    this.labelsAsset = 'assets/models/labels.txt',
    this.inputSize = 224,
  });

  final String modelAsset;
  final String labelsAsset;
  final int inputSize;

  Interpreter? _interpreter;
  List<String> _labels = const [];
  bool _triedLoad = false;
  bool _loaded = false;

  @override
  Future<bool> ensureLoaded() async {
    if (_triedLoad) return _loaded;
    _triedLoad = true;
    try {
      _interpreter = await Interpreter.fromAsset(modelAsset);
      final raw = await rootBundle.loadString(labelsAsset);
      _labels = raw
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      _loaded = _interpreter != null && _labels.isNotEmpty;
    } catch (_) {
      _loaded = false;
    }
    return _loaded;
  }

  @override
  Future<List<Classification>> classify(File image, {int topK = 3}) async {
    if (!await ensureLoaded()) throw ClassifierUnavailable();
    final interpreter = _interpreter!;

    final input = _imageToInput(await image.readAsBytes());
    final output = [List<double>.filled(_labels.length, 0.0)];
    interpreter.run(input, output);

    final scores = output.first;
    final indices = List<int>.generate(scores.length, (i) => i)
      ..sort((a, b) => scores[b].compareTo(scores[a]));

    return [
      for (final i in indices.take(topK))
        Classification(label: _labels[i], confidence: scores[i]),
    ];
  }

  /// Decode → resize → build a [1, h, w, 3] float32 tensor of RAW RGB 0–255
  /// (the model graph does its own normalization).
  List<List<List<List<double>>>> _imageToInput(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw ClassifierUnavailable('Could not read image.');
    final resized =
        img.copyResize(decoded, width: inputSize, height: inputSize);

    return [
      List.generate(inputSize, (y) {
        return List.generate(inputSize, (x) {
          final p = resized.getPixel(x, y);
          return [p.r.toDouble(), p.g.toDouble(), p.b.toDouble()];
        });
      }),
    ];
  }

  @override
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
