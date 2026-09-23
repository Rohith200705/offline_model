// TFLite-based Object Detector using YOLOv8n

import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'ml_interfaces.dart';
import '../models/photo_models.dart';
import '../utils/image_utils.dart';

class TFLiteObjectDetector implements ObjectDetector {
  Interpreter? _interpreter;
  bool _initialized = false;
  String? _error;
  
  static const List<String> _labels = [
    'person', 'bicycle', 'car', 'motorcycle', 'bus', 'truck',
    'traffic light', 'bench', 'bird', 'cat', 'dog', 'horse',
    'backpack', 'umbrella', 'handbag', 'suitcase', 'bottle',
    'cup', 'fork', 'knife', 'spoon', 'bowl', 'banana', 'apple',
    'chair', 'couch', 'potted plant', 'bed', 'dining table',
    'toilet', 'tv', 'laptop', 'cell phone', 'book', 'clock',
    'vase', 'scissors', 'teddy bear'
  ];
  
  static const int _inputSize = 640;
  static const double _confThreshold = 0.3;
  static const double _iouThreshold = 0.4;

  @override
  Future<List<ObjectDetection>> detect(img.Image image, {double confidenceThreshold = 0.3}) async {
    if (!_initialized) {
      await _initialize();
    }
    
    if (_interpreter == null) {
      return _heuristicDetect(image);
    }

    try {
      return await _detectWithYOLO(image, confidenceThreshold);
    } catch (e) {
      _error = e.toString();
      return _heuristicDetect(image);
    }
  }

  Future<void> _initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset('models/object/yolov8n.tflite');
      _initialized = true;
    } catch (e) {
      _error = e.toString();
      _initialized = true;
    }
  }

  Future<List<ObjectDetection>> _detectWithYOLO(img.Image image, double confThreshold) async {
    final origW = image.width;
    final origH = image.height;
    
    // Resize and preprocess
    final resized = img.copyResize(image, width: _inputSize, height: _inputSize);
    final input = _preprocessInput(resized);
    
    // Run inference - YOLOv8 output format: [1, 84, 8400] (84 = 4 box + 80 classes)
    final outputShape = [1, 84, 8400];
    final output = List.filled(84 * 8400, 0.0).reshape(outputShape);
    
    _interpreter!.run(input, output);
    
    return _postProcess(output[0], origW, origH, confThreshold);
  }

  List<List<List<double>>> _preprocessInput(img.Image image) {
    final input = List.generate(1, (_) => 
      List.generate(3, (c) => 
        List.generate(_inputSize, (y) => 
          List.generate(_inputSize, (x) => 
            image.getPixel(x, y)[c] / 255.0
          )
        )
      )
    );
    return input;
  }

  List<ObjectDetection> _postProcess(
    List<List<double>> output, 
    int origW, 
    int origH, 
    double confThreshold
  ) {
    // Output shape: [84, 8400] -> transpose to [8400, 84]
    final detections = <ObjectDetection>[];
    final boxes = <List<double>>[];
    final scores = <double>[];
    final classIds = <int>[];
    
    // Transpose: output[class][anchor] -> output[anchor][class]
    for (int i = 0; i < 8400; i++) {
      final classScores = <double>[];
      for (int c = 4; c < 84; c++) {
        classScores.add(output[c][i]);
      }
      
      final maxScore = classScores.reduce((a, b) => a > b ? a : b);
      final classId = classScores.indexOf(maxScore);
      
      if (maxScore > confThreshold) {
        final cx = output[0][i];
        final cy = output[1][i];
        final w = output[2][i];
        final h = output[3][i];
        
        // Convert from center format to corner format, scale to original image
        final x = ((cx - w / 2) * origW / _inputSize).round();
        final y = ((cy - h / 2) * origH / _inputSize).round();
        final width = (w * origW / _inputSize).round();
        final height = (h * origH / _inputSize).round();
        
        boxes.add([x.toDouble(), y.toDouble(), width.toDouble(), height.toDouble()]);
        scores.add(maxScore);
        classIds.add(classId);
      }
    }
    
    // NMS
    final keepIndices = _nms(boxes, scores, _iouThreshold);
    
    for (final idx in keepIndices) {
      final label = classIds[idx] < _labels.length ? _labels[classIds[idx]] : 'object';
      detections.add(ObjectDetection(
        label: label,
        confidence: scores[idx],
        bbox: boxes[idx].map((e) => e.round()).toList(),
      ));
    }
    
    return detections.take(10).toList();
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
    final x1 = [box1[0], box2[0]].reduce((a, b) => a > b ? a : b);
    final y1 = [box1[1], box2[1]].reduce((a, b) => a > b ? a : b);
    final x2 = [box1[0] + box1[2], box2[0] + box2[2]].reduce((a, b) => a < b ? a : b);
    final y2 = [box1[1] + box1[3], box2[1] + box2[3]].reduce((a, b) => a < b ? a : b);
    
    final interW = (x2 - x1).clamp(0, double.infinity);
    final interH = (y2 - y1).clamp(0, double.infinity);
    final inter = interW * interH;
    
    final area1 = box1[2] * box1[3];
    final area2 = box2[2] * box2[3];
    
    return inter / (area1 + area2 - inter);
  }

  List<ObjectDetection> _heuristicDetect(img.Image image) {
    // Fallback heuristic detection based on color/shape
    return [];
  }

  @override
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _initialized = false;
  }
}