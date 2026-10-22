import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PromptEditor extends StatelessWidget {
  final TextEditingController positiveController;
  final TextEditingController negativeController;
  final bool randomizeSeed;
  final ValueChanged<bool> onRandomizeSeedChanged;
  final VoidCallback? onResetToDefault;

  const PromptEditor({
    super.key,
    required this.positiveController,
    required this.negativeController,
    required this.randomizeSeed,
    required this.onRandomizeSeedChanged,
    this.onResetToDefault,
  });

  void _copyToClipboard(BuildContext context, String text, String label) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Positive Prompt Card
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.green.withValues(alpha: 0.25), width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Positive Prompt',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'Copy Positive Prompt',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _copyToClipboard(
                        context,
                        positiveController.text,
                        'Positive Prompt',
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: 'Clear',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => positiveController.clear(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: positiveController,
                  maxLines: 5,
                  minLines: 3,
                  style: const TextStyle(fontSize: 14, height: 1.3),
                  decoration: InputDecoration(
                    hintText: 'Enter positive prompt (what you want to see)...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.green, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Negative Prompt Card
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.25), width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.do_not_disturb_on_outlined,
                        color: Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Negative Prompt',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'Copy Negative Prompt',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _copyToClipboard(
                        context,
                        negativeController.text,
                        'Negative Prompt',
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: 'Clear',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => negativeController.clear(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: negativeController,
                  maxLines: 4,
                  minLines: 2,
                  style: const TextStyle(fontSize: 14, height: 1.3),
                  decoration: InputDecoration(
                    hintText: 'Enter negative prompt (what you want to avoid)...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Settings row (Random seed toggle & Reset to default prompt)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Switch.adaptive(
                  value: randomizeSeed,
                  onChanged: onRandomizeSeedChanged,
                  activeTrackColor: Colors.deepPurple,
                ),
                const Text(
                  'Randomize Seed',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            if (onResetToDefault != null)
              TextButton.icon(
                icon: const Icon(Icons.restart_alt, size: 16),
                label: const Text('Reset Prompts', style: TextStyle(fontSize: 12)),
                onPressed: onResetToDefault,
              ),
          ],
        ),
      ],
    );
  }
}
