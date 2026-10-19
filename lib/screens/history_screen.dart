import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/generation_record.dart';
import '../services/database_service.dart';

class HistoryScreen extends StatefulWidget {
  final Function(String workflow, String positive, String negative)? onReusePrompt;

  const HistoryScreen({super.key, this.onReusePrompt});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<GenerationRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
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
        title: const Text('Clear History?'),
        content: const Text('Are you sure you want to clear all generation records from SQLite database?'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generation History'),
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear History',
              onPressed: _clearAll,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'No generations yet',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Images generated via ComfyUI will be recorded here.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
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
                                    Text(
                                      item.createdAt.toLocal().toString().split('.').first,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
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
                ),
    );
  }
}
