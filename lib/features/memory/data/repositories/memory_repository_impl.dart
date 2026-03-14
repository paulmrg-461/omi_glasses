import '../../domain/entities/memory_entry.dart';
import '../../domain/repositories/memory_repository.dart';
import '../datasources/memory_remote_data_source.dart';

class MemoryRepositoryImpl implements MemoryRepository {
  final MemoryRemoteDataSource remote;

  MemoryRepositoryImpl({required this.remote});

  @override
  Future<void> save(MemoryEntry entry) async {
    // Convert MemoryEntry to the format expected by the API
    final memoryData = {
      "transcript_original": entry.transcriptOriginal,
      "interpretation": {
        "summary": entry.summary,
        "action_items": entry.actionItems.map((item) => {
          "title": item.title,
          "description": item.description,
          "steps": item.steps,
        }).toList(),
        "risks": entry.risks,
      }
    };
    await remote.createMemory(memoryData);
  }

  @override
  Future<List<MemoryEntry>> list({int limit = 50, int offset = 0}) {
    return remote.getMemoryHistory(limit: limit, offset: offset);
  }

  @override
  Future<List<MemoryEntry>> search(String query, {int limit = 5}) {
    return remote.searchMemories(query, limit: limit);
  }
}
