import 'package:flutter/material.dart';

class WorkflowPicker extends StatelessWidget {
  final List<String> workflows;
  final String? selectedWorkflow;
  final ValueChanged<String> onSelected;

  const WorkflowPicker({
    super.key,
    required this.workflows,
    required this.selectedWorkflow,
    required this.onSelected,
  });

  String _cleanName(String filename) {
    return filename.replaceAll('.json', '');
  }

  String _getCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.startsWith('flux')) return 'Flux';
    if (lower.startsWith('sdxl')) return 'SDXL';
    if (lower.startsWith('animatediff')) return 'AnimateDiff';
    if (lower.startsWith('pony')) return 'Pony';
    if (lower.startsWith('animagine')) return 'Animagine';
    if (lower.startsWith('illustrious')) return 'Illustrious';
    return 'Workflow';
  }

  Color _getCategoryColor(String category, {bool isDark = false}) {
    if (isDark) {
      switch (category) {
        case 'Flux':
          return Colors.indigo.shade300;
        case 'SDXL':
          return Colors.teal.shade300;
        case 'AnimateDiff':
          return Colors.purple.shade300;
        case 'Pony':
          return Colors.pink.shade300;
        case 'Animagine':
          return Colors.orange.shade300;
        case 'Illustrious':
          return Colors.blueGrey.shade300;
        default:
          return Colors.deepPurple.shade300;
      }
    }
    switch (category) {
      case 'Flux':
        return Colors.indigo;
      case 'SDXL':
        return Colors.teal;
      case 'AnimateDiff':
        return Colors.purple;
      case 'Pony':
        return Colors.pink;
      case 'Animagine':
        return Colors.orange;
      case 'Illustrious':
        return Colors.blueGrey;
      default:
        return Colors.deepPurple;
    }
  }

  void _showPickerBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _WorkflowPickerSheet(
        workflows: workflows,
        selectedWorkflow: selectedWorkflow,
        cleanName: _cleanName,
        getCategory: _getCategory,
        getCategoryColor: (cat) => _getCategoryColor(cat, isDark: isDark),
        onSelected: (chosen) {
          Navigator.pop(ctx);
          onSelected(chosen);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final category = selectedWorkflow != null ? _getCategory(selectedWorkflow!) : '';
    final categoryColor = _getCategoryColor(category, isDark: isDark);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _showPickerBottomSheet(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: isDark ? 0.25 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.hub_outlined, color: categoryColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Selected Workflow',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (category.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: isDark ? 0.25 : 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: categoryColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedWorkflow != null
                          ? _cleanName(selectedWorkflow!)
                          : 'Choose a workflow from workflows/',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: selectedWorkflow != null
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_drop_down_circle_outlined,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkflowPickerSheet extends StatefulWidget {
  final List<String> workflows;
  final String? selectedWorkflow;
  final String Function(String) cleanName;
  final String Function(String) getCategory;
  final Color Function(String) getCategoryColor;
  final ValueChanged<String> onSelected;

  const _WorkflowPickerSheet({
    required this.workflows,
    required this.selectedWorkflow,
    required this.cleanName,
    required this.getCategory,
    required this.getCategoryColor,
    required this.onSelected,
  });

  @override
  State<_WorkflowPickerSheet> createState() => _WorkflowPickerSheetState();
}

class _WorkflowPickerSheetState extends State<_WorkflowPickerSheet> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'SDXL',
    'Flux',
    'AnimateDiff',
    'Pony',
    'Animagine',
    'Illustrious',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filtered = widget.workflows.where((wf) {
      final name = widget.cleanName(wf).toLowerCase();
      final category = widget.getCategory(wf);
      final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Select Workflow',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.workflows.length} available',
                  style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search workflows...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No workflows match your search',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (context, idx) {
                        final wf = filtered[idx];
                        final isSelected = wf == widget.selectedWorkflow;
                        final category = widget.getCategory(wf);
                        final color = widget.getCategoryColor(category);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: isDark ? 0.25 : 0.15),
                            child: Icon(Icons.account_tree_outlined, color: color, size: 20),
                          ),
                          title: Text(
                            widget.cleanName(wf),
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            category,
                            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                              : null,
                          onTap: () => widget.onSelected(wf),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
