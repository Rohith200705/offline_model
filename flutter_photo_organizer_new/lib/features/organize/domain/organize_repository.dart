// Organize Repository

import 'package:get_it/get_it.dart';
import 'photo_organizer.dart';
import '../../../core/models/photo_models.dart';

class OrganizeRepository {
  final PhotoOrganizer _organizer = GetIt.instance<PhotoOrganizer>();

  Future<OrganizeResult> organizePhotos(
    String sourceDir,
    OrganizeCategory category, {
    bool moveFiles = false,
    Function(double progress, String currentFile)? onProgress,
  }) async {
    return await _organizer.organizePhotos(
      sourceDir,
      category,
      moveFiles: moveFiles,
      onProgress: onProgress,
    );
  }

  Future<Map<String, int>> getCategoryCounts() async {
    // This would query the database for category counts
    // For now, return empty map
    return {};
  }
}