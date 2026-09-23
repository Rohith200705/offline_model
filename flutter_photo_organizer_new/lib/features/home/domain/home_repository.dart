// Home Repository

import 'package:get_it/get_it.dart';
import '../../../core/database/database_service.dart';
import '../../../core/models/photo_models.dart';

class HomeRepository {
  final DatabaseService _db = GetIt.instance<DatabaseService>();

  Future<AppStats> getStats() async {
    return await _db.getStats();
  }
}