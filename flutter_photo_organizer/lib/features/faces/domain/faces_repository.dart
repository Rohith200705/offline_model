// Faces Repository

import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:get_it/get_it.dart';
import '../../core/services/image_processor.dart';
import '../../core/models/photo_models.dart';

class FacesRepository {
  final ImageProcessor _processor = GetIt.instance<ImageProcessor>();

  Future<List<KnownFace>> getKnownFaces() async {
    // This would come from the database
    // For now, return empty list
    return [];
  }

  Future<void> addKnownFace(String name, String imagePath) async {
    final image = await _loadImage(imagePath);
    if (image != null) {
      await _processor.faceRecognizer.addKnownFace(name, [image]);
    }
  }

  Future<void> removeKnownFace(String name) async {
    await _processor.faceRecognizer.removeKnownFace(name);
  }

  Future<List<FaceDetection>> testFaceRecognition(String imagePath) async {
    final image = await _loadImage(imagePath);
    if (image == null) return [];
    
    final faces = await _processor.faceDetector.detectFaces(image);
    return faces;
  }

  Future<img.Image?> _loadImage(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        return img.decodeImage(bytes);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}