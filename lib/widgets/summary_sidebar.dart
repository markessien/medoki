import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:convert'; // For jsonDecode
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart'; // Import date formatting
import '../providers/selected_file_provider.dart'; // Import the provider
import '../providers/file_extraction_provider.dart'; // Import the new provider
import '../services/ai_service.dart';
import 'document_chat_widget.dart';

// Helper function to format bytes (moved from main.dart)
String formatBytes(int bytes, [int decimals = 2]) {
  if (bytes <= 0) return "0 B";
  const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
  var i = (log(bytes) / log(1024)).floor();
  return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
}

// Provider to read and parse the .medoki.md file content
final medokiFileContentProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, filePath) async {
      final medokiFilePath = '$filePath.medoki.md';
      final file = File(medokiFilePath);

      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;
          return data; // Return the whole map (transcription + summary)
        } catch (e) {
          print("Error reading/parsing $medokiFilePath: $e");
          throw Exception(
            'Error reading analysis file: $e',
          ); // Throw for error state
        }
      }
      return null; // Return null if file doesn't exist
    });

// Convert to ConsumerStatefulWidget
class SummarySidebar extends ConsumerStatefulWidget {
  final String? selectedFilePath;
  final String? selectedFileName;
  final int? selectedFileSize;
  // Remove parameters managed internally or by provider:
  // final String? aiSummaryContent;
  // final String? extractionError;
  // final bool isExtracting;
  // final VoidCallback? onExtractDataPressed;

  const SummarySidebar({
    super.key,
    required this.selectedFilePath,
    required this.selectedFileName,
    required this.selectedFileSize,
    // Remove parameters from constructor
  });

  @override
  ConsumerState<SummarySidebar> createState() => _SummarySidebarState();
}

class _SummarySidebarState extends ConsumerState<SummarySidebar> {
  // Local state and extraction method removed - now handled by fileExtractionProvider

  // Helper method to build the summary content area using provider state
  Widget _buildSummaryContent(
    BuildContext context,
    AsyncValue<Map<String, dynamic>?> medokiDataAsync,
    FileExtractionState extractionState, // Get extraction state as parameter
  ) {
    // Priority: Extraction Loading > Extraction Error > Medoki Loading > Medoki Error > Medoki Content > Button
    if (extractionState.isLoading) {
      // Display loading indicator from extraction provider
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Extracting data..."),
          ],
        ),
      );
    } else if (extractionState.error != null) {
      // Display the error message from extraction provider
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            extractionState.error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 13,
            ),
          ),
        ),
      );
    } else {
      // Use the medoki content provider's state
      return medokiDataAsync.when(
        loading:
            () => const Center(
              child: CircularProgressIndicator(),
            ), // Loading medoki file
        error: // Error loading medoki file
            (err, stack) => SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Error loading summary: $err',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        data: (medokiData) {
          final summary = medokiData?['summary'] as String?;
          if (summary != null && summary.isNotEmpty) {
            // Display the summary text from medoki provider
            return TextField(
              controller: TextEditingController(text: summary),
              maxLines: null,
              readOnly: true,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.all(8.0),
              ),
              style: const TextStyle(fontSize: 13),
            );
          } else {
            // Display the button if no summary exists (and no extraction error/loading)
            return Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.biotech_outlined),
                label: const Text('Extract Data with AI'),
                onPressed:
                    () =>
                        ref
                            .read(
                              fileExtractionProvider(
                                widget.selectedFilePath,
                              ).notifier,
                            )
                            .extractData(), // Call provider method
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            );
          }
        },
      );
    }
  }

  // Helper to format and display the date
  Widget _buildDateDisplay(BuildContext context, String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return const Text(
        'Date not available in document.',
        style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
      );
    }
    try {
      // Attempt to parse the date string (assuming ISO 8601 format)
      final dateTime = DateTime.parse(dateString).toLocal();
      // Format the date nicely (e.g., "July 15, 2024")
      final formattedDate = DateFormat.yMMMMd().format(dateTime);
      return Text(formattedDate, style: const TextStyle(fontSize: 13));
    } catch (e) {
      // Handle cases where the date string is not in the expected format
      print("Error parsing date string '$dateString': $e");
      return Text(
        'Invalid date format found: $dateString',
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  // _buildSidebarHeader method removed - header is now in AppToolbar

  @override
  Widget build(BuildContext context) {
    // Watch the medoki content provider
    final medokiDataAsync =
        widget.selectedFilePath != null
            ? ref.watch(medokiFileContentProvider(widget.selectedFilePath!))
            : const AsyncValue.data(null);

    // Watch the extraction state provider for the current file
    final extractionState = ref.watch(
      fileExtractionProvider(widget.selectedFilePath),
    );

    // Build the main content structure using Column
    return Column(
      children: [
        // --- Header removed from here ---

        // --- Scrollable Content Area ---
        Expanded(
          // Make the content scrollable
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8.0), // Add padding around content
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                // Only show content if a file is selected
                children:
                    widget.selectedFilePath == null
                        ? [
                          // Show 'Select a file' message if nothing is selected
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.only(top: 50.0),
                              child: Text(
                                'Select a file to see details.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ]
                        : [
                          // --- Top Section (Image/Placeholder, Details) ---
                          // Calculate isImage and build the top section only when filePath is not null
                          Builder(
                            builder: (context) {
                              // Safe to use ! here because we are inside the non-null check block
                              final isImage = [
                                '.png',
                                '.jpg',
                                '.jpeg',
                                '.gif',
                                '.bmp',
                                '.webp',
                              ].any(
                                (ext) => widget.selectedFilePath!
                                    .toLowerCase()
                                    .endsWith(ext),
                              );

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isImage)
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxHeight: 200,
                                      ),
                                      child: Container(
                                        margin: EdgeInsets.zero,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            4.0,
                                          ),
                                          child: Center(
                                            child: Image.file(
                                              File(widget.selectedFilePath!),
                                              fit: BoxFit.contain,
                                              errorBuilder: (
                                                context,
                                                error,
                                                stackTrace,
                                              ) {
                                                return const Center(
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        Icons.error_outline,
                                                        color: Colors.red,
                                                        size: 40,
                                                      ),
                                                      SizedBox(height: 8),
                                                      Text(
                                                        'Could not load image preview.',
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      height: 150,
                                      margin: EdgeInsets.zero,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          4.0,
                                        ),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.insert_drive_file_outlined,
                                          size: 50,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 8.0),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            widget.selectedFileName ??
                                                'Unknown File',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.normal,
                                              fontSize: 11,
                                              height: 0.8,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        Text(
                                          widget.selectedFileSize != null
                                              ? formatBytes(
                                                widget.selectedFileSize!,
                                              )
                                              : 'Unknown size',
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontSize: 10,
                                            height: 0.8,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8.0),
                                  // --- End Top Section ---
                                ],
                              );
                            },
                          ),

                          // --- Test Date Section (Direct Display) ---
                          // Only show if medoki data is loaded successfully
                          if (medokiDataAsync.hasValue &&
                              medokiDataAsync.value != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 4.0,
                              ), // Add padding
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .baseline, // Align text baselines
                                textBaseline:
                                    TextBaseline
                                        .alphabetic, // Specify the baseline type
                                children: [
                                  const Text(
                                    'Test Date: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Expanded(
                                    // Allow date text to wrap if needed
                                    child: _buildDateDisplay(
                                      context,
                                      medokiDataAsync.value?['testDateUTC']
                                          as String?,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // --- End Test Date Section ---

                          // --- AI Summary Section ---
                          const Divider(height: 8.0),
                          // Use Container with height constraints for summary area
                          Container(
                            constraints: const BoxConstraints(minHeight: 100),
                            child: _buildSummaryContent(
                              context,
                              medokiDataAsync,
                              extractionState, // Pass extraction state
                            ),
                          ),
                          // --- End AI Summary Section ---

                          // --- Full Transcription Section (Collapsible) ---
                          if (medokiDataAsync.hasValue &&
                              medokiDataAsync.value != null)
                            Theme(
                              data: Theme.of(
                                context,
                              ).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 0,
                                ),
                                dense: true,
                                title: const Text(
                                  'Full Extracted Text',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                initiallyExpanded: false,
                                children: <Widget>[
                                  Container(
                                    constraints: const BoxConstraints(
                                      maxHeight: 300,
                                    ), // Limit height
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                      vertical: 8.0,
                                    ),
                                    child: SingleChildScrollView(
                                      // Allow scrolling for long text
                                      child: SelectableText(
                                        // Use SelectableText for copying
                                        medokiDataAsync.value?['transcription']
                                                as String? ??
                                            'Transcription not available.',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // --- End Full Transcription Section ---
                        ], // End of children when file is selected
              ),
            ),
          ),
        ),
        // --- Floating Chat Widget (Positioned at the bottom) ---
        const Divider(height: 1), // Add a divider above chat
        DocumentChatWidget(
          selectedFilePath: widget.selectedFilePath,
        ), // Use widget.
        // --- End Floating Chat Widget ---
      ], // End of main Column
    );
  }
}
