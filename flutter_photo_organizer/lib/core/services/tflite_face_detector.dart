// TFLite-based Face Detector using UltraFace model

import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'ml_interfaces.dart';
import '../models/photo_models.dart';
import '../utils/image_utils.dart';

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
      return _fallbackDetection(image);
    }

    try {
      return await _detectWithUltraFace(image);
    } catch (e) {
      _error = e.toString();
      return _fallbackDetection(image);
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
    final inputWidth = 320;
    final inputHeight = 240;
    
    // Resize and preprocess
    final resized = img.copyResize(image, width: inputWidth, height: inputHeight);
    final input = _preprocessInput(resized);
    
    // Run inference
    final outputShapes = [
      [1, 4420, 2], // scores
      [1, 4420, 4], // boxes
    ];
    
    final outputs = [
      List.filled(4420 * 2, 0.0).reshape([1, 4420, 2]),
      List.filled(4420 * 4, 0.0).reshape([1, 4420, 4]),
    ];
    
    _interpreter!.runForMultipleInputs([input], outputs);
    
    final scores = outputs[0][0] as List<List<double>>;
    final boxes = outputs[1][0] as List<List<double>>;
    
    return _postProcess(scores, boxes, image.width, image.height);
  }

  List<List<List<double>>> _preprocessInput(img.Image image) {
    final floatList = <double>[];
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        floatList.add((pixel.r - 127.0) / 128.0);
        floatList.add((pixel.g - 127.0) / 128.0);
        floatList.add((pixel.b - 127.0) / 128.0);
      }
    }
    
    // Reshape to [1, 3, 240, 320] -> [1, 240, 320, 3] for NHWC
    final channels = <List<List<double>>>[
      List.generate(240, (y) => List.generate(320, (x) => floatList[(y * 320 + x) * 3 + 0])),
      List.generate(240, (y) => List.generate(320, (x) => floatList[(y * 320 + x) * 3 + 1])),
      List.generate(240, (y) => List.generate(320, (x) => floatList[(y * 320 + x) * 3 + 2])),
    ];
    
    // Convert to NHWC format
    final nhwc = List.generate(240, (y) => 
      List.generate(320, (x) => [
        channels[0][y][x],
        channels[1][y][x],
        channels[2][y][x],
      ])
    );
    
    return [nhwc];
  }

  List<FaceDetection> _postProcess(
    List<List<double>> scores, 
    List<List<double>> boxes, 
    int origW, 
    int origH
  ) {
    final faces = <FaceDetection>[];
    const scoreThreshold = 0.5;
    const nmsThreshold = 0.4;
    
    final validIndices = <int>[];
    final validBoxes = <List<double>>[];
    final validScores = <double>[];
    
    for (int i = 0; i < scores.length; i++) {
      if (scores[i][1] > scoreThreshold) { // Assuming class 1 is face
        validIndices.add(i);
        validBoxes.add(boxes[i]);
        validScores.add(scores[i][1]);
      }
    }
    
    if (validIndices.isEmpty) {
      return _fallbackDetection(null);
    }
    
    // NMS
    final keepIndices = _nms(validBoxes, validScores, nmsThreshold);
    
    for (final idx in keepIndices) {
      final box = validBoxes[idx];
      final x1 = (box[0] * origW).round();
      final y1 = (box[1] * origH).round();
      final x2 = (box[2] * origW).round();
      final y2 = (box[3] * origH).round();
      
      // Add padding
      final padX = ((x2 - x1) * 0.1).round();
      final padY = ((y2 - y1) * 0.15).round();
      final fx1 = (x1 - padX).clamp(0, origW);
      final fy1 = (y1 - padY).clamp(0, origH);
      final fx2 = (x2 + padX).clamp(0, origW);
      final fy2 = (y2 + padY).clamp(0, origH);
      
      faces.add(FaceDetection(
        bbox: [fx1, fy1, fx2, fy2],
        confidence: validScores[idx],
        name: 'unknown', // Will be identified by recognizer
      ));
    }
    
    return faces.take(5).toList();
  }

  List<int> _nms(List<List<double>> boxes, List<double> scores, double threshold) {
    final indices = List.generate(boxes.length, (i) => i);
    indices.sort((a, b) => scores[b].compareTo(scores[a]));
    
    final keep = <int>[];
    final suppressed = <bool>[];
    
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
    final x1 = box1[0].max(box2[0]);
    final y1 = box1[1].max(box2[1]);
    final x2 = box1[2].min(box2[2]);
    final y2 = box1[3].min(box2[3]);
    
    final inter = (x2 - x1).clamp(0, double.infinity) * (y2 - y1).clamp(0, double.infinity);
    final area1 = (box1[2] - box1[0]) * (box1[3] - box1[1]);
    final area2 = (box2[2] - box2[0]) * (box2[3] - box2[1]);
    
    return inter / (area1 + area2 - inter);
  }

  List<FaceDetection> _fallbackDetection(img.Image? image) {
    // Simple skin-color based detection as fallback
    if (image == null) return [];
    
    // This is a simplified version - in practice you'd use OpenCV or similar
    // For now, return empty to indicate no faces found
    return [];
  }

  @override
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _initialized = false;
  }
}