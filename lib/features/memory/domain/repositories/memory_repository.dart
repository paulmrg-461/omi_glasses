import '../entities/memory_entry.dart';

abstract class MemoryRepository {
  Future<void> save(MemoryEntry entry);
  Future<List<MemoryEntry>> list({int limit = 50, int offset = 0});
  Future<List<MemoryEntry>> search(String query, {int limit = 5});
}
