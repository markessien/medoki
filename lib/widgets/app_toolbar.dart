import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import '../providers/selected_file_provider.dart'; // Import the provider

// Change to ConsumerWidget
class AppToolbar extends ConsumerWidget implements PreferredSizeWidget {
  final int currentIndex;
  final int analysisTabIndex;
  // final String? selectedFilePath; // Removed - will get from provider
  final VoidCallback onAddRecord;
  // final VoidCallback onClearSelection; // Removed - will call provider directly
  // Add placeholders for other actions if needed later
  // final VoidCallback onSearch;
  // final VoidCallback onFilter;
  // final VoidCallback onGenerateReport;

  const AppToolbar({
    super.key,
    required this.currentIndex,
    required this.analysisTabIndex,
    // required this.selectedFilePath, // Removed
    required this.onAddRecord,
    // required this.onClearSelection, // Removed
    // required this.onSearch,
    // required this.onFilter,
    // required this.onGenerateReport,
  });

  @override
  // Add WidgetRef ref parameter
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the provider state
    final selectedFileState = ref.watch(selectedFileProvider);

    // This logic is moved from _buildToolbarContent in main.dart
    return Container(
      height: kToolbarHeight, // Use standard toolbar height
      color: Theme.of(context).colorScheme.surface,
      // Pass ref down
      child: _buildToolbarContent(context, ref, selectedFileState),
    );
  }

  // Build the content based on the current tab
  // Add WidgetRef ref and SelectedFileState selectedFileState parameters
  Widget _buildToolbarContent(
    BuildContext context,
    WidgetRef ref,
    SelectedFileState selectedFileState,
  ) {
    if (currentIndex == analysisTabIndex) {
      // Content for the Analysis tab toolbar
      return Row(
        mainAxisAlignment: MainAxisAlignment.center, // Center the button
        children: [
          ElevatedButton.icon(
            onPressed: () {
              // Placeholder action for generating report
              // onGenerateReport(); // Call if implemented
            },
            icon: const Icon(Icons.assessment),
            label: const Text('Generate Report'),
          ),
        ],
      );
    } else {
      // Content for the Year tabs toolbar
      return Row(
        children: [
          // Left side: Controls
          Expanded(
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: ElevatedButton.icon(
                    onPressed: onAddRecord, // Use the passed callback
                    icon: const Icon(Icons.add),
                    label: const Text('Add medical records...'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                const Spacer(), // Pushes Search/Filter to the right
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    // Placeholder action for search
                    // onSearch(); // Call if implemented
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: () {
                    // Placeholder action for filter
                    // onFilter(); // Call if implemented
                  },
                ),
              ],
            ),
          ),
          // Vertical divider
          const VerticalDivider(
            width: 1,
            thickness: 1,
            indent: 8,
            endIndent: 8,
          ),
          // Right side: Dynamic Header
          Container(
            width: 350, // Match sidebar width
            alignment: Alignment.center,
            // Pass ref and state down
            child: _buildSidebarHeader(ref, selectedFileState),
          ),
        ],
      );
    }
  }

  // Build the dynamic sidebar header (moved from main.dart)
  // Add WidgetRef ref and SelectedFileState selectedFileState parameters
  Widget _buildSidebarHeader(
    WidgetRef ref,
    SelectedFileState selectedFileState,
  ) {
    if (selectedFileState.path == null) {
      // Check state from provider
      // Default "Summary" title
      return const Text(
        'Summary',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      );
    } else {
      // "Back" button and "File Information" title
      return Row(
        mainAxisAlignment: MainAxisAlignment.center, // Center content
        children: [
          Padding(
            // Add padding to the left of the button
            padding: const EdgeInsets.only(left: 8.0),
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              // Call provider notifier method directly
              onPressed:
                  () =>
                      ref.read(selectedFileProvider.notifier).clearSelection(),
              tooltip: 'Back to Summary',
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(
                right: 8.0,
              ), // Keep existing right padding if needed, or adjust
            ),
          ),
          const Expanded(
            child: Text(
              'File Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 48), // Balance the IconButton
        ],
      );
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
