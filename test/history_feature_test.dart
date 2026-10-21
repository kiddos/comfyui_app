import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:comfyui_app/models/comfyui_history_item.dart';
import 'package:comfyui_app/widgets/server_history_view.dart';

void main() {
  group('ComfyUIHistoryItem Tests', () {
    test('fromComfyJson parses history JSON with prompt list and outputs correctly', () {
      final sampleComfyHistory = {
        'prompt': [
          42, // promptNumber
          'd4c6a582-7f93-4a0b-93df-818818818818',
          {
            '3': {
              'class_type': 'KSampler',
              'inputs': {
                'positive': ['6', 0],
                'negative': ['7', 0],
              },
            },
            '6': {
              'class_type': 'CLIPTextEncode',
              '_meta': {'title': 'positive_prompt'},
              'inputs': {'text': 'A beautiful fantasy landscape in Studio Ghibli style'},
            },
            '7': {
              'class_type': 'CLIPTextEncode',
              '_meta': {'title': 'negative_prompt'},
              'inputs': {'text': 'low quality, blurry, deformed'},
            },
          },
          {'client_id': 'test-client'},
          ['9'],
        ],
        'outputs': {
          '9': {
            'images': [
              {
                'filename': 'ComfyUI_00042_.png',
                'subfolder': 'ghibli',
                'type': 'output',
              },
              {
                'filename': 'ComfyUI_00043_.png',
                'subfolder': '',
                'type': 'output',
              },
            ],
          },
        },
        'status': {
          'status_str': 'success',
          'completed': true,
          'messages': [],
        },
      };

      const promptId = 'd4c6a582-7f93-4a0b-93df-818818818818';
      final item = ComfyUIHistoryItem.fromComfyJson(promptId, sampleComfyHistory);

      expect(item.promptId, promptId);
      expect(item.promptNumber, 42);
      expect(item.statusStr, 'success');
      expect(item.completed, isTrue);
      expect(item.positivePrompt, 'A beautiful fantasy landscape in Studio Ghibli style');
      expect(item.negativePrompt, 'low quality, blurry, deformed');
      expect(item.images.length, 2);
      expect(item.images[0].filename, 'ComfyUI_00042_.png');
      expect(item.images[0].subfolder, 'ghibli');
      expect(item.images[0].type, 'output');
      expect(item.images[1].filename, 'ComfyUI_00043_.png');

      final viewUri = item.images[0].getViewUri('http://192.168.0.100:8188');
      expect(viewUri.path, '/view');
      expect(viewUri.queryParameters['filename'], 'ComfyUI_00042_.png');
      expect(viewUri.queryParameters['subfolder'], 'ghibli');
      expect(viewUri.queryParameters['type'], 'output');
    });

    test('fromComfyJson correctly extracts prompts linked via KSampler when titles are missing', () {
      final historyWithoutTitles = {
        'prompt': [
          10,
          'id-10',
          {
            '3': {
              'class_type': 'KSampler',
              'inputs': {
                'positive': ['20', 0],
                'negative': ['21', 0],
              },
            },
            '20': {
              'class_type': 'CLIPTextEncode',
              'inputs': {'text': 'Cyberpunk city street at night'},
            },
            '21': {
              'class_type': 'CLIPTextEncode',
              'inputs': {'text': 'ugly, oversaturated'},
            },
          },
        ],
        'outputs': {
          '9': {
            'images': [
              {
                'filename': 'cyberpunk.png',
                'subfolder': '',
                'type': 'output',
              }
            ],
          },
        },
        'status': {
          'status_str': 'success',
          'completed': true,
        },
      };

      final item = ComfyUIHistoryItem.fromComfyJson('id-10', historyWithoutTitles);

      expect(item.promptId, 'id-10');
      expect(item.promptNumber, 10);
      expect(item.positivePrompt, 'Cyberpunk city street at night');
      expect(item.negativePrompt, 'ugly, oversaturated');
      expect(item.images.length, 1);
      expect(item.images.first.filename, 'cyberpunk.png');
    });

    test('fromComfyJson handles empty outputs and failed status gracefully', () {
      final failedHistory = {
        'prompt': [
          5,
          'failed-id',
          {},
        ],
        'outputs': {},
        'status': {
          'status_str': 'error',
          'completed': false,
        },
      };

      final item = ComfyUIHistoryItem.fromComfyJson('failed-id', failedHistory);

      expect(item.promptId, 'failed-id');
      expect(item.promptNumber, 5);
      expect(item.statusStr, 'error');
      expect(item.completed, isFalse);
      expect(item.images, isEmpty);
      expect(item.positivePrompt, isEmpty);
    });
  });

  group('ServerHistoryView Widget UI Tests', () {
    testWidgets('ServerHistoryView renders search and prompt lookup buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ServerHistoryView(
              initialServerUrl: 'http://127.0.0.1:8188',
            ),
          ),
        ),
      );

      // Search bar and lookup button should be present
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.tag), findsOneWidget);
    });
  });
}
