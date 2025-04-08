import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/file_service.dart'; // Import the file service
import 'document_chat_widget.dart'; // Import the chat widget
import '../providers/selected_file_provider.dart'; // Import the provider
import 'medical_records_page.dart'; // Import medicalRecordsProvider (Renamed file)

// Placeholder provider for analysis results (replace with actual logic later)
final analysisResultsProvider = StateProvider<String>(
  (ref) => 'Analysis results will appear here...',
);

class AnalysisTabPage extends ConsumerWidget {
  const AnalysisTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the overall medical records list to determine initial state
    final allRecordsAsyncValue = ref.watch(
      medicalRecordsProvider,
    ); // Use renamed provider
    final analysisResults = ref.watch(analysisResultsProvider);
    final selectedFileState = ref.watch(
      selectedFileProvider,
    ); // Watch selected file state object

    // Main Column to hold content and chat widget
    return Column(
      children: [
        // Expanded content area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(
              left: 32.0,
              right: 32.0,
              top: 24.0,
              bottom: 12.0, // Reduced bottom padding to make space for chat
            ),
            child: Container(
              padding: const EdgeInsets.all(
                32.0, // Increased internal padding
              ),
              decoration: BoxDecoration(
                color: Colors.white, // Background color
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 1.0,
                ), // Solid border
                borderRadius: BorderRadius.circular(8.0), // Rounded corners
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3), // Shadow color
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3), // changes position of shadow
                  ),
                ],
              ),
              // Conditionally display content based on whether any records exist
              child: allRecordsAsyncValue.when(
                // Use renamed variable
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (err, stack) =>
                        Center(child: Text('Error checking for files: $err')),
                data: (fileList) {
                  if (fileList.isEmpty) {
                    // No files exist anywhere yet - show prompt and button
                    return Center(
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center, // Center vertically
                        children: [
                          Text(
                            'Add some medical records, and then push the Start Analysis button', // Updated text
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 24), // Spacing below text
                          ElevatedButton.icon(
                            onPressed: () async {
                              // Make async
                              final fileService = FileService(
                                ref,
                              ); // Instantiate service
                              final resultMessage = await fileService
                                  .pickAndAddFiles(context); // Call service
                              // Show result in SnackBar
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(resultMessage)),
                                );
                              }
                            },
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text(
                              'Add Medical Records',
                            ), // Rename label
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              textStyle:
                                  Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    // Files exist - show analysis placeholder/results
                    // TODO: Replace this with actual analysis results display later
                    return Center(
                      child: Text(
                        analysisResults, // Use the placeholder/results provider
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ),
        // Floating Chat Widget at the bottom
        DocumentChatWidget(
          selectedFilePath: selectedFileState.path,
        ), // Pass the path property
      ],
    );
  }
}
