import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../domain/entities/memory_entry.dart';

abstract class MemoryRemoteDataSource {
  Future<List<MemoryEntry>> getMemoryHistory({int limit = 50, int offset = 0});
  Future<List<MemoryEntry>> searchMemories(String query, {int limit = 5});
  Future<void> createMemory(Map<String, dynamic> memoryData);
}

class MemoryRemoteDataSourceImpl implements MemoryRemoteDataSource {
  final http.Client client;
  final String _baseUrl;

  MemoryRemoteDataSourceImpl({required this.client})
      : _baseUrl = dotenv.get('RAG_API_URL', fallback: 'http://192.168.0.17:8787');

  Uri _buildUri(String path, [Map<String, String>? queryParams]) {
    final uri = Uri.parse(_baseUrl);
    return uri.replace(path: '${uri.path}$path', queryParameters: queryParams);
  }

  @override
  Future<List<MemoryEntry>> getMemoryHistory({int limit = 50, int offset = 0}) async {
    final uri = _buildUri('/user/memories/', {
      'limit': limit.toString(),
      'offset': offset.toString(),
    });

    final response = await client.get(uri, headers: {'Content-Type': 'application/json'});

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data.map((json) => MemoryEntry.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load memory history: ${response.statusCode}');
    }
  }

  @override
  Future<List<MemoryEntry>> searchMemories(String query, {int limit = 5}) async {
    final uri = _buildUri('/user/memories/search', {
      'query': query,
      'limit': limit.toString(),
    });

    final response = await client.get(uri, headers: {'Content-Type': 'application/json'});

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data.map((json) => MemoryEntry.fromJson(json)).toList();
    } else {
      throw Exception('Failed to search memories: ${response.statusCode}');
    }
  }

  @override
  Future<void> createMemory(Map<String, dynamic> memoryData) async {
    final uri = _buildUri('/user/memories/');
    final response = await client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(memoryData),
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Failed to create memory: ${response.statusCode}');
    }
  }
}
