import '../../domain/entities/photo_entry.dart';
import '../../domain/repositories/photo_repository.dart';
import '../datasources/photo_local_data_source.dart';

class PhotoRepositoryImpl implements PhotoRepository {
  final PhotoLocalDataSource local;
  PhotoRepositoryImpl({required this.local});

  @override
  Future<void> save(PhotoEntry entry) async {
    await local.save(entry);
  }

  @override
  Future<List<PhotoEntry>> list({int? limit}) async {
    return local.list(limit: limit);
  }

  @override
  Future<void> clear() async {
    await local.clear();
  }
}
