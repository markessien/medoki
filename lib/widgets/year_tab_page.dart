import 'dart:io'; // Import dart:io for File operations
import 'dart:io'; // Import dart:io for File operations
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:path/path.dart' as p; // Import path package
import 'year_records_grid.dart'; // Import YearRecordsGrid and the provider
import 'summary_sidebar.dart'; // Import SummarySidebar
import '../providers/selected_file_provider.dart'; // Import the provider
import '../providers/settings_provider.dart'; // Import the settings provider
import '../services/ai_service.dart'; // Import the AI service

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

  // Function to handle AI extraction
  Future<void> _handleExtractData(
    BuildContext context,
    WidgetRef ref,
    String? filePath,
  ) async {
    // API key is no longer read here; AIService handles it internally.

    if (filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot extract data: No file selected.")),
      );
      return;
    }

    // Set extracting state to true
    ref.read(selectedFileProvider.notifier).setExtracting(true);
    // Remove snackbar as status is shown in sidebar now
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(content: Text("Extracting data for ${p.basename(filePath)}...")),
    // );

    try {
      final aiService =
          AIService(); // Create instance (consider providing via Riverpod later)
      // Call the updated service method (no apiKey needed here)
      final extractedData = await aiService.extractDataFromFile(filePath);

      // Hide loading indicator (no longer needed)
      // ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Note: setExtracting(false) is called implicitly by selectFile or setExtractionError

      if (extractedData != null && !extractedData.startsWith("Error:")) {
        // --- Save the extracted data to .medoki.md file ---
        final medokiFilePath = '$filePath.medoki.md';
        final medokiFile = File(medokiFilePath);
        await medokiFile.writeAsString(extractedData);
        print("AI data saved to: $medokiFilePath");

        // --- Update the medokiStatusProvider for this year ---
        ref
            .read(medokiStatusProvider(yearName).notifier)
            .update(
              (state) => {...state, filePath}, // Add the file path to the set
            );

        // --- Refresh the selected file provider to show new content ---
        // This will re-read the .medoki.md file we just saved
        await ref.read(selectedFileProvider.notifier).selectFile(filePath);

        // Grid refresh is now handled automatically by watching the provider

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("AI data extracted and saved successfully!"),
          ),
        );
      } else {
        // Set error state in the provider
        final errorMessage = extractedData ?? "AI extraction failed.";
        ref
            .read(selectedFileProvider.notifier)
            .setExtractionError(errorMessage);
        // Optionally show snackbar as well
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text(errorMessage)),
        // );
      }
    } catch (e) {
      // Hide loading indicator (no longer needed)
      // ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final errorMessage = "An error occurred during extraction: $e";
      print("Error in _handleExtractData: $e");
      // Set error state in the provider
      ref.read(selectedFileProvider.notifier).setExtractionError(errorMessage);
      // Optionally show snackbar as well
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text(errorMessage)),
      // );
    }
  }

  @override
  // Add WidgetRef ref
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
          child: SummarySidebar(
            selectedFilePath: selectedFileState.path,
            selectedFileName: selectedFileState.name,
            selectedFileSize: selectedFileState.size,
            aiSummaryContent: selectedFileState.aiSummaryContent,
            extractionError: selectedFileState.extractionError,
            isExtracting:
                selectedFileState.isExtracting, // Pass extracting state
            // Pass the actual callback, wrapped to include context
            onExtractDataPressed:
                () => _handleExtractData(
                  context, // Pass BuildContext for ScaffoldMessenger
                  ref,
                  selectedFileState.path,
                ),
          ),
        ),
      ],
    );
  }
}
