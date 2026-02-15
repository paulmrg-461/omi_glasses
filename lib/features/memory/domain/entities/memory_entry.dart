class MemoryEntry {
  final String id;
  final DateTime timestamp;
  final String sourceDeviceId;
  final String transcript;
  final String summary;
  final List<String> suggestions;
  MemoryEntry({
    required this.id,
    required this.timestamp,
    required this.sourceDeviceId,
    required this.transcript,
    required this.summary,
    required this.suggestions,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'sourceDeviceId': sourceDeviceId,
    'transcript': transcript,
    'summary': summary,
    'suggestions': suggestions,
  };

  static MemoryEntry fromMap(Map<dynamic, dynamic> m) {
    return MemoryEntry(
      id: m['id'] as String,
      timestamp: DateTime.parse(m['timestamp'] as String),
      sourceDeviceId: m['sourceDeviceId'] as String,
      transcript: m['transcript']?.toString() ?? '',
      summary: m['summary'] as String,
      suggestions: (m['suggestions'] as List).map((e) => e.toString()).toList(),
    );
  }
}
