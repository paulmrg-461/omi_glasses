import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/photo_entry.dart';

abstract class PhotoLocalDataSource {
  Future<void> init();
  Future<void> save(PhotoEntry entry);
  Future<List<PhotoEntry>> list({int? limit});
  Future<void> clear();
}

class PhotoLocalDataSourceImpl implements PhotoLocalDataSource {
  static const String boxName = 'photos';
  Box<Map>? _box;

  @override
  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<Map>(boxName);
  }

  @override
  Future<void> save(PhotoEntry entry) async {
    if (_box == null) {
      await init();
    }
    await _box!.put(entry.id, entry.toMap());
  }

  @override
  Future<List<PhotoEntry>> list({int? limit}) async {
    if (_box == null) {
      await init();
    }
    final values = _box!.values.toList();
    values.sort((a, b) {
      final ta = DateTime.parse(a['timestamp'] as String);
      final tb = DateTime.parse(b['timestamp'] as String);
      return tb.compareTo(ta);
    });
    final sliced = limit != null ? values.take(limit).toList() : values;
    return sliced.map((m) => PhotoEntry.fromMap(m)).toList();
  }

  @override
  Future<void> clear() async {
    if (_box == null) {
      await init();
    }
    await _box!.clear();
  }
}
