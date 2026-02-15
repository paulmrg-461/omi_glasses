import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/memory_entry.dart';

abstract class MemoryLocalDataSource {
  Future<void> init();
  Future<void> save(MemoryEntry entry);
  Future<List<MemoryEntry>> list({int? limit});
}

class MemoryLocalDataSourceImpl implements MemoryLocalDataSource {
  static const String boxName = 'memories';
  Box<Map>? _box;

  @override
  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<Map>(boxName);
  }

  @override
  Future<void> save(MemoryEntry entry) async {
    if (_box == null) {
      await init();
    }
    await _box!.put(entry.id, entry.toMap());
  }

  @override
  Future<List<MemoryEntry>> list({int? limit}) async {
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
    return sliced.map((m) => MemoryEntry.fromMap(m)).toList();
  }
}
