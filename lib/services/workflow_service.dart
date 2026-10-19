import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';

class ExtractedPrompts {
  final String positivePrompt;
  final String negativePrompt;

  const ExtractedPrompts({
    this.positivePrompt = '',
    this.negativePrompt = '',
  });
}

class WorkflowService {
  static const List<String> bundledWorkflows = [
    'SDXL-Dreamyvibes.json',
    'SDXL-Ghibli-Redmond.json',
    'SDXL-PixarStyle.json',
    'SDXL-StickersRedmond.json',
    'SDXL-zhibi.json',
    'animagine_ghibli.json',
    'animatediff-rcnzCartoon3d.json',
    'animatediff-ultimatepixartoon.json',
    'flux-dev-clash-of-clans.json',
    'flux-dev-E_cute.json',
    'flux-dev-frieren.json',
    'flux-dev-ghibli-chatgpt-4o.json',
    'flux-dev-ghibli-chatgpt.json',
    'flux-dev-ghibli-detail-v3.json',
    'flux-dev-ghiblify.json',
    'flux-dev-ghibli.json',
    'flux-dev-juaner-manga.json',
    'flux-dev-minecraft.json',
    'flux-dev-pixar-v2.json',
    'flux-dev-spongebob.json',
    'illustrious-vixons-ghibli.json',
    'pony-Frieren.json',
    'pony-stickers.json',
  ];

  static Future<List<String>> getAvailableWorkflows() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assetPaths = manifest.listAssets();
      final workflowFiles = assetPaths
          .where((path) => path.startsWith('workflows/') && path.endsWith('.json'))
          .map((path) => path.replaceFirst('workflows/', ''))
          .toList();

      if (workflowFiles.isNotEmpty) {
        workflowFiles.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        return workflowFiles;
      }
    } catch (_) {}

    final list = List<String>.from(bundledWorkflows);
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static Future<Map<String, dynamic>> loadWorkflow(String workflowFileName) async {
    final assetPath = workflowFileName.startsWith('workflows/')
        ? workflowFileName
        : 'workflows/$workflowFileName';
    final jsonString = await rootBundle.loadString(assetPath);
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  static ExtractedPrompts extractPrompts(Map<String, dynamic> workflow) {
    String? positive;
    String? negative;
    String? fallbackPositive;
    String? fallbackNegative;

    for (final entry in workflow.entries) {
      if (entry.value is! Map) continue;
      final node = entry.value as Map<String, dynamic>;
      final meta = node['_meta'];
      final title = (meta is Map ? meta['title']?.toString() : '')?.toLowerCase() ?? '';
      final inputs = node['inputs'];
      if (inputs is! Map<String, dynamic>) continue;

      // Extract positive prompt candidate
      if (title.contains('positive_prompt') || title.contains('positive prompt')) {
        final text = _extractTextFromInputs(inputs);
        if (text != null && text.isNotEmpty) {
          if (title == 'positive_prompt' || title == 'positive prompt') {
            positive = text;
          } else {
            fallbackPositive ??= text;
          }
        }
      }

      // Extract negative prompt candidate
      if (title.contains('negative_prompt') || title.contains('negative prompt')) {
        final text = _extractTextFromInputs(inputs);
        if (text != null && text.isNotEmpty) {
          if (title == 'negative_prompt' || title == 'negative prompt') {
            negative = text;
          } else {
            fallbackNegative ??= text;
          }
        }
      }
    }

    return ExtractedPrompts(
      positivePrompt: positive ?? fallbackPositive ?? '',
      negativePrompt: negative ?? fallbackNegative ?? '',
    );
  }

  static String? _extractTextFromInputs(Map<String, dynamic> inputs) {
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

  static Map<String, dynamic> prepareWorkflowWithPrompts(
    Map<String, dynamic> originalWorkflow, {
    required String positivePrompt,
    required String negativePrompt,
    bool randomizeSeed = true,
  }) {
    // Deep clone workflow
    final cloned = jsonDecode(jsonEncode(originalWorkflow)) as Map<String, dynamic>;
    final random = Random();
    final newSeed = random.nextInt(1000000000);

    for (final entry in cloned.entries) {
      if (entry.value is! Map) continue;
      final node = entry.value as Map<String, dynamic>;
      final meta = node['_meta'];
      final title = (meta is Map ? meta['title']?.toString() : '')?.toLowerCase() ?? '';
      final inputs = node['inputs'];
      if (inputs is! Map<String, dynamic>) continue;

      // Update positive prompt
      if (title.contains('positive_prompt') || title.contains('positive prompt')) {
        if (inputs.containsKey('text')) {
          inputs['text'] = positivePrompt;
        }
        if (inputs.containsKey('text_g')) {
          inputs['text_g'] = positivePrompt;
        }
        if (inputs.containsKey('text_l')) {
          inputs['text_l'] = positivePrompt;
        }
      }

      // Update negative prompt
      if (title.contains('negative_prompt') || title.contains('negative prompt')) {
        if (inputs.containsKey('text')) {
          inputs['text'] = negativePrompt;
        }
        if (inputs.containsKey('text_g')) {
          inputs['text_g'] = negativePrompt;
        }
        if (inputs.containsKey('text_l')) {
          inputs['text_l'] = negativePrompt;
        }
      }

      // Randomize seed if enabled
      if (randomizeSeed) {
        if (inputs.containsKey('seed') && inputs['seed'] is num) {
          inputs['seed'] = newSeed;
        }
        if (inputs.containsKey('noise_seed') && inputs['noise_seed'] is num) {
          inputs['noise_seed'] = newSeed;
        }
        final classType = node['class_type']?.toString() ?? '';
        if (classType == 'PrimitiveInt' && inputs.containsKey('value') && inputs['value'] is num) {
          inputs['value'] = newSeed;
        }
      }
    }

    return cloned;
  }
}
