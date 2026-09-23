// Stats Repository

import 'package:get_it/get_it.dart';
import '../../../core/database/database_service.dart';
import '../../../core/models/photo_models.dart';

class StatsRepository {
  final DatabaseService _db = GetIt.instance<DatabaseService>();

  Future<AppStats> getStats() async {
    return await _db.getStats();
  }

  Future<List<Photo>> getRecentPhotos(int limit) async {
    final photos = await _db.getAllPhotos();
    // Sort by created_at descending
    photos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return photos.take(limit).toList();
  }
}