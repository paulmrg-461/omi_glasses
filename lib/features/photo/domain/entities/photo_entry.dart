import 'dart:convert';

class PhotoEntry {
  final String id;
  final DateTime timestamp;
  final String description;
  final String sourceDeviceId;
  final String imageBase64;

  PhotoEntry({
    required this.id,
    required this.timestamp,
    required this.description,
    required this.sourceDeviceId,
    required this.imageBase64,
  });

  factory PhotoEntry.newFrom({
    required String description,
    required String sourceDeviceId,
    required List<int> imageBytes,
  }) {
    return PhotoEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      description: description,
      sourceDeviceId: sourceDeviceId,
      imageBase64: base64Encode(imageBytes),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
      'sourceDeviceId': sourceDeviceId,
      'imageBase64': imageBase64,
    };
  }

  factory PhotoEntry.fromMap(Map map) {
    return PhotoEntry(
      id: map['id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      description: map['description'] as String? ?? '',
      sourceDeviceId: map['sourceDeviceId'] as String? ?? '',
      imageBase64: map['imageBase64'] as String? ?? '',
    );
  }
}
