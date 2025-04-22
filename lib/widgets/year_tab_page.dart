// Import dart:io for File operations
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
// Import path package
import 'year_records_grid.dart'; // Import YearRecordsGrid and the provider
import 'summary_sidebar.dart' as ss; // Import SummarySidebar with prefix
import '../providers/selected_file_provider.dart';
// Settings provider might not be needed directly here anymore
// import '../providers/settings_provider.dart';
// AI Service is now used internally by SummarySidebar
// import '../services/ai_service.dart';

// Change to ConsumerWidget
class YearTabPage extends ConsumerWidget {
  final String yearName;
  final String? basePath;
  final int refreshCounter; // Needed for the ValueKey
  // final String? selectedFilePath; // Removed - use provider
  // final Function(String filePath) onFileSelected; // Removed - use provider
  final VoidCallback onAddRecord;
  // final Widget sidebarWidget; // Removed - build sidebar here

  const YearTabPage({
    // Use a specific key combining year and counter for grid refresh
    required Key key,
    required this.yearName,
    required this.basePath,
    required this.refreshCounter,
    // required this.selectedFilePath, // Removed
    // required this.onFileSelected, // Removed
    required this.onAddRecord,
    // required this.sidebarWidget, // Removed
  }) : super(key: key); // Pass the key to the superclass

  // Removed _handleExtractData function as SummarySidebar now handles its own extraction

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the provider state
    final selectedFileState = ref.watch(selectedFileProvider);
    // Get the notifier to call methods
    final selectedFileNotifier = ref.read(selectedFileProvider.notifier);

    return Row(
      children: [
        // Main content area
        Expanded(
          child: YearRecordsGrid(
            // Use a ValueKey derived from the passed key's value for consistency
            // This assumes the key passed to YearTabPage is the ValueKey needed for the grid
            key: key,
            yearName: yearName,
            basePath: basePath,
            onAddRecord: onAddRecord,
            // Call notifier method on file selection
            onFileSelected:
                (filePath) => selectedFileNotifier.selectFile(filePath),
            // selectedFilePath removed - YearRecordsGrid gets it from provider now
          ),
        ),
        // Sidebar (build it here using provider state)
        Container(
          width: 350, // Keep width consistent
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.blueGrey[50],
            border: Border(
              left: BorderSide(color: Colors.blueGrey[200]!, width: 1.0),
            ),
          ),
          child: ss.SummarySidebar(
            // Use prefix for SummarySidebar
            // Pass only the required data to the sidebar
            // It now manages its own extraction state internally
            selectedFilePath: selectedFileState.path,
            selectedFileName: selectedFileState.name,
            selectedFileSize: selectedFileState.size,
            // Removed: aiSummaryContent, extractionError, isExtracting, onExtractDataPressed
          ),
        ),
      ],
    );
  }
}
