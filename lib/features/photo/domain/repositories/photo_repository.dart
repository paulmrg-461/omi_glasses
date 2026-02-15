import '../entities/photo_entry.dart';

abstract class PhotoRepository {
  Future<void> save(PhotoEntry entry);
  Future<List<PhotoEntry>> list({int? limit});
  Future<void> clear();
}
