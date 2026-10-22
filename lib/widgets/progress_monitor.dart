import 'package:flutter/material.dart';
import '../models/execution_state.dart';

class ProgressMonitor extends StatelessWidget {
  final ExecutionProgress progress;
  final VoidCallback? onCancel;
  final VoidCallback? onDismiss;

  const ProgressMonitor({
    super.key,
    required this.progress,
    this.onCancel,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (progress.status == ExecutionStatus.idle) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (progress.status == ExecutionStatus.error) {
      final errorColor = isDark ? Colors.red.shade300 : Colors.red.shade700;
      final errorCardBg = isDark
          ? Colors.red.shade900.withValues(alpha: 0.22)
          : Colors.red.shade50;
      final errorBorderColor = isDark
          ? Colors.red.shade700.withValues(alpha: 0.35)
          : Colors.red.shade200;
      final detailBg = isDark
          ? theme.colorScheme.surface
          : Colors.white;
      final detailBorder = isDark
          ? Colors.red.shade900.withValues(alpha: 0.4)
          : Colors.red.shade100;
      final detailTextColor = isDark
          ? theme.colorScheme.onSurface
          : Colors.red.shade900;

      return Card(
        color: errorCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: errorBorderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: errorColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      progress.statusMessage,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: errorColor,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (onDismiss != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: Icon(Icons.close, size: 18, color: errorColor),
                      tooltip: 'Dismiss',
                      onPressed: onDismiss,
                    ),
                ],
              ),
              if (progress.errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: detailBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: detailBorder),
                  ),
                  child: Text(
                    progress.errorMessage!,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: detailTextColor,
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
