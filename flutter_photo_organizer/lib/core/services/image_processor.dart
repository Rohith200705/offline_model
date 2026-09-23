// Composite Image Processor that combines all ML services

import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'ml_interfaces.dart';
import '../models/photo_models.dart';
import 'tflite_face_detector.dart';
import 'tflite_face_recognizer.dart';
import 'tflite_scene_classifier.dart';
import 'tflite_object_detector.dart';

class ImageProcessorImpl implements ImageProcessor {
  final FaceDetector _faceDetector;
  final FaceRecognizer _faceRecognizer;
  final SceneClassifier _sceneClassifier;
  final ObjectDetector _objectDetector;
  
  static const List<String> _supportedFormats = [
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.heic', '.tiff'
  ];

  ImageProcessorImpl({
    FaceDetector? faceDetector,
    FaceRecognizer? faceRecognizer,
    SceneClassifier? sceneClassifier,
    ObjectDetector? objectDetector,
  }) : _faceDetector = faceDetector ?? TFLiteFaceDetector(),
       _faceRecognizer = faceRecognizer ?? TFLiteFaceRecognizer(),
       _sceneClassifier = sceneClassifier ?? TFLiteSceneClassifier(),
       _objectDetector = objectDetector ?? TFLiteObjectDetector();

  @override
  Future<ImageAnalysis> analyzeImage(String imagePath) async {
    try {
      final image = await _loadImage(imagePath);
      if (image == null) {
        throw Exception('Failed to load image: $imagePath');
      }

      // Run all analyses in parallel
      final futures = await Future.wait([
        _faceDetector.detectFaces(image),
        _sceneClassifier.classify(image),
        _objectDetector.detect(image),
        _extractMetadata(imagePath, image),
      ]);

      final faces = futures[0] as List<FaceDetection>;
      final scenes = futures[1] as List<SceneClassification>;
      final objects = futures[2] as List<ObjectDetection>;
      final metadata = futures[3] as ImageMetadata;

      // Identify faces
      final identifiedFaces = <FaceDetection>[];
      for (final face in faces) {
        if (face.bbox[2] > face.bbox[0] && face.bbox[3] > face.bbox[1]) {
          final faceCrop = _cropFace(image, face.bbox);
          final name = await _faceRecognizer.identifyFace(faceCrop);
          identifiedFaces.add(FaceDetection(
            bbox: face.bbox,
            confidence: face.confidence,
            name: name,
          ));
        } else {
          identifiedFaces.add(face);
        }
      }

      return ImageAnalysis(
        path: imagePath,
        filename: p.basename(imagePath),
        faces: identifiedFaces,
        scenes: scenes,
        objects: objects,
        metadata: metadata,
      );
    } catch (e) {
      return ImageAnalysis(
        path: imagePath,
        filename: p.basename(imagePath),
        faces: [],
        scenes: [],
        objects: [],
        metadata: ImageMetadata(),
      );
    }
  }

  Future<img.Image?> _loadImage(String path) async {
    try {
      final bytes = await _readFileBytes(path);
      if (bytes == null) return null;
      return img.decodeImage(bytes);
    } catch (e) {
      return null;
    }
  }

  Future<List<int>?> _readFileBytes(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<ImageMetadata> _extractMetadata(String imagePath, img.Image image) async {
    // Extract EXIF metadata
    // This would use exif package in a real implementation
    return ImageMetadata(
      width: image.width,
      height: image.height,
      // date, gps, camera would be extracted from EXIF
    );
  }

  img.Image _cropFace(img.Image image, List<int> bbox) {
    final x1 = bbox[0].clamp(0, image.width);
    final y1 = bbox[1].clamp(0, image.height);
    final x2 = bbox[2].clamp(0, image.width);
    final y2 = bbox[3].clamp(0, image.height);
    
    if (x2 <= x1 || y2 <= y1) {
      return img.Image(width: 112, height: 112);
    }
    
    return img.copyCrop(image, x: x1, y: y1, width: x2 - x1, height: y2 - y1);
  }

  @override
  bool isSupported(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    return _supportedFormats.contains(ext);
  }

  // Getters for sub-services (for advanced usage)
  FaceDetector get faceDetector => _faceDetector;
  FaceRecognizer get faceRecognizer => _faceRecognizer;
  SceneClassifier get sceneClassifier => _sceneClassifier;
  ObjectDetector get objectDetector => _objectDetector;

  void dispose() {
    _faceDetector.dispose();
    _faceRecognizer.dispose();
    _sceneClassifier.dispose();
    _objectDetector.dispose();
  }
}