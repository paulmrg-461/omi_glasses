import 'package:equatable/equatable.dart';

class MemoryEntry extends Equatable {
  final String id;
  final DateTime timestamp;
  final String transcriptOriginal;
  final String summary;
  final List<ActionItem> actionItems;
  final List<String> risks;

  const MemoryEntry({
    required this.id,
    required this.timestamp,
    required this.transcriptOriginal,
    required this.summary,
    required this.actionItems,
    required this.risks,
  });

  factory MemoryEntry.fromJson(Map<String, dynamic> json) {
    final interpretation =
        json['interpretation'] as Map<String, dynamic>? ?? {};
    final actionItemsList =
        interpretation['action_items'] as List<dynamic>? ?? [];
    final risksList = interpretation['risks'] as List<dynamic>? ?? [];

    return MemoryEntry(
      id:
          json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      transcriptOriginal: json['transcript_original']?.toString() ?? '',
      summary: interpretation['summary']?.toString() ?? '',
      actionItems: actionItemsList
          .map((item) => ActionItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      risks: risksList.map((risk) => risk.toString()).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'created_at': timestamp.toIso8601String(),
      'transcript_original': transcriptOriginal,
      'interpretation': {
        'summary': summary,
        'action_items': actionItems.map((item) => item.toMap()).toList(),
        'risks': risks,
      },
    };
  }

  @override
  List<Object?> get props => [
    id,
    timestamp,
    transcriptOriginal,
    summary,
    actionItems,
    risks,
  ];
}

class ActionItem extends Equatable {
  final String title;
  final String description;
  final List<String> steps;

  const ActionItem({
    required this.title,
    required this.description,
    required this.steps,
  });

  factory ActionItem.fromJson(Map<String, dynamic> json) {
    final stepsList = json['steps'] as List<dynamic>? ?? [];
    return ActionItem(
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      steps: stepsList.map((step) => step.toString()).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'title': title, 'description': description, 'steps': steps};
  }

  @override
  List<Object?> get props => [title, description, steps];
}
