// TFLite-based Scene Classifier

import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'ml_interfaces.dart';
import '../models/photo_models.dart';
import '../utils/image_utils.dart';

class TFLiteSceneClassifier implements SceneClassifier {
  Interpreter? _interpreter;
  bool _initialized = false;
  String? _error;
  
  static const List<String> _labels = [
    'indoor', 'outdoor', 'beach', 'mountain', 'city', 'forest',
    'sunset', 'night', 'snow', 'portrait', 'food', 'building',
    'water', 'desert', 'garden', 'parking', 'street', 'office',
  ];

  @override
  Future<List<SceneClassification>> classify(img.Image image) async {
    if (!_initialized) {
      await _initialize();
    }
    
    if (_interpreter == null) {
      return _heuristicClassify(image);
    }

    try {
      return await _classifyWithModel(image);
    } catch (e) {
      _error = e.toString();
      return _heuristicClassify(image);
    }
  }

  Future<void> _initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset('models/classification/scene_classifier.tflite');
      _initialized = true;
    } catch (e) {
      _error = e.toString();
      _initialized = true;
    }
  }

  Future<List<SceneClassification>> _classifyWithModel(img.Image image) async {
    // Resize to 224x224 and normalize
    final resized = img.copyResize(image, width: 224, height: 224);
    final input = _preprocessInput(resized);
    
    // Run inference
    final outputShape = [1, _labels.length];
    final output = List.filled(_labels.length, 0.0).reshape(outputShape);
    
    _interpreter!.run(input, output);
    
    final predictions = (output[0] as List<dynamic>).cast<double>();
    
    // Get top 5
    final indexedPredictions = predictions.asMap().entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return indexedPredictions.take(5).map((entry) {
      final idx = entry.key;
      final conf = entry.value;
      if (idx < _labels.length && conf > 0.01) {
        return SceneClassification(scene: _labels[idx], confidence: conf);
      }
      return null;
    }).whereType<SceneClassification>().toList();
  }

  List<List<List<List<double>>>> _preprocessInput(img.Image image) {
    final input = List.generate(1, (_) => 
      List.generate(224, (y) => 
        List.generate(224, (x) => 
          List.generate(3, (c) => 
            image.getPixel(x, y)[c] / 255.0
          )
        )
      )
    );
    return input;
  }

  List<SceneClassification> _heuristicClassify(img.Image image) {
    // Simplified heuristic based on color analysis
    final hsv = _rgbToHsv(image);
    final stats = _calculateColorStats(hsv);
    
    final scores = <String, double>{};
    for (final label in _labels) {
      scores[label] = 0.0;
    }
    
    // Simple brightness-based classification
    final brightness = stats['brightness'] ?? 0.0;
    final saturation = stats['saturation'] ?? 0.0;
    final blueRatio = stats['blueRatio'] ?? 0.0;
    final greenRatio = stats['greenRatio'] ?? 0.0;
    final skinRatio = stats['skinRatio'] ?? 0.0;
    
    if (brightness > 0.7) {
      scores['outdoor'] = (scores['outdoor'] ?? 0) + 1.0;
      scores['beach'] = (scores['beach'] ?? 0) + 0.5;
    } else if (brightness < 0.3) {
      scores['night'] = (scores['night'] ?? 0) + 1.5;
    }
    
    if (blueRatio > 0.2) {
      scores['beach'] = (scores['beach'] ?? 0) + 1.5;
      scores['water'] = (scores['water'] ?? 0) + 1.5;
    }
    
    if (greenRatio > 0.15) {
      scores['forest'] = (scores['forest'] ?? 0) + 1.5;
      scores['garden'] = (scores['garden'] ?? 0) + 1.0;
    }
    
    if (skinRatio > 0.1) {
      scores['portrait'] = (scores['portrait'] ?? 0) + 1.5;
    }
    
    // Sort and return top results
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted.take(5)
      .where((e) => e.value > 0.1)
      .map((e) => SceneClassification(scene: e.key, confidence: e.value.clamp(0.0, 1.0)))
      .toList();
  }

  Map<String, double> _rgbToHsv(img.Image image) {
    // Simplified - just return stats
    return _calculateColorStats({});
  }

  Map<String, double> _calculateColorStats(Map<String, dynamic> hsv) {
    // Simplified color analysis
    double rSum = 0, gSum = 0, bSum = 0;
    int count = 0;
    
    for (int y = 0; y < image.height; y += 4) {
      for (int x = 0; x < image.width; x += 4) {
        final p = image.getPixel(x, y);
        rSum += p.r;
        gSum += p.g;
        bSum += p.b;
        count++;
      }
    }
    
    final avgR = rSum / count;
    final avgG = gSum / count;
    final avgB = bSum / count;
    
    final brightness = (avgR + avgG + avgB) / (3 * 255);
    final saturation = ((avgR - avgG).abs() + (avgG - avgB).abs() + (avgB - avgR).abs()) / (3 * 255);
    
    final bluePixels = image.data.expand((p) => [p]).where((p) => p.b > p.r && p.b > p.g).length;
    final greenPixels = image.data.expand((p) => [p]).where((p) => p.g > p.r && p.g > p.b).length;
    final skinPixels = image.data.expand((p) => [p]).where((p) {
      final h = _rgbToHue(p.r, p.g, p.b);
      final s = _rgbToSaturation(p.r, p.g, p.b);
      return h >= 0 && h <= 25 && s > 0.3 && s < 0.9;
    }).length;
    
    return {
      'brightness': brightness,
      'saturation': saturation,
      'blueRatio': bluePixels / count,
      'greenRatio': greenPixels / count,
      'skinRatio': skinPixels / count,
    };
  }

  double _rgbToHue(int r, int g, int b) {
    final max = [r, g, b].reduce((a, b) => a > b ? a : b);
    final min = [r, g, b].reduce((a, b) => a < b ? a : b);
    final delta = max - min;
    
    if (delta == 0) return 0;
    
    double hue = 0;
    if (max == r) hue = 60 * (((g - b) / delta) % 6);
    else if (max == g) hue = 60 * (((b - r) / delta) + 2);
    else hue = 60 * (((r - g) / delta) + 4);
    
    return hue < 0 ? hue + 360 : hue;
  }

  double _rgbToSaturation(int r, int g, int b) {
    final max = [r, g, b].reduce((a, b) => a > b ? a : b);
    final min = [r, g, b].reduce((a, b) => a < b ? a : b);
    if (max == 0) return 0;
    return (max - min) / max;
  }

  @override
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _initialized = false;
  }
}