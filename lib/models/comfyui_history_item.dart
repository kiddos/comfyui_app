import '../services/comfyui_service.dart';
import '../services/workflow_service.dart';

class ComfyUIImageInfo {
  final String filename;
  final String subfolder;
  final String type;

  const ComfyUIImageInfo({
    required this.filename,
    this.subfolder = '',
    this.type = 'output',
  });

  Uri getViewUri(String serverUrl) {
    final normalized = ComfyUIService.normalizeUrl(serverUrl);
    return Uri.parse('$normalized/view').replace(
      queryParameters: {
        'filename': filename,
        if (subfolder.isNotEmpty) 'subfolder': subfolder,
        'type': type,
      },
    );
  }

  factory ComfyUIImageInfo.fromJson(Map<String, dynamic> json) {
    return ComfyUIImageInfo(
      filename: json['filename']?.toString() ?? '',
      subfolder: json['subfolder']?.toString() ?? '',
      type: json['type']?.toString() ?? 'output',
    );
  }

  Map<String, dynamic> toJson() => {
        'filename': filename,
        'subfolder': subfolder,
        'type': type,
      };
}

class ComfyUIHistoryItem {
  final String promptId;
  final int? promptNumber;
  final String statusStr;
  final bool completed;
  final String positivePrompt;
  final String negativePrompt;
  final List<ComfyUIImageInfo> images;
  final Map<String, dynamic>? rawJson;

  const ComfyUIHistoryItem({
    required this.promptId,
    this.promptNumber,
    this.statusStr = 'success',
    this.completed = true,
    this.positivePrompt = '',
    this.negativePrompt = '',
    this.images = const [],
    this.rawJson,
  });

  factory ComfyUIHistoryItem.fromComfyJson(
    String promptId,
    Map<String, dynamic> data,
  ) {
    int? promptNumber;
    String positivePrompt = '';
    String negativePrompt = '';
    final List<ComfyUIImageInfo> images = [];

    // 1. Parse prompt structure
    final promptData = data['prompt'];
    Map<String, dynamic>? nodeMap;

    if (promptData is List && promptData.isNotEmpty) {
      if (promptData[0] is num) {
        promptNumber = (promptData[0] as num).toInt();
      }
      if (promptData.length >= 3 && promptData[2] is Map) {
        nodeMap = Map<String, dynamic>.from(promptData[2] as Map);
      }
    } else if (promptData is Map) {
      nodeMap = Map<String, dynamic>.from(promptData);
    }

    if (nodeMap != null) {
      // First try standard WorkflowService extractor
      final extracted = WorkflowService.extractPrompts(nodeMap);
      positivePrompt = extracted.positivePrompt;
      negativePrompt = extracted.negativePrompt;

      // If empty, inspect KSampler connections (ComfyUI graph links)
      if (positivePrompt.isEmpty || negativePrompt.isEmpty) {
        String? posNodeId;
        String? negNodeId;

        for (final entry in nodeMap.entries) {
          if (entry.value is Map) {
            final node = entry.value as Map;
            final inputs = node['inputs'];
            if (inputs is Map) {
              if (inputs['positive'] is List && (inputs['positive'] as List).isNotEmpty) {
                posNodeId = inputs['positive'][0]?.toString();
              }
              if (inputs['negative'] is List && (inputs['negative'] as List).isNotEmpty) {
                negNodeId = inputs['negative'][0]?.toString();
              }
            }
          }
        }

        if (positivePrompt.isEmpty && posNodeId != null && nodeMap.containsKey(posNodeId)) {
          final posNode = nodeMap[posNodeId];
          if (posNode is Map && posNode['inputs'] is Map) {
            final text = _findTextInInputs(posNode['inputs'] as Map);
            if (text != null && text.isNotEmpty) {
              positivePrompt = text;
            }
          }
        }

        if (negativePrompt.isEmpty && negNodeId != null && nodeMap.containsKey(negNodeId)) {
          final negNode = nodeMap[negNodeId];
          if (negNode is Map && negNode['inputs'] is Map) {
            final text = _findTextInInputs(negNode['inputs'] as Map);
            if (text != null && text.isNotEmpty) {
              negativePrompt = text;
            }
          }
        }

        // Fallback: scan any text node if still empty
        if (positivePrompt.isEmpty) {
          for (final entry in nodeMap.entries) {
            if (entry.value is Map) {
              final node = entry.value as Map;
              final classType = node['class_type']?.toString().toLowerCase() ?? '';
              if (classType.contains('cliptext') || classType.contains('prompt')) {
                final text = _findTextInInputs(node['inputs'] as Map? ?? {});
                if (text != null && text.isNotEmpty) {
                  positivePrompt = text;
                  break;
                }
              }
            }
          }
        }
      }
    }

    // 2. Parse outputs and extract images
    final outputs = data['outputs'];
    if (outputs is Map) {
      for (final nodeOutput in outputs.values) {
        if (nodeOutput is Map && nodeOutput['images'] is List) {
          for (final img in (nodeOutput['images'] as List)) {
            if (img is Map) {
              images.add(ComfyUIImageInfo.fromJson(Map<String, dynamic>.from(img)));
            }
          }
        }
      }
    }

    // 3. Parse execution status
    String statusStr = 'unknown';
    bool completed = false;
    final status = data['status'];
    if (status is Map) {
      statusStr = status['status_str']?.toString() ?? 'unknown';
      completed = status['completed'] == true;
    } else if (images.isNotEmpty) {
      statusStr = 'success';
      completed = true;
    }

    return ComfyUIHistoryItem(
      promptId: promptId,
      promptNumber: promptNumber,
      statusStr: statusStr,
      completed: completed,
      positivePrompt: positivePrompt,
      negativePrompt: negativePrompt,
      images: images,
      rawJson: data,
    );
  }

  static String? _findTextInInputs(Map inputs) {
    if (inputs['text'] is String && (inputs['text'] as String).isNotEmpty) {
      return inputs['text'] as String;
    }
    if (inputs['text_g'] is String && (inputs['text_g'] as String).isNotEmpty) {
      return inputs['text_g'] as String;
    }
    if (inputs['text_l'] is String && (inputs['text_l'] as String).isNotEmpty) {
      return inputs['text_l'] as String;
    }
    return null;
  }
}
