import '../../domain/entities/memory_entry.dart';
import '../../domain/repositories/memory_repository.dart';
import '../datasources/memory_local_data_source.dart';

class MemoryRepositoryImpl implements MemoryRepository {
  final MemoryLocalDataSource local;
  MemoryRepositoryImpl({required this.local});
  @override
  Future<void> save(MemoryEntry entry) => local.save(entry);
  @override
  Future<List<MemoryEntry>> list({int? limit}) => local.list(limit: limit);
}
