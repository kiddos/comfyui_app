import 'package:flutter/material.dart';
import '../models/execution_state.dart';

class ProgressMonitor extends StatelessWidget {
  final ExecutionProgress progress;
  final VoidCallback? onCancel;

  const ProgressMonitor({
    super.key,
    required this.progress,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (progress.status == ExecutionStatus.idle) {
      return const SizedBox.shrink();
    }

    if (progress.status == ExecutionStatus.error) {
      return Card(
        color: Colors.red.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.red.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    progress.statusMessage,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              if (progress.errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Text(
                    progress.errorMessage!,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.red.shade900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final fraction = progress.progressFraction;
    final pct = (fraction * 100).toInt();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.deepPurple.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        progress.statusMessage.isNotEmpty
                            ? progress.statusMessage
                            : 'Processing...',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (progress.currentNodeTitle != null)
                        Text(
                          'Node: ${progress.currentNodeTitle}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '$pct%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                if (onCancel != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    tooltip: 'Cancel',
                    onPressed: onCancel,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: fraction > 0 ? fraction : null,
                minHeight: 8,
                backgroundColor: Colors.deepPurple.shade50,
                color: Colors.deepPurple,
              ),
            ),
            if (progress.totalSteps > 0) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Step ${progress.currentStep} of ${progress.totalSteps}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (progress.promptId != null)
                    Text(
                      'ID: ${progress.promptId!.substring(0, 8)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
