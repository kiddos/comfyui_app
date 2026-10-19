class GenerationRecord {
  final int? id;
  final String workflowName;
  final String positivePrompt;
  final String negativePrompt;
  final String promptId;
  final String imagePath;
  final String serverUrl;
  final DateTime createdAt;

  GenerationRecord({
    this.id,
    required this.workflowName,
    required this.positivePrompt,
    required this.negativePrompt,
    required this.promptId,
    required this.imagePath,
    required this.serverUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'workflow_name': workflowName,
      'positive_prompt': positivePrompt,
      'negative_prompt': negativePrompt,
      'prompt_id': promptId,
      'image_path': imagePath,
      'server_url': serverUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory GenerationRecord.fromMap(Map<String, dynamic> map) {
    return GenerationRecord(
      id: map['id'] as int?,
      workflowName: map['workflow_name'] as String? ?? '',
      positivePrompt: map['positive_prompt'] as String? ?? '',
      negativePrompt: map['negative_prompt'] as String? ?? '',
      promptId: map['prompt_id'] as String? ?? '',
      imagePath: map['image_path'] as String? ?? '',
      serverUrl: map['server_url'] as String? ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
