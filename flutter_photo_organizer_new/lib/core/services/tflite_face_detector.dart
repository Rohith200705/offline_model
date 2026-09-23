// TFLite-based Face Detector using UltraFace model

import 'dart:math' as math;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'ml_interfaces.dart';
import '../models/photo_models.dart';

class TFLiteFaceDetector implements FaceDetector {
  Interpreter? _interpreter;
  bool _initialized = false;
  String? _error;

  @override
  Future<List<FaceDetection>> detectFaces(img.Image image) async {
    if (!_initialized) {
      await _initialize();
    }

    if (_interpreter == null) {
      return _detectSkinColor(image);
    }

    try {
      return await _detectWithUltraFace(image);
    } catch (e) {
      _error = e.toString();
      return _detectSkinColor(image);
    }
  }

  Future<void> _initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset('models/face/ultraface.tflite');
      _initialized = true;
    } catch (e) {
      _error = e.toString();
      _initialized = true;
    }
  }

  Future<List<FaceDetection>> _detectWithUltraFace(img.Image image) async {
    const inputWidth = 320;
    const inputHeight = 240;

    final resized = img.copyResize(image, width: inputWidth, height: inputHeight);

    // NHWC input [1, 240, 320, 3]
    final input = [
      List.generate(inputHeight, (y) {
        return List.generate(inputWidth, (x) {
          final p = resized.getPixel(x, y);
          return [
            (p.r - 127.0) / 128.0,
            (p.g - 127.0) / 128.0,
            (p.b - 127.0) / 128.0,
          ];
        });
      })
    ];

    // Outputs: scores [1, 4420, 2], boxes [1, 4420, 4]
    final scoresOut = [
      List.generate(4420, (_) => <double>[0.0, 0.0])
    ];
    final boxesOut = [
      List.generate(4420, (_) => <double>[0.0, 0.0, 0.0, 0.0])
    ];

    _interpreter!.runForMultipleInputs([input], {
      0: scoresOut,
      1: boxesOut,
    });

    final scores = scoresOut[0];
    final boxes = boxesOut[0];

    return _postProcess(scores, boxes, image.width, image.height);
  }

  List<FaceDetection> _postProcess(
    List<List<double>> scores,
    List<List<double>> boxes,
    int origW,
    int origH,
  ) {
    final faces = <FaceDetection>[];
    const scoreThreshold = 0.5;
    const nmsThreshold = 0.4;

    final validBoxes = <List<double>>[];
    final validScores = <double>[];

    for (int i = 0; i < scores.length; i++) {
      if (scores[i].length > 1 && scores[i][1] > scoreThreshold) {
        validBoxes.add(boxes[i]);
        validScores.add(scores[i][1]);
      }
    }

    if (validBoxes.isEmpty) {
      return _detectSkinColor(null);
    }

    final keepIndices = _nms(validBoxes, validScores, nmsThreshold);

    for (final idx in keepIndices) {
      final box = validBoxes[idx];
      final x1 = (box[0] * origW).round();
      final y1 = (box[1] * origH).round();
      final x2 = (box[2] * origW).round();
      final y2 = (box[3] * origH).round();

      final padX = ((x2 - x1) * 0.1).round();
      final padY = ((y2 - y1) * 0.15).round();
      final fx1 = (x1 - padX).clamp(0, origW);
      final fy1 = (y1 - padY).clamp(0, origH);
      final fx2 = (x2 + padX).clamp(0, origW);
      final fy2 = (y2 + padY).clamp(0, origH);

      faces.add(FaceDetection(
        bbox: [fx1, fy1, fx2, fy2],
        confidence: validScores[idx],
        name: 'unknown',
      ));
    }

    return faces.take(5).toList();
  }

  List<int> _nms(List<List<double>> boxes, List<double> scores, double threshold) {
    final indices = List.generate(boxes.length, (i) => i);
    indices.sort((a, b) => scores[b].compareTo(scores[a]));

    final keep = <int>[];
    final suppressed = List.filled(indices.length, false);

    for (int i = 0; i < indices.length; i++) {
      if (suppressed[i]) continue;
      keep.add(indices[i]);

      for (int j = i + 1; j < indices.length; j++) {
        if (suppressed[j]) continue;
        if (_iou(boxes[indices[i]], boxes[indices[j]]) > threshold) {
          suppressed[j] = true;
        }
      }
    }

    return keep;
  }

  double _iou(List<double> box1, List<double> box2) {
    final x1 = math.max(box1[0], box2[0]);
    final y1 = math.max(box1[1], box2[1]);
    final x2 = math.min(box1[2], box2[2]);
    final y2 = math.min(box1[3], box2[3]);

    final interW = (x2 - x1).clamp(0.0, double.infinity);
    final interH = (y2 - y1).clamp(0.0, double.infinity);
    final inter = interW * interH;
    final area1 = (box1[2] - box1[0]) * (box1[3] - box1[1]);
    final area2 = (box2[2] - box2[0]) * (box2[3] - box2[1]);

    final total = area1 + area2 - inter;
    if (total <= 0) return 0.0;
    return inter / total;
  }

  List<FaceDetection> _detectSkinColor(img.Image? image) {
    if (image == null) return [];

    // Sample-based skin color heuristic for fallback
    final faces = <FaceDetection>[];
    const blockSize = 40;
    final skinCounts = <String, int>{};

    for (int y = 0; y + blockSize <= image.height; y += blockSize) {
      for (int x = 0; x + blockSize <= image.width; x += blockSize) {
        int skin = 0;
        int total = 0;
        for (int dy = 0; dy < blockSize; dy += 4) {
          for (int dx = 0; dx < blockSize; dx += 4) {
            final p = image.getPixel(x + dx, y + dy);
            final r = p.r.toDouble();
            final g = p.g.toDouble();
            final b = p.b.toDouble();
            total++;
            if (r > 95 && g > 40 && b > 20 &&
                r > g && r > b &&
                (r - math.min(g, b)) > 15 &&
                r < 250) {
              skin++;
            }
          }
        }
        if (total > 0 && skin / total > 0.4) {
          final key = '$x,$y';
          skinCounts[key] = skin;
          faces.add(FaceDetection(
            bbox: [x, y, x + blockSize, y + blockSize],
            confidence: (skin / total).clamp(0.0, 1.0),
            name: 'unknown',
          ));
        }
      }
    }

    // Merge nearby detections crudely: keep top 5 by confidence
    faces.sort((a, b) => b.confidence.compareTo(a.confidence));
    return faces.take(5).toList();
  }

  @override
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _initialized = false;
  }
}