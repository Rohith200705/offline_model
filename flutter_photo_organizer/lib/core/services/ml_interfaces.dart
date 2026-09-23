// ML Service interfaces and implementations

import 'package:image/image.dart' as img;
import '../models/photo_models.dart';

abstract class FaceDetector {
  Future<List<FaceDetection>> detectFaces(img.Image image);
  void dispose();
}

abstract class FaceRecognizer {
  Future<String> identifyFace(img.Image faceImage);
  Future<List<float>> getFaceEmbedding(img.Image faceImage);
  Future<bool> addKnownFace(String name, List<img.Image> faceImages);
  Future<void> removeKnownFace(String name);
  Map<String, KnownFace> get knownFaces;
  void dispose();
}

abstract class SceneClassifier {
  Future<List<SceneClassification>> classify(img.Image image);
  void dispose();
}

abstract class ObjectDetector {
  Future<List<ObjectDetection>> detect(img.Image image, {double confidenceThreshold = 0.3});
  void dispose();
}

abstract class ImageProcessor {
  Future<ImageAnalysis> analyzeImage(String imagePath);
  bool isSupported(String filePath);
}