import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:comfyui_app/models/generation_record.dart';
import 'package:comfyui_app/services/database_service.dart';
import 'package:comfyui_app/services/workflow_service.dart';
import 'package:comfyui_app/widgets/prompt_editor.dart';

void main() {
  setUpAll(() {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  });

  group('WorkflowService Tests', () {
    test('extractPrompts correctly finds positive and negative prompts', () {
      final sampleWorkflow = {
        '1': {
          'class_type': 'CLIPTextEncode',
          '_meta': {'title': 'positive_prompt'},
          'inputs': {'text': 'A serene mountain lake at sunrise'},
        },
        '2': {
          'class_type': 'CLIPTextEncode',
          '_meta': {'title': 'negative_prompt'},
          'inputs': {'text': 'blurry, low quality'},
        },
      };

      final extracted = WorkflowService.extractPrompts(sampleWorkflow);
      expect(extracted.positivePrompt, 'A serene mountain lake at sunrise');
      expect(extracted.negativePrompt, 'blurry, low quality');
    });

    test('extractPrompts handles SDXL text_g and text_l', () {
      final sdxlWorkflow = {
        '7': {
          'class_type': 'CLIPTextEncodeSDXL',
          '_meta': {'title': 'positive_prompt'},
          'inputs': {
            'text_g': 'SDXL masterpiece prompt',
            'text_l': 'SDXL masterpiece prompt',
          },
        },
        '5': {
          'class_type': 'CLIPTextEncodeSDXL',
          '_meta': {'title': 'negative_prompt'},
          'inputs': {
            'text_g': 'ugly, deformed',
            'text_l': 'ugly, deformed',
          },
        },
      };

      final extracted = WorkflowService.extractPrompts(sdxlWorkflow);
      expect(extracted.positivePrompt, 'SDXL masterpiece prompt');
      expect(extracted.negativePrompt, 'ugly, deformed');
    });

    test('prepareWorkflowWithPrompts updates prompt texts and randomizes seed', () {
      final sampleWorkflow = {
        '1': {
          'class_type': 'CLIPTextEncode',
          '_meta': {'title': 'positive_prompt'},
          'inputs': {'text': 'old positive'},
        },
        '2': {
          'class_type': 'CLIPTextEncode',
          '_meta': {'title': 'negative_prompt'},
          'inputs': {'text': 'old negative'},
        },
        '3': {
          'class_type': 'KSampler',
          '_meta': {'title': 'KSampler'},
          'inputs': {'seed': 12345},
        },
      };

      final updated = WorkflowService.prepareWorkflowWithPrompts(
        sampleWorkflow,
        positivePrompt: 'new positive text',
        negativePrompt: 'new negative text',
        randomizeSeed: true,
      );

      final posNode = updated['1'] as Map<String, dynamic>;
      final negNode = updated['2'] as Map<String, dynamic>;
      final ksampler = updated['3'] as Map<String, dynamic>;

      expect(posNode['inputs']['text'], 'new positive text');
      expect(negNode['inputs']['text'], 'new negative text');
      expect(ksampler['inputs']['seed'], isNot(12345));
    });
  });

  group('DatabaseService Tests', () {
    test('Default server URL is http://192.168.0.198:8188', () async {
      final url = await DatabaseService.instance.getServerUrl();
      expect(url, contains('192.168.0.198:8188'));
    });

    test('Saving and retrieving server URL works', () async {
      const customUrl = 'http://192.168.1.100:8188';
      await DatabaseService.instance.setServerUrl(customUrl);
      final fetched = await DatabaseService.instance.getServerUrl();
      expect(fetched, customUrl);

      // Restore default
      await DatabaseService.instance.setServerUrl(DatabaseService.defaultServerUrl);
    });

    test('Inserting and querying GenerationRecord works', () async {
      final record = GenerationRecord(
        workflowName: 'flux-dev-ghibli.json',
        positivePrompt: 'ghibli aesthetic scenery',
        negativePrompt: 'bad quality',
        promptId: 'test-prompt-id-123',
        imagePath: '/tmp/test.png',
        serverUrl: 'http://192.168.0.198:8188',
        createdAt: DateTime.now(),
      );

      final id = await DatabaseService.instance.insertGeneration(record);
      expect(id, isPositive);

      final list = await DatabaseService.instance.getGenerations();
      expect(list.any((r) => r.promptId == 'test-prompt-id-123'), isTrue);

      await DatabaseService.instance.deleteGeneration(id);
    });
  });

  group('PromptEditor Widget Tests', () {
    testWidgets('PromptEditor displays controllers and allows editing', (tester) async {
      final posCtrl = TextEditingController(text: 'Initial Positive');
      final negCtrl = TextEditingController(text: 'Initial Negative');
      bool seedRandom = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PromptEditor(
                positiveController: posCtrl,
                negativeController: negCtrl,
                randomizeSeed: seedRandom,
                onRandomizeSeedChanged: (val) => seedRandom = val,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Positive Prompt'), findsOneWidget);
      expect(find.text('Negative Prompt'), findsOneWidget);
      expect(find.text('Initial Positive'), findsOneWidget);
      expect(find.text('Initial Negative'), findsOneWidget);
    });
  });
}
