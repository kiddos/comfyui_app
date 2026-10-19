import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

class ResultView extends StatelessWidget {
  final Uint8List? imageBytes;
  final String? savedPath;
  final String workflowName;
  final String positivePrompt;
  final VoidCallback? onDismiss;

  const ResultView({
    super.key,
    required this.imageBytes,
    required this.savedPath,
    required this.workflowName,
    required this.positivePrompt,
    this.onDismiss,
  });

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              workflowName.replaceAll('.json', ''),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: imageBytes != null
                  ? Image.memory(imageBytes!)
                  : (savedPath != null ? Image.file(File(savedPath!)) : const SizedBox.shrink()),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (imageBytes == null && savedPath == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.withValues(alpha: 0.3), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.green.shade50,
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Generation Complete! Saved to Gallery',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onDismiss,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),

          // Image preview (tap for full screen)
          GestureDetector(
            onTap: () => _openFullScreen(context),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  constraints: const BoxConstraints(maxHeight: 380),
                  width: double.infinity,
                  color: Colors.black12,
                  child: imageBytes != null
                      ? Image.memory(
                          imageBytes!,
                          fit: BoxFit.contain,
                        )
                      : Image.file(
                          File(savedPath!),
                          fit: BoxFit.contain,
                        ),
                ),
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Tap to zoom',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Footer actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    savedPath != null ? savedPath!.split('/').last : 'Saved',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: const Text('Open Gallery', style: TextStyle(fontSize: 12)),
                  onPressed: () async {
                    try {
                      await Gal.open();
                    } catch (_) {}
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
