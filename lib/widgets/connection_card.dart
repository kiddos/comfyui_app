import 'package:flutter/material.dart';
import '../services/comfyui_service.dart';
import '../services/database_service.dart';

enum ServerStatus {
  unknown,
  checking,
  connected,
  disconnected,
}

class ConnectionCard extends StatefulWidget {
  final String serverUrl;
  final ValueChanged<String> onUrlChanged;
  final VoidCallback? onConnected;

  const ConnectionCard({
    super.key,
    required this.serverUrl,
    required this.onUrlChanged,
    this.onConnected,
  });

  @override
  State<ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<ConnectionCard> {
  ServerStatus _status = ServerStatus.unknown;
  String? _lastCheckedTime;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  @override
  void didUpdateWidget(covariant ConnectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serverUrl != widget.serverUrl) {
      _checkConnection();
    }
  }

  Future<void> _checkConnection() async {
    if (!mounted) return;
    setState(() {
      _status = ServerStatus.checking;
    });

    final ok = await ComfyUIService.instance.testConnection(widget.serverUrl);
    if (!mounted) return;

    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    setState(() {
      _status = ok ? ServerStatus.connected : ServerStatus.disconnected;
      _lastCheckedTime = timeStr;
    });

    if (ok && widget.onConnected != null) {
      widget.onConnected!();
    }
  }

  void _showEditDialog() {
    final controller = TextEditingController(text: widget.serverUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings_ethernet, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('ComfyUI Server'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the address of your ComfyUI instance:',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Server URL',
                hintText: DatabaseService.defaultServerUrl,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.link),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => controller.clear(),
                ),
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () {
                controller.text = DatabaseService.defaultServerUrl;
              },
              icon: const Icon(Icons.restore, size: 16),
              label: const Text('Reset to default (192.168.0.198:8188)',
                  style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save & Connect'),
            onPressed: () async {
              final newUrl = ComfyUIService.normalizeUrl(controller.text);
              Navigator.pop(ctx);
              await DatabaseService.instance.setServerUrl(newUrl);
              widget.onUrlChanged(newUrl);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (_status) {
      case ServerStatus.connected:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Connected';
        break;
      case ServerStatus.disconnected:
        statusColor = Colors.redAccent;
        statusIcon = Icons.error;
        statusText = 'Offline / Unreachable';
        break;
      case ServerStatus.checking:
        statusColor = Colors.orange;
        statusIcon = Icons.sync;
        statusText = 'Checking...';
        break;
      case ServerStatus.unknown:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = 'Unknown';
        break;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: statusColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            statusText,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: statusColor,
                            ),
                          ),
                          if (_lastCheckedTime != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '($_lastCheckedTime)',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.serverUrl,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: _status == ServerStatus.checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  tooltip: 'Test Connection',
                  onPressed: _status == ServerStatus.checking
                      ? null
                      : _checkConnection,
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit Server URL',
                  onPressed: _showEditDialog,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
