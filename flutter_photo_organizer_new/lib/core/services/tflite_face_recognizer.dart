// TFLite-based Face Recognizer using SFace model

import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'ml_interfaces.dart';
import '../models/photo_models.dart';
import '../utils/image_utils.dart';
import '../database/database_service.dart';

class TFLiteFaceRecognizer implements FaceRecognizer {
  Interpreter? _interpreter;
  bool _initialized = false;
  String? _error;
  
  final DatabaseService _db = DatabaseService.instance;
  Map<String, KnownFace> _knownFaces = {};
  static const int _embeddingSize = 512;
  static const double _similarityThreshold = 0.4;

  @override
  Map<String, KnownFace> get knownFaces => _knownFaces;

  Future<void> _loadKnownFaces() async {
    _knownFaces = {for (var face in await _db.getKnownFaces()) face.name: face};
  }

  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      _interpreter = await Interpreter.fromAsset('models/face/face_recognition_sface.tflite');
      await _loadKnownFaces();
      _initialized = true;
    } catch (e) {
      _error = e.toString();
      _initialized = true;
    }
  }

  @override
  Future<String> identifyFace(img.Image faceImage) async {
    if (!_initialized) await initialize();
    
    if (_interpreter == null || _knownFaces.isEmpty) {
      return 'unknown';
    }

    try {
      final embedding = await getFaceEmbedding(faceImage);
      return _matchEmbedding(embedding);
    } catch (e) {
      _error = e.toString();
      return 'unknown';
    }
  }

  @override
  Future<List<double>> getFaceEmbedding(img.Image faceImage) async {
    if (!_initialized) await initialize();
    
    if (_interpreter == null) {
      return List.filled(_embeddingSize, 0.0);
    }

    // Preprocess: align and normalize to 112x112
    final aligned = _alignFace(faceImage, 112);
    final input = _preprocessFace(aligned);
    
    // Run inference
    final output = List.filled(_embeddingSize, 0.0).reshape([1, _embeddingSize]);
    _interpreter!.run(input, output);
    
    return (output[0] as List<dynamic>).cast<double>();
  }

  img.Image _alignFace(img.Image faceImg, int targetSize) {
    final h = faceImg.height;
    final w = faceImg.width;
    
    if (h == 0 || w == 0) {
      return img.copyResize(faceImg, width: targetSize, height: targetSize);
    }
    
    final size = h > w ? h : w;
    final padX = (size - w) ~/ 2;
    final padY = (size - h) ~/ 2;
    
    final padded = img.Image(width: size, height: size);
    img.fill(padded, color: img.ColorRgb8(128, 128, 128));
    img.compositeImage(padded, faceImg, dstX: padX, dstY: padY);
    
    return img.copyResize(padded, width: targetSize, height: targetSize);
  }

  List<List<List<List<double>>>> _preprocessFace(img.Image aligned) {
    const mean = [127.0, 127.0, 127.0];
    const std = [128.0, 128.0, 128.0];
    
    final input = List.generate(1, (_) => 
      List.generate(112, (y) => 
        List.generate(112, (x) => 
          List.generate(3, (c) => 
            (aligned.getPixel(x, y)[c] - mean[c]) / std[c]
          )
        )
      )
    );
    
    return input;
  }

  String _matchEmbedding(List<double> embedding) {
    double bestScore = -1;
    String bestName = 'unknown';
    
    for (final entry in _knownFaces.entries) {
      final knownFace = entry.value;

      for (final embPath in knownFace.embeddingPaths) {
        // In a real implementation, you'd load the embedding from file
        // For now, we'll skip file loading and return unknown
        // TODO: Load embeddings from file system
        if (embPath.isEmpty) continue;
      }
    }
    
    return bestScore > _similarityThreshold ? bestName : 'unknown';
  }

  @override
  Future<bool> addKnownFace(String name, List<img.Image> faceImages) async {
    if (!_initialized) await initialize();
    
    if (_interpreter == null || faceImages.isEmpty) {
      return false;
    }

    final embeddings = <String>[];
    final sampleImages = <String>[];
    
    for (int i = 0; i < faceImages.length; i++) {
      try {
        final embedding = await getFaceEmbedding(faceImages[i]);
        
        // Save embedding to file
        final embPath = await _saveEmbedding(name, i, embedding);
        embeddings.add(embPath);
        sampleImages.add('face_${name}_$i.jpg'); // Placeholder
      } catch (e) {
        _error = e.toString();
        continue;
      }
    }
    
    if (embeddings.isEmpty) return false;
    
    final knownFace = KnownFace(
      id: name.hashCode.abs().toString(),
      name: name,
      embeddingPaths: embeddings,
      sampleImages: sampleImages,
      createdAt: DateTime.now().toIso8601String(),
    );
    
    _knownFaces[name] = knownFace;
    await _db.storeKnownFace(knownFace);
    
    return true;
  }

  Future<String> _saveEmbedding(String name, int index, List<double> embedding) async {
    // In a real app, save to file system
    // For now, return a placeholder path
    return 'embeddings/${name}_$index.bin';
  }

  @override
  Future<void> removeKnownFace(String name) async {
    if (_knownFaces.containsKey(name)) {
      _knownFaces.remove(name);
      await _db.removeKnownFace(name);
    }
  }

  @override
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _initialized = false;
  }
}