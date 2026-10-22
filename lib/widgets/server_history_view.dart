import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/comfyui_history_item.dart';
import '../services/comfyui_service.dart';
import '../services/database_service.dart';

class ServerHistoryView extends StatefulWidget {
  final String? initialServerUrl;
  final Function(String workflow, String positive, String negative)? onReusePrompt;
  final VoidCallback? onImageSaved;

  const ServerHistoryView({
    super.key,
    this.initialServerUrl,
    this.onReusePrompt,
    this.onImageSaved,
  });

  @override
  ServerHistoryViewState createState() => ServerHistoryViewState();
}

class ServerHistoryViewState extends State<ServerHistoryView> {
  String _serverUrl = DatabaseService.defaultServerUrl;
  List<ComfyUIHistoryItem> _allHistory = [];
  List<ComfyUIHistoryItem> _filteredHistory = [];
  bool _isLoading = true;
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();
  final Set<String> _downloadingPromptIds = {};
  final Map<String, List<String>> _downloadedPaths = {};

  @override
  void initState() {
    super.initState();
    _initServerAndLoad();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initServerAndLoad() async {
    setState(() => _isLoading = true);
    if (widget.initialServerUrl != null && widget.initialServerUrl!.isNotEmpty) {
      _serverUrl = widget.initialServerUrl!;
    } else {
      _serverUrl = await DatabaseService.instance.getServerUrl();
    }
    await reloadHistory();
  }

  Future<void> reloadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await ComfyUIService.instance.fetchHistory(
        serverUrl: _serverUrl,
      );

      if (!mounted) return;

      setState(() {
        _allHistory = items;
        _isLoading = false;
        _applyFilter();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('TimeoutException') || raw.contains('Future not completed')) {
      return 'Connection timed out. ComfyUI server at $_serverUrl is not responding.';
    }
    if (raw.contains('Connection refused') || raw.contains('SocketException') || raw.contains('Failed host lookup')) {
      return 'Unable to connect to ComfyUI at $_serverUrl. Please check if the server is running and reachable.';
    }
    return raw;
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredHistory = List.from(_allHistory));
      return;
    }

    setState(() {
      _filteredHistory = _allHistory.where((item) {
        final matchesId = item.promptId.toLowerCase().contains(query);
        final matchesNumber = item.promptNumber?.toString().contains(query) ?? false;
        final matchesPositive = item.positivePrompt.toLowerCase().contains(query);
        final matchesNegative = item.negativePrompt.toLowerCase().contains(query);
        final matchesStatus = item.statusStr.toLowerCase().contains(query);
        return matchesId || matchesNumber || matchesPositive || matchesNegative || matchesStatus;
      }).toList();
    });
  }

  Future<void> downloadImagesForPrompt(
    ComfyUIHistoryItem item, {
    ComfyUIImageInfo? specificImage,
  }) async {
    final imagesToDownload = specificImage != null ? [specificImage] : item.images;
    if (imagesToDownload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No images available for this prompt ID')),
      );
      return;
    }

    setState(() {
      _downloadingPromptIds.add(item.promptId);
    });

    int successCount = 0;
    final savedPaths = <String>[];

    try {
      for (final img in imagesToDownload) {
        final savedPath = await ComfyUIService.instance.downloadAndSaveImage(
          serverUrl: _serverUrl,
          imageInfo: img,
          promptId: item.promptId,
          workflowName: 'History_${img.filename}',
          positivePrompt: item.positivePrompt,
          negativePrompt: item.negativePrompt,
        );
        savedPaths.add(savedPath);
        successCount++;
      }

      if (!mounted) return;

      setState(() {
        _downloadedPaths[item.promptId] = [
          ...?_downloadedPaths[item.promptId],
          ...savedPaths,
        ];
      });

      widget.onImageSaved?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            successCount == 1
                ? 'Saved 1 image to Gallery & History!'
                : 'Saved $successCount images to Gallery & History!',
          ),
          backgroundColor: Colors.green.shade700,
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              if (savedPaths.isNotEmpty) {
                _previewLocalImage(savedPaths.first, item);
              }
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloadingPromptIds.remove(item.promptId);
        });
      }
    }
  }

  void _previewServerImage(ComfyUIImageInfo img, ComfyUIHistoryItem item) {
    final imageUri = img.getViewUri(_serverUrl).toString();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(
                  img.filename,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.download),
                    tooltip: 'Download to Gallery',
                    onPressed: () {
                      Navigator.pop(ctx);
                      downloadImagesForPrompt(item, specificImage: img);
                    },
                  ),
                ],
              ),
              Flexible(
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: Image.network(
                    imageUri,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text('Failed to load image preview: $error', textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Download Image to Gallery'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      downloadImagesForPrompt(item, specificImage: img);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _previewLocalImage(String path, ComfyUIHistoryItem item) {
    final file = File(path);
    if (!file.existsSync()) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('Downloaded Image', style: TextStyle(fontSize: 14)),
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: Image.file(file, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void showLookupPromptIdDialog() {
    final controller = TextEditingController();
    bool isSearching = false;
    String? lookupError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.search, color: Colors.deepPurple),
              SizedBox(width: 8),
              Text('Lookup Prompt ID'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter or paste a ComfyUI Prompt ID to fetch its history and download the image:',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. 550e8400-e29b-41d4-a716-446655440000',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.tag),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste),
                    tooltip: 'Paste from clipboard',
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        controller.text = data!.text!.trim();
                      }
                    },
                  ),
                ),
              ),
              if (lookupError != null) ...[
                const SizedBox(height: 8),
                Text(
                  lookupError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
              if (isSearching) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSearching
                  ? null
                  : () async {
                      final promptId = controller.text.trim();
                      if (promptId.isEmpty) return;

                      setDialogState(() {
                        isSearching = true;
                        lookupError = null;
                      });

                      try {
                        final item = await ComfyUIService.instance.fetchPromptHistory(
                          serverUrl: _serverUrl,
                          promptId: promptId,
                        );

                        if (!mounted) return;

                        if (item == null) {
                          setDialogState(() {
                            isSearching = false;
                            lookupError = 'No record found for prompt ID: $promptId';
                          });
                          return;
                        }

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (mounted) {
                          _showPromptDetailSheet(item);
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSearching = false;
                          lookupError = 'Error: $e';
                        });
                      }
                    },
              child: const Text('Lookup'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPromptDetailSheet(ComfyUIHistoryItem item) {
    final isDownloading = _downloadingPromptIds.contains(item.promptId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.85,
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
                Row(
                  children: [
                    if (item.promptNumber != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.deepPurple.shade200),
                        ),
                        child: Text(
                          '#${item.promptNumber}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple.shade700,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        'Prompt ID: ${item.promptId}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'Copy Prompt ID',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: item.promptId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Prompt ID copied to clipboard!')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(
                      avatar: Icon(
                        item.completed ? Icons.check_circle : Icons.info_outline,
                        size: 16,
                        color: item.completed ? Colors.green : Colors.orange,
                      ),
                      label: Text(item.statusStr),
                      backgroundColor: item.completed
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: item.completed
                            ? Colors.green.shade800
                            : Colors.orange.shade800,
                      ),
                    ),
                    Chip(
                      avatar: const Icon(Icons.image_outlined, size: 16),
                      label: Text('${item.images.length} images'),
                      backgroundColor: Colors.grey.shade100,
                      labelStyle: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (item.images.isNotEmpty) ...[
                  const Text(
                    'Generated Output Images',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: item.images.length,
                      separatorBuilder: (context, sepIdx) => const SizedBox(width: 12),
                      itemBuilder: (context, idx) {
                        final img = item.images[idx];
                        final viewUri = img.getViewUri(_serverUrl).toString();

                        return GestureDetector(
                          onTap: () => _previewServerImage(img, item),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                Container(
                                  width: 200,
                                  height: 200,
                                  color: Colors.black12,
                                  child: Image.network(
                                    viewUri,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return const Center(child: CircularProgressIndicator());
                                    },
                                    errorBuilder: (context, error, stackTrace) => const Center(
                                      child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: FloatingActionButton.small(
                                    heroTag: 'dl_sheet_${item.promptId}_$idx',
                                    onPressed: isDownloading
                                        ? null
                                        : () => downloadImagesForPrompt(item, specificImage: img),
                                    child: const Icon(Icons.download, size: 20),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (item.positivePrompt.isNotEmpty) ...[
                  Text(
                    'Positive Prompt',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.green.shade300
                          : Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.green.shade900.withValues(alpha: 0.25)
                          : Colors.green.shade50.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.green.shade700.withValues(alpha: 0.35)
                            : Colors.green.shade200,
                      ),
                    ),
                    child: SelectableText(
                      item.positivePrompt,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (item.negativePrompt.isNotEmpty) ...[
                  Text(
                    'Negative Prompt',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.red.shade300
                          : Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.red.shade900.withValues(alpha: 0.25)
                          : Colors.red.shade50.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.red.shade700.withValues(alpha: 0.35)
                            : Colors.red.shade200,
                      ),
                    ),
                    child: SelectableText(
                      item.negativePrompt,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: isDownloading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.download),
                        label: Text(
                          isDownloading
                              ? 'Downloading...'
                              : (item.images.length > 1
                                  ? 'Download All (${item.images.length})'
                                  : 'Download Image'),
                        ),
                        onPressed: isDownloading || item.images.isEmpty
                            ? null
                            : () async {
                                Navigator.pop(ctx);
                                await downloadImagesForPrompt(item);
                              },
                      ),
                    ),
                    if (widget.onReusePrompt != null && item.positivePrompt.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.replay),
                        label: const Text('Load into Editor'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          widget.onReusePrompt!(
                            'ComfyUI_History',
                            item.positivePrompt,
                            item.negativePrompt,
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search & Server bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search Prompt ID or prompt text...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.tag),
                tooltip: 'Lookup Prompt ID',
                onPressed: showLookupPromptIdDialog,
              ),
            ],
          ),
        ),

        // Main List Content
        Expanded(
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Fetching history from ComfyUI server...'),
                    ],
                  ),
                )
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.cloud_off,
                                size: 48,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Server Offline or Unreachable',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _friendlyError(_errorMessage!),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry Connection'),
                              onPressed: reloadHistory,
                            ),
                          ],
                        ),
                      ),
                    )
                  : _filteredHistory.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                _allHistory.isEmpty
                                    ? 'No prompt history on server'
                                    : 'No matching prompt IDs',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _allHistory.isEmpty
                                    ? 'Execute prompts on ComfyUI to see them here.'
                                    : 'Try modifying your search filter.',
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                              if (_allHistory.isEmpty) ...[
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.tag),
                                  label: const Text('Enter Prompt ID Manually'),
                                  onPressed: showLookupPromptIdDialog,
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredHistory.length,
                          itemBuilder: (context, idx) {
                            final item = _filteredHistory[idx];
                            final isDownloading = _downloadingPromptIds.contains(item.promptId);
                            final hasImages = item.images.isNotEmpty;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => _showPromptDetailSheet(item),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Header: Sequence Number, Prompt ID, Copy Icon, Status Badge
                                      Row(
                                        children: [
                                          if (item.promptNumber != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              margin: const EdgeInsets.only(right: 8),
                                              decoration: BoxDecoration(
                                                color: Colors.deepPurple.shade50,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '#${item.promptNumber}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: Colors.deepPurple.shade700,
                                                ),
                                              ),
                                            ),
                                          Expanded(
                                            child: Text(
                                              item.promptId,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                fontFamily: 'monospace',
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.copy, size: 16, color: Colors.grey),
                                            tooltip: 'Copy Prompt ID',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(text: item.promptId));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Prompt ID copied!'),
                                                  duration: Duration(seconds: 1),
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: item.completed
                                                  ? Colors.green.shade50
                                                  : Colors.orange.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              item.statusStr,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: item.completed
                                                    ? Colors.green.shade800
                                                    : Colors.orange.shade800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      if (item.positivePrompt.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          item.positivePrompt,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],

                                      const SizedBox(height: 10),

                                      // Thumbnails & Download Button
                                      Row(
                                        children: [
                                          if (hasImages)
                                            Expanded(
                                              child: SizedBox(
                                                height: 60,
                                                child: ListView.separated(
                                                  scrollDirection: Axis.horizontal,
                                                  itemCount: item.images.length,
                                                  separatorBuilder: (context, sepIdx) =>
                                                      const SizedBox(width: 8),
                                                  itemBuilder: (context, imgIdx) {
                                                    final img = item.images[imgIdx];
                                                    final thumbUri =
                                                        img.getViewUri(_serverUrl).toString();

                                                    return GestureDetector(
                                                      onTap: () =>
                                                          _previewServerImage(img, item),
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(8),
                                                        child: Container(
                                                          width: 60,
                                                          height: 60,
                                                          color: Colors.black12,
                                                          child: Image.network(
                                                            thumbUri,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (context, error, stackTrace) =>
                                                                const Icon(Icons.image, size: 24, color: Colors.grey),
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            )
                                          else
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Icon(Icons.image_not_supported_outlined,
                                                      size: 20, color: Colors.grey.shade400),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'No output images',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          const SizedBox(width: 8),
                                          FilledButton.icon(
                                            style: FilledButton.styleFrom(
                                              backgroundColor: Colors.deepPurple,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 8,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                            icon: isDownloading
                                                ? const SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : const Icon(Icons.download, size: 18),
                                            label: Text(
                                              isDownloading
                                                  ? 'Saving...'
                                                  : (item.images.length > 1
                                                      ? 'Download (${item.images.length})'
                                                      : 'Download'),
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                            onPressed: isDownloading || !hasImages
                                                ? null
                                                : () => downloadImagesForPrompt(item),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
