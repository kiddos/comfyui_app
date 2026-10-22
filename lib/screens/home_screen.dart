import 'dart:async';
import 'package:flutter/material.dart';
import '../models/execution_state.dart';
import '../models/generation_record.dart';
import '../services/comfyui_service.dart';
import '../services/database_service.dart';
import '../services/image_saver_service.dart';
import '../services/workflow_service.dart';
import '../widgets/connection_card.dart';
import '../widgets/progress_monitor.dart';
import '../widgets/prompt_editor.dart';
import '../widgets/result_view.dart';
import '../widgets/workflow_picker.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _serverUrl = DatabaseService.defaultServerUrl;
  List<String> _availableWorkflows = [];
  String? _selectedWorkflow;
  Map<String, dynamic>? _loadedWorkflowJson;

  final TextEditingController _positiveController = TextEditingController();
  final TextEditingController _negativeController = TextEditingController();
  String _initialPositive = '';
  String _initialNegative = '';

  bool _randomizeSeed = true;
  bool _isLoadingWorkflows = true;

  ExecutionProgress _progress = const ExecutionProgress();
  StreamSubscription<ExecutionProgress>? _executionSubscription;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _executionSubscription?.cancel();
    _positiveController.dispose();
    _negativeController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    // 1. Load saved server URL from SQLite
    final savedUrl = await DatabaseService.instance.getServerUrl();

    // 2. Load available workflows from workflows/
    final workflows = await WorkflowService.getAvailableWorkflows();

    if (!mounted) return;

    setState(() {
      _serverUrl = savedUrl;
      _availableWorkflows = workflows;
      _isLoadingWorkflows = false;
    });

    // 3. Select first workflow by default
    if (workflows.isNotEmpty) {
      _selectWorkflow(workflows.first);
    }
  }

  Future<void> _selectWorkflow(String workflowName) async {
    try {
      final jsonMap = await WorkflowService.loadWorkflow(workflowName);
      final extracted = WorkflowService.extractPrompts(jsonMap);

      if (!mounted) return;

      setState(() {
        _selectedWorkflow = workflowName;
        _loadedWorkflowJson = jsonMap;
        _initialPositive = extracted.positivePrompt;
        _initialNegative = extracted.negativePrompt;
        _positiveController.text = extracted.positivePrompt;
        _negativeController.text = extracted.negativePrompt;
        // Reset previous result when workflow changes
        _progress = const ExecutionProgress();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load workflow: $e')),
      );
    }
  }

  void _resetPromptsToDefault() {
    setState(() {
      _positiveController.text = _initialPositive;
      _negativeController.text = _initialNegative;
    });
  }

  Future<void> _runWorkflow() async {
    if (_selectedWorkflow == null || _loadedWorkflowJson == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a workflow first')),
      );
      return;
    }

    if (_progress.isRunning) {
      return;
    }

    // Cancel any previous run subscription
    await _executionSubscription?.cancel();

    // Prepare modified workflow JSON with user prompts and new seed
    final preparedWorkflow = WorkflowService.prepareWorkflowWithPrompts(
      _loadedWorkflowJson!,
      positivePrompt: _positiveController.text,
      negativePrompt: _negativeController.text,
      randomizeSeed: _randomizeSeed,
    );

    setState(() {
      _progress = const ExecutionProgress(
        status: ExecutionStatus.connecting,
        statusMessage: 'Initiating run...',
      );
    });

    final stream = ComfyUIService.instance.runWorkflow(
      serverUrl: _serverUrl,
      workflowPrompt: preparedWorkflow,
      workflowName: _selectedWorkflow,
    );

    _executionSubscription = stream.listen(
      (progressEvent) async {
        if (!mounted) return;

        var displayEvent = progressEvent;
        if (progressEvent.status == ExecutionStatus.error && progressEvent.errorMessage != null) {
          final raw = progressEvent.errorMessage!;
          String friendly = raw;
          if (raw.contains('TimeoutException') || raw.contains('Future not completed')) {
            friendly = 'Unable to reach ComfyUI server at $_serverUrl.\nConnection timed out. Please check that ComfyUI is running.';
          } else if (raw.contains('Connection refused') || raw.contains('SocketException') || raw.contains('Failed host lookup')) {
            friendly = 'Failed to connect to ComfyUI server at $_serverUrl.\nPlease ensure the server is running and accessible.';
          }
          displayEvent = progressEvent.copyWith(
            statusMessage: 'Connection Error',
            errorMessage: friendly,
          );
        }

        setState(() {
          _progress = displayEvent;
        });

        // When image bytes are ready and saving is indicated:
        if (progressEvent.status == ExecutionStatus.saving &&
            progressEvent.resultImageBytes != null) {
          try {
            // Save to phone shared image folder (Gallery) & app storage
            final savedPath = await ImageSaverService.saveImage(
              bytes: progressEvent.resultImageBytes!,
              workflowName: _selectedWorkflow!,
              promptId: progressEvent.promptId,
            );

            // Record in SQLite database
            final record = GenerationRecord(
              workflowName: _selectedWorkflow!,
              positivePrompt: _positiveController.text,
              negativePrompt: _negativeController.text,
              promptId: progressEvent.promptId ?? '',
              imagePath: savedPath,
              serverUrl: _serverUrl,
              createdAt: DateTime.now(),
            );
            await DatabaseService.instance.insertGeneration(record);

            if (!mounted) return;

            setState(() {
              _progress = progressEvent.copyWith(
                status: ExecutionStatus.completed,
                statusMessage: 'Completed & Saved to Gallery!',
                savedImagePath: savedPath,
              );
            });
          } catch (e) {
            debugPrint('Error saving image or writing to SQLite: $e');
            if (!mounted) return;
            setState(() {
              _progress = progressEvent.copyWith(
                status: ExecutionStatus.completed,
                statusMessage: 'Completed (Saved with warning: $e)',
              );
            });
          }
        }
      },
      onError: (err) {
        if (!mounted) return;
        final raw = err.toString();
        String friendly = raw;
        if (raw.contains('TimeoutException') || raw.contains('Future not completed')) {
          friendly = 'Unable to reach ComfyUI server at $_serverUrl.\nConnection timed out. Please check that ComfyUI is running.';
        } else if (raw.contains('Connection refused') || raw.contains('SocketException') || raw.contains('Failed host lookup')) {
          friendly = 'Failed to connect to ComfyUI server at $_serverUrl.\nPlease ensure the server is running and accessible.';
        }
        setState(() {
          _progress = ExecutionProgress(
            status: ExecutionStatus.error,
            statusMessage: 'Connection Error',
            errorMessage: friendly,
          );
        });
      },
    );
  }

  void _cancelExecution() {
    _executionSubscription?.cancel();
    setState(() {
      _progress = const ExecutionProgress(
        status: ExecutionStatus.idle,
        statusMessage: 'Execution cancelled',
      );
    });
  }

  void _openHistory([int initialTab = 0]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HistoryScreen(
          initialTabIndex: initialTab,
          onReusePrompt: (wf, pos, neg) {
            setState(() {
              if (wf != 'ComfyUI_History') {
                _selectedWorkflow = wf;
              }
              _positiveController.text = pos;
              _negativeController.text = neg;
            });
            // Also reload workflow structure if it was a file workflow
            if (wf != 'ComfyUI_History') {
              WorkflowService.loadWorkflow(wf).then((json) {
                if (mounted) setState(() => _loadedWorkflowJson = json);
              });
            }
          },
        ),
      ),
    );
  }

  void _openServerHistory() {
    _openHistory(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.palette_outlined, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text(
              'ComfyUI Studio',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_download_outlined),
            tooltip: 'Server Prompt History',
            onPressed: _openServerHistory,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Generation History',
            onPressed: () => _openHistory(0),
          ),
        ],
      ),
      body: _isLoadingWorkflows
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Connection setup widget
                    ConnectionCard(
                      serverUrl: _serverUrl,
                      onUrlChanged: (newUrl) {
                        setState(() {
                          _serverUrl = newUrl;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    // 2. Workflow Picker widget
                    WorkflowPicker(
                      workflows: _availableWorkflows,
                      selectedWorkflow: _selectedWorkflow,
                      onSelected: _selectWorkflow,
                    ),

                    const SizedBox(height: 12),

                    // 3. Positive and Negative Prompt Editor widget
                    PromptEditor(
                      positiveController: _positiveController,
                      negativeController: _negativeController,
                      randomizeSeed: _randomizeSeed,
                      onRandomizeSeedChanged: (val) {
                        setState(() => _randomizeSeed = val);
                      },
                      onResetToDefault: _resetPromptsToDefault,
                    ),

                    const SizedBox(height: 16),

                    // 4. Run Workflow Action Button
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        icon: _progress.isRunning
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.play_arrow_rounded, size: 26),
                        label: Text(
                          _progress.isRunning
                              ? 'Running Workflow...'
                              : 'Generate Image',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: _progress.isRunning ? null : _runWorkflow,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 5. Progress Monitor widget (WebSocket progress & steps)
                    if (_progress.isRunning || _progress.status == ExecutionStatus.error) ...[
                      ProgressMonitor(
                        progress: _progress,
                        onCancel: _progress.isRunning ? _cancelExecution : null,
                        onDismiss: _progress.status == ExecutionStatus.error
                            ? () => setState(() => _progress = const ExecutionProgress())
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 6. Result View widget (Saved to Gallery & SQLite confirmation)
                    if (_progress.resultImageBytes != null || _progress.savedImagePath != null) ...[
                      ResultView(
                        imageBytes: _progress.resultImageBytes,
                        savedPath: _progress.savedImagePath,
                        workflowName: _selectedWorkflow ?? 'Workflow',
                        positivePrompt: _positiveController.text,
                        onDismiss: () {
                          setState(() {
                            _progress = const ExecutionProgress();
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
