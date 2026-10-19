import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/generation_record.dart';
import '../services/database_service.dart';
import '../widgets/server_history_view.dart';

class HistoryScreen extends StatefulWidget {
  final Function(String workflow, String positive, String negative)? onReusePrompt;
  final int initialTabIndex;

  const HistoryScreen({
    super.key,
    this.onReusePrompt,
    this.initialTabIndex = 0,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final GlobalKey<ServerHistoryViewState> _serverViewKey = GlobalKey<ServerHistoryViewState>();

  List<GenerationRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _tabController.addListener(() {
      setState(() {});
    });
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final list = await DatabaseService.instance.getGenerations();
    if (!mounted) return;
    setState(() {
      _records = list;
      _isLoading = false;
    });
  }

  Future<void> _deleteRecord(int id) async {
    await DatabaseService.instance.deleteGeneration(id);
    _loadHistory();
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Saved History?'),
        content: const Text(
          'Are you sure you want to clear all generation records from SQLite database?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseService.instance.clearGenerations();
      _loadHistory();
    }
  }

  void _showDetailSheet(GenerationRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (File(record.imagePath).existsSync())
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(record.imagePath),
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: 280,
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                record.workflowName.replaceAll('.json', ''),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (record.promptId.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Prompt ID: ${record.promptId}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: 'Copy Prompt ID',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: record.promptId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Prompt ID copied!'), duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                  ],
                ),
              ],
              Text(
                'Generated: ${record.createdAt.toLocal().toString().split('.').first}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const Divider(height: 24),
              const Text(
                'Positive Prompt',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 4),
              SelectableText(
                record.positivePrompt.isEmpty ? '(Empty)' : record.positivePrompt,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'Negative Prompt',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.redAccent),
              ),
              const SizedBox(height: 4),
              SelectableText(
                record.negativePrompt.isEmpty ? '(None)' : record.negativePrompt,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Prompt'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: record.positivePrompt));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Prompt copied!')),
                        );
                      },
                    ),
                  ),
                  if (widget.onReusePrompt != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.replay),
                        label: const Text('Load into Editor'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          widget.onReusePrompt!(
                            record.workflowName,
                            record.positivePrompt,
                            record.negativePrompt,
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavedList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text(
                'No saved generations yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              const Text(
                'Images generated or downloaded from ComfyUI server will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Browse Server History Prompt IDs'),
                onPressed: () => _tabController.animateTo(1),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _records.length,
      itemBuilder: (context, idx) {
        final item = _records[idx];
        final file = File(item.imagePath);
        final exists = file.existsSync();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _showDetailSheet(item),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 80,
                      height: 80,
                      color: Colors.black12,
                      child: exists
                          ? Image.file(file, fit: BoxFit.cover)
                          : const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.workflowName.replaceAll('.json', ''),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.positivePrompt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              item.createdAt.toLocal().toString().split('.').first,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            if (item.promptId.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'ID: ${item.promptId.substring(0, item.promptId.length > 8 ? 8 : item.promptId.length)}...',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.deepPurple.shade300,
                                    fontFamily: 'monospace',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                    onPressed: item.id != null ? () => _deleteRecord(item.id!) : null,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSavedTab = _tabController.index == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generation & Server History'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.photo_library_outlined, size: 20),
              text: 'Saved Gallery',
            ),
            Tab(
              icon: Icon(Icons.cloud_download_outlined, size: 20),
              text: 'Server Prompt IDs',
            ),
          ],
        ),
        actions: [
          if (isSavedTab) ...[
            if (_records.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: 'Clear Saved History',
                onPressed: _clearAll,
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reload Saved',
              onPressed: _loadHistory,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.manage_search),
              tooltip: 'Lookup Prompt ID',
              onPressed: () {
                _serverViewKey.currentState?.showLookupPromptIdDialog();
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Server History',
              onPressed: () {
                _serverViewKey.currentState?.reloadHistory();
              },
            ),
          ],
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSavedList(),
          ServerHistoryView(
            key: _serverViewKey,
            onReusePrompt: widget.onReusePrompt,
            onImageSaved: _loadHistory,
          ),
        ],
      ),
    );
  }
}
