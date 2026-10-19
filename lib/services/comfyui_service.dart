import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/execution_state.dart';

class ComfyUIService {
  static final ComfyUIService instance = ComfyUIService._internal();
  ComfyUIService._internal();

  static String normalizeUrl(String input) {
    var url = input.trim();
    if (url.isEmpty) return 'http://192.168.0.198:8188';
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  static Uri getWebSocketUri(String serverUrl, String clientId) {
    final normalized = normalizeUrl(serverUrl);
    final uri = Uri.parse(normalized);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: wsScheme,
      host: uri.host,
      port: uri.port,
      path: '/ws',
      queryParameters: {'clientId': clientId},
    );
  }

  Future<bool> testConnection(String serverUrl) async {
    try {
      final normalized = normalizeUrl(serverUrl);
      final client = http.Client();
      try {
        final res = await client
            .get(Uri.parse('$normalized/system_stats'))
            .timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) return true;

        final res2 = await client
            .get(Uri.parse('$normalized/prompt'))
            .timeout(const Duration(seconds: 4));
        return res2.statusCode == 200;
      } finally {
        client.close();
      }
    } catch (_) {
      return false;
    }
  }

  Stream<ExecutionProgress> runWorkflow({
    required String serverUrl,
    required Map<String, dynamic> workflowPrompt,
    String? workflowName,
  }) {
    late final StreamController<ExecutionProgress> controller;
    bool isCancelled = false;
    WebSocketChannel? wsChannel;
    StreamSubscription? wsSubscription;

    controller = StreamController<ExecutionProgress>(
      onCancel: () {
        isCancelled = true;
        wsSubscription?.cancel();
        wsChannel?.sink.close();
      },
    );

    _executeWorkflow(
      controller: controller,
      serverUrl: serverUrl,
      workflowPrompt: workflowPrompt,
      workflowName: workflowName,
      isCancelled: () => isCancelled,
      setWsResources: (channel, subscription) {
        wsChannel = channel;
        wsSubscription = subscription;
      },
    );

    return controller.stream;
  }

  Future<void> _executeWorkflow({
    required StreamController<ExecutionProgress> controller,
    required String serverUrl,
    required Map<String, dynamic> workflowPrompt,
    String? workflowName,
    required bool Function() isCancelled,
    required void Function(WebSocketChannel channel, StreamSubscription subscription) setWsResources,
  }) async {
    final normalizedUrl = normalizeUrl(serverUrl);
    final clientId = const Uuid().v4();
    WebSocketChannel? wsChannel;
    StreamSubscription? wsSubscription;

    controller.add(const ExecutionProgress(
      status: ExecutionStatus.connecting,
      statusMessage: 'Connecting to ComfyUI server...',
    ));

    final wsUri = getWebSocketUri(normalizedUrl, clientId);
    final List<Map<String, dynamic>> outputImages = [];
    String? promptId;
    final executionDone = Completer<void>();

    // Helper map of node_id -> title for display
    final nodeTitles = <String, String>{};
    for (final entry in workflowPrompt.entries) {
      if (entry.value is Map) {
        final meta = (entry.value as Map)['_meta'];
        if (meta is Map && meta['title'] != null) {
          nodeTitles[entry.key] = meta['title'].toString();
        } else if ((entry.value as Map)['class_type'] != null) {
          nodeTitles[entry.key] = (entry.value as Map)['class_type'].toString();
        }
      }
    }

    try {
      wsChannel = WebSocketChannel.connect(wsUri);
      await wsChannel.ready.timeout(const Duration(seconds: 7));

      if (isCancelled()) return;

      controller.add(const ExecutionProgress(
        status: ExecutionStatus.submitting,
        statusMessage: 'Connected. Submitting workflow...',
      ));

      // Listen on WebSocket
      wsSubscription = wsChannel.stream.listen(
        (dynamic message) {
          if (message is String) {
            try {
              final json = jsonDecode(message) as Map<String, dynamic>;
              final type = json['type'] as String?;
              final data = json['data'] as Map<String, dynamic>? ?? {};

              debugPrint('ComfyUI WS Event: $type');

              switch (type) {
                case 'status':
                  final execInfo = data['status']?['exec_info'];
                  final queueRemaining = execInfo?['queue_remaining'] ?? 0;
                  if (promptId == null && !controller.isClosed) {
                    controller.add(ExecutionProgress(
                      status: ExecutionStatus.queued,
                      statusMessage: 'In queue (remaining: $queueRemaining)...',
                      promptId: promptId,
                    ));
                  }
                  break;

                case 'execution_start':
                  if (data['prompt_id'] == promptId && !controller.isClosed) {
                    controller.add(ExecutionProgress(
                      status: ExecutionStatus.executing,
                      statusMessage: 'Execution started',
                      promptId: promptId,
                    ));
                  }
                  break;

                case 'executing':
                  final node = data['node']?.toString();
                  final currentPromptId = data['prompt_id']?.toString();

                  if (currentPromptId == promptId) {
                    if (node == null) {
                      // null node indicates execution completed in older ComfyUI
                      if (!executionDone.isCompleted) {
                        executionDone.complete();
                      }
                    } else if (!controller.isClosed) {
                      final title = nodeTitles[node] ?? 'Node $node';
                      controller.add(ExecutionProgress(
                        status: ExecutionStatus.executing,
                        statusMessage: 'Running: $title',
                        currentNodeTitle: title,
                        promptId: promptId,
                      ));
                    }
                  }
                  break;

                case 'progress':
                  final step = (data['value'] as num?)?.toInt() ?? 0;
                  final max = (data['max'] as num?)?.toInt() ?? 0;
                  final node = data['node']?.toString();
                  final title = node != null ? (nodeTitles[node] ?? 'Node $node') : 'Sampler';

                  if (!controller.isClosed) {
                    controller.add(ExecutionProgress(
                      status: ExecutionStatus.executing,
                      statusMessage: 'Sampling step $step of $max ($title)',
                      currentStep: step,
                      totalSteps: max,
                      currentNodeTitle: title,
                      promptId: promptId,
                    ));
                  }
                  break;

                case 'executed':
                  if (data['prompt_id'] == promptId) {
                    final output = data['output'];
                    if (output is Map && output['images'] is List) {
                      for (final img in (output['images'] as List)) {
                        if (img is Map) {
                          outputImages.add(Map<String, dynamic>.from(img));
                        }
                      }
                    }
                  }
                  break;

                case 'execution_success':
                  if (data['prompt_id'] == promptId) {
                    if (!executionDone.isCompleted) {
                      executionDone.complete();
                    }
                  }
                  break;

                case 'execution_error':
                  if (data['prompt_id'] == promptId) {
                    final errMsg = data['exception_message']?.toString() ??
                        data['exception_type']?.toString() ??
                        'ComfyUI execution error';
                    if (!executionDone.isCompleted) {
                      executionDone.completeError(errMsg);
                    }
                  }
                  break;
              }
            } catch (e) {
              debugPrint('Error parsing ComfyUI WS message: $e');
            }
          }
        },
        onError: (err) {
          if (!executionDone.isCompleted) {
            executionDone.completeError(err);
          }
        },
      );

      setWsResources(wsChannel, wsSubscription);

      // Submit workflow to /prompt
      final promptPayload = {
        'prompt': workflowPrompt,
        'client_id': clientId,
      };

      final postRes = await http.post(
        Uri.parse('$normalizedUrl/prompt'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(promptPayload),
      ).timeout(const Duration(seconds: 15));

      if (isCancelled()) return;

      if (postRes.statusCode != 200) {
        String errDetail = 'Failed to queue prompt: ${postRes.statusCode}';
        try {
          final errJson = jsonDecode(postRes.body);
          if (errJson['node_errors'] != null &&
              (errJson['node_errors'] as Map).isNotEmpty) {
            errDetail = 'Node errors: ${jsonEncode(errJson['node_errors'])}';
          } else if (errJson['error'] != null) {
            errDetail = errJson['error'].toString();
          }
        } catch (_) {
          errDetail = postRes.body;
        }
        if (!controller.isClosed) {
          controller.add(ExecutionProgress(
            status: ExecutionStatus.error,
            statusMessage: 'Prompt submission failed',
            errorMessage: errDetail,
          ));
        }
        return;
      }

      final postJson = jsonDecode(postRes.body) as Map<String, dynamic>;
      promptId = postJson['prompt_id'] as String?;

      if (!controller.isClosed) {
        controller.add(ExecutionProgress(
          status: ExecutionStatus.queued,
          statusMessage: 'Prompt queued (ID: ${promptId?.substring(0, 8)}...)',
          promptId: promptId,
        ));
      }

      // Wait for execution to finish (via execution_success or executing with null node)
      await executionDone.future.timeout(const Duration(minutes: 10));

      if (isCancelled()) return;

      if (!controller.isClosed) {
        controller.add(ExecutionProgress(
          status: ExecutionStatus.downloading,
          statusMessage: 'Execution success. Fetching result...',
          promptId: promptId,
        ));
      }

      // If outputImages is still empty, query /history/$promptId
      if (outputImages.isEmpty && promptId != null) {
        try {
          final historyRes = await http
              .get(Uri.parse('$normalizedUrl/history/$promptId'))
              .timeout(const Duration(seconds: 10));
          if (historyRes.statusCode == 200) {
            final histJson = jsonDecode(historyRes.body) as Map<String, dynamic>;
            final histData = histJson[promptId];
            if (histData is Map && histData['outputs'] is Map) {
              final outputs = histData['outputs'] as Map;
              for (final nodeOutput in outputs.values) {
                if (nodeOutput is Map && nodeOutput['images'] is List) {
                  for (final img in (nodeOutput['images'] as List)) {
                    if (img is Map) {
                      outputImages.add(Map<String, dynamic>.from(img));
                    }
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Error querying /history/$promptId: $e');
        }
      }

      if (isCancelled()) return;

      if (outputImages.isNotEmpty) {
        final firstImage = outputImages.first;
        final filename = firstImage['filename']?.toString() ?? '';
        final subfolder = firstImage['subfolder']?.toString() ?? '';
        final type = firstImage['type']?.toString() ?? 'output';

        final viewUri = Uri.parse('$normalizedUrl/view').replace(
          queryParameters: {
            'filename': filename,
            if (subfolder.isNotEmpty) 'subfolder': subfolder,
            'type': type,
          },
        );

        debugPrint('Downloading image from viewUri: $viewUri');
        final imgRes = await http.get(viewUri).timeout(const Duration(seconds: 30));

        if (isCancelled()) return;

        if (imgRes.statusCode == 200) {
          final imageBytes = imgRes.bodyBytes;
          if (!controller.isClosed) {
            controller.add(ExecutionProgress(
              status: ExecutionStatus.saving,
              statusMessage: 'Saving image to gallery...',
              promptId: promptId,
              resultImageBytes: imageBytes,
            ));
          }
        } else {
          if (!controller.isClosed) {
            controller.add(ExecutionProgress(
              status: ExecutionStatus.error,
              statusMessage: 'Failed to download image from ComfyUI',
              errorMessage: 'HTTP ${imgRes.statusCode}: ${imgRes.reasonPhrase}',
              promptId: promptId,
            ));
          }
        }
      } else {
        if (!controller.isClosed) {
          controller.add(ExecutionProgress(
            status: ExecutionStatus.error,
            statusMessage: 'No output images produced by workflow',
            errorMessage: 'Workflow completed but no image was found in output nodes.',
            promptId: promptId,
          ));
        }
      }
    } catch (e, stack) {
      debugPrint('Workflow execution exception: $e\n$stack');
      if (!isCancelled() && !controller.isClosed) {
        controller.add(ExecutionProgress(
          status: ExecutionStatus.error,
          statusMessage: 'Execution error',
          errorMessage: e.toString(),
          promptId: promptId,
        ));
      }
    } finally {
      await wsSubscription?.cancel();
      await wsChannel?.sink.close();
      if (!controller.isClosed) {
        await controller.close();
      }
    }
  }
}
