import 'package:flutter/material.dart';
import '../widgets/server_history_view.dart';

class ServerHistoryScreen extends StatefulWidget {
  final String? initialServerUrl;
  final Function(String workflow, String positive, String negative)? onReusePrompt;
  final VoidCallback? onImageSaved;

  const ServerHistoryScreen({
    super.key,
    this.initialServerUrl,
    this.onReusePrompt,
    this.onImageSaved,
  });

  @override
  State<ServerHistoryScreen> createState() => _ServerHistoryScreenState();
}

class _ServerHistoryScreenState extends State<ServerHistoryScreen> {
  final GlobalKey<ServerHistoryViewState> _viewKey = GlobalKey<ServerHistoryViewState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Prompt History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_search),
            tooltip: 'Lookup Prompt ID',
            onPressed: () {
              _viewKey.currentState?.showLookupPromptIdDialog();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh History',
            onPressed: () {
              _viewKey.currentState?.reloadHistory();
            },
          ),
        ],
      ),
      body: ServerHistoryView(
        key: _viewKey,
        initialServerUrl: widget.initialServerUrl,
        onReusePrompt: widget.onReusePrompt,
        onImageSaved: widget.onImageSaved,
      ),
    );
  }
}
