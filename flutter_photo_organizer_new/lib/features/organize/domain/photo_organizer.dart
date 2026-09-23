// Photo Organizer Service

import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../core/models/photo_models.dart';
import '../../../core/database/database_service.dart';
import '../../../core/services/image_processor.dart';

class PhotoOrganizer {
  final ImageProcessor _processor;
  final DatabaseService _db;

  // Category directories
  static const Map<String, String> _categories = {
    'persons': 'Persons',
    'locations': 'Locations',
    'events': 'Events',
    'objects': 'Objects',
    'documents': 'Documents',
    'others': 'Others',
  };

  PhotoOrganizer({
    ImageProcessor? processor,
    DatabaseService? database,
  }) : _processor = processor ?? ImageProcessorImpl(),
       _db = database ?? DatabaseService.instance;

  Future<OrganizeResult> organizePhotos(
    String sourceDir,
    OrganizeCategory organizeBy, {
    bool moveFiles = false,
    Function(double progress, String currentFile)? onProgress,
  }) async {
    final source = Directory(sourceDir);
    if (!await source.exists()) {
      return OrganizeResult(
        total: 0,
        organized: 0,
        skipped: 0,
        errors: 1,
        details: [OrganizeDetail(file: '', error: 'Directory not found: $sourceDir')],
      );
    }

    final photos = await _getAllPhotos(source);
    if (photos.isEmpty) {
      return OrganizeResult(
        total: 0,
        organized: 0,
        skipped: 0,
        errors: 0,
        details: [OrganizeDetail(file: '', error: 'No supported photos found')],
      );
    }

    int organized = 0;
    int skipped = 0;
    int errors = 0;
    final details = <OrganizeDetail>[];

    for (int i = 0; i < photos.length; i++) {
      final photo = photos[i];

      onProgress?.call((i + 1) / photos.length, photo.path.split('/').last);

      try {
        if (await _db.photoExists(photo.path)) {
          skipped++;
          details.add(OrganizeDetail(file: photo.path.split('/').last));
          continue;
        }

        final analysis = await _processor.analyzeImage(photo.path);
        final category = _determineCategory(analysis, organizeBy);
        final dest = await _getDestination(photo, category, analysis, moveFiles);

        await _copyOrMoveFile(photo.path, dest, moveFiles);
        await _db.storePhoto(photo.path, analysis, category);

        organized++;
        details.add(OrganizeDetail(
          file: photo.path.split('/').last,
          category: category,
          destination: dest,
        ));
      } catch (e) {
        errors++;
        details.add(OrganizeDetail(
          file: photo.path.split('/').last,
          error: e.toString(),
        ));
      }
    }

    return OrganizeResult(
      total: photos.length,
      organized: organized,
      skipped: skipped,
      errors: errors,
      details: details,
    );
  }

  Future<List<FileSystemEntity>> _getAllPhotos(Directory directory) async {
    final entities = <FileSystemEntity>[];
    await for (final entity in directory.list(recursive: true, followLinks: false)) {
      if (entity is File && _processor.isSupported(entity.path)) {
        entities.add(entity);
      }
    }
    return entities;
  }

  String _determineCategory(ImageAnalysis analysis, OrganizeCategory organizeBy) {
    if (organizeBy != OrganizeCategory.auto) {
      return organizeBy.name;
    }

    // Auto categorization logic
    if (analysis.faces.isNotEmpty) {
      return 'persons';
    }

    if (analysis.scenes.isNotEmpty) {
      final topScene = analysis.scenes.first.scene;
      final outdoorScenes = ['outdoor', 'beach', 'mountain', 'forest', 'garden', 'park'];
      if (outdoorScenes.contains(topScene)) {
        return 'locations';
      }
    }

    if (analysis.metadata?.date != null) {
      return 'events';
    }

    if (analysis.objects.isNotEmpty) {
      return 'objects';
    }

    return 'others';
  }

  Future<String> _getDestination(
    FileSystemEntity photo,
    String category,
    ImageAnalysis analysis,
    bool moveFiles,
  ) async {
    final baseDir = await _getBaseDir();
    final categoryDir = _categories[category] ?? 'Others';
    final destDir = Directory(p.join(baseDir.path, 'sorted_photos', categoryDir));
    
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    String fileName = p.basename(photo.path);
    String subDir = '';

    switch (category) {
      case 'persons':
        final names = analysis.faces.map((f) => f.name).where((n) => n != 'unknown').toList();
        subDir = names.isNotEmpty ? names.first : 'unknown';
        break;
      case 'locations':
        subDir = analysis.scenes.isNotEmpty ? analysis.scenes.first.scene : 'unknown';
        break;
      case 'events':
        if (analysis.metadata?.date != null) {
          try {
            final dt = DateTime.parse(analysis.metadata!.date!.replaceAll(':', '-'));
            subDir = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
          } catch (_) {
            subDir = 'undated';
          }
        } else {
          subDir = 'undated';
        }
        break;
      case 'objects':
        subDir = analysis.objects.isNotEmpty ? analysis.objects.first.label : 'other';
        break;
      default:
        subDir = '';
    }

    if (subDir.isNotEmpty) {
      final subDirPath = Directory(p.join(destDir.path, subDir));
      if (!await subDirPath.exists()) {
        await subDirPath.create(recursive: true);
      }
      fileName = p.join(subDir, fileName);
    }

    var destPath = p.join(destDir.path, fileName);
    
    // Handle duplicates
    var counter = 1;
    while (await File(destPath).exists()) {
      final ext = p.extension(fileName);
      final name = p.basenameWithoutExtension(fileName);
      fileName = '${name}_$counter$ext';
      if (subDir.isNotEmpty) {
        fileName = p.join(subDir, fileName);
      }
      destPath = p.join(destDir.path, fileName);
      counter++;
    }

    return destPath;
  }

  Future<Directory> _getBaseDir() async {
    // Use app documents directory as base
    // In a real app, this would be configurable
    return Directory('/storage/emulated/0/Pictures/PhotoOrganizer');
  }

  Future<void> _copyOrMoveFile(String src, String dest, bool move) async {
    final srcFile = File(src);
    final destFile = File(dest);
    
    if (!await destFile.parent.exists()) {
      await destFile.parent.create(recursive: true);
    }

    if (move) {
      await srcFile.rename(dest);
    } else {
      await srcFile.copy(dest);
    }
  }

  Future<AppStats> getStats() async {
    return await _db.getStats();
  }

  void dispose() {
    _processor.dispose();
  }
}