import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:convert'; // For jsonDecode
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart'; // Import date formatting
import '../providers/selected_file_provider.dart'; // Import the provider
import '../providers/file_extraction_provider.dart'; // Import the new provider
import '../services/ai_service.dart';
import 'document_chat_widget.dart';

// Helper function to format bytes
String formatBytes(int bytes, [int decimals = 2]) {
  if (bytes <= 0) return "0 B";
  const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
  var i = (log(bytes) / log(1024)).floor();
  return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
}

// Provider to read and parse the .medoki.json file content
final medokiFileContentProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, filePath) async {
      // Construct path within the data-files subdirectory
      final originalFileDir = p.dirname(filePath);
      final originalFileName = p.basename(filePath);
      final dataFilesDir = p.join(originalFileDir, 'data-files');
      final medokiFilePath = p.join(
        dataFilesDir,
        '$originalFileName.medoki.json',
      );
      final file = File(medokiFilePath);

      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;
          return data; // Return the whole map (transcription + summary)
        } catch (e) {
          print("Error reading/parsing $medokiFilePath: $e");
          // Return null instead of throwing, let UI handle missing data
          return null;
        }
      }
      return null; // Return null if file doesn't exist
    });

// Convert to ConsumerStatefulWidget
class SummarySidebar extends ConsumerStatefulWidget {
  final String? selectedFilePath;
  final String? selectedFileName;
  final int? selectedFileSize;

  const SummarySidebar({
    super.key,
    required this.selectedFilePath,
    required this.selectedFileName,
    required this.selectedFileSize,
  });

  @override
  ConsumerState<SummarySidebar> createState() => _SummarySidebarState();
}

class _SummarySidebarState extends ConsumerState<SummarySidebar> {
  // Helper method to build the summary content area using provider state
  Widget _buildSummaryContent(
    BuildContext context,
    AsyncValue<Map<String, dynamic>?> medokiDataAsync,
    FileExtractionState extractionState, // Get extraction state as parameter
  ) {
    // --- Priority 1: Extraction Status ---
    if (extractionState.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(extractionState.currentStep ?? "Starting extraction..."),
          ],
        ),
      );
    } else if (extractionState.error != null) {
      // Show extraction error and the button to allow retrying
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Extraction Failed: ${extractionState.error!}",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
          ),
          _buildExtractButton(context), // Offer retry
        ],
      );
    }
    // --- Priority 2: Medoki File Status (only if extraction is idle/successful) ---
    else {
      return medokiDataAsync.when(
        // Show button while loading medoki file
        loading: () => _buildExtractButton(context),
        // Show error reading medoki file AND the button
        error: (err, stack) {
          print("Error reading medoki file: $err");
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Could not read existing analysis data.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ),
              _buildExtractButton(context), // Offer re-extract
            ],
          );
        },
        // Medoki file read attempted (data might be null or contain data)
        data: (medokiData) {
          final summary = medokiData?['summary'] as String?;
          // Case 1: Valid summary exists - show it
          if (summary != null && summary.isNotEmpty) {
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
          }
          // Case 2: No valid summary (medokiData is null OR summary is missing/empty) - show button
          else {
            return _buildExtractButton(context);
          }
        },
      );
    }
  }

  // Helper widget for the Extract button to avoid repetition
  Widget _buildExtractButton(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.biotech_outlined),
        label: const Text('Extract Data with AI'),
        onPressed: () {
          // Prevent triggering extraction if already loading (extra safety)
          if (ref
              .read(fileExtractionProvider(widget.selectedFilePath))
              .isLoading)
            return;

          if (widget.selectedFilePath != null) {
            ref
                .read(fileExtractionProvider(widget.selectedFilePath!).notifier)
                .extractData();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error: No file selected for extraction.'),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
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
      final dateTime = DateTime.parse(dateString).toLocal();
      final formattedDate = DateFormat.yMMMMd().format(dateTime);
      return Text(formattedDate, style: const TextStyle(fontSize: 13));
    } catch (e) {
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

  // --- Helper Function for Image Dialog ---
  void _showImageDialog(BuildContext context, String imagePath) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (
        BuildContext buildContext,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
      ) {
        return Align(
          alignment: const Alignment(-0.7, 0.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Dialog(
              insetPadding: const EdgeInsets.all(10.0),
              child: Container(
                padding: const EdgeInsets.all(12.0),
                child: InteractiveViewer(
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.file(
                    File(imagePath),
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 50,
                            ),
                            SizedBox(height: 8),
                            Text('Could not load image.'),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: animation.drive(CurveTween(curve: Curves.easeOutCubic)),
            child: child,
          ),
        );
      },
    );
  }
  // --- End Helper Function ---

  // --- Helper Function for Lab Results Table ---
  Widget _buildLabResultsTable(BuildContext context, dynamic labResultsData) {
    if (labResultsData == null ||
        !(labResultsData is List) ||
        labResultsData.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text(
          'No structured lab results found in document.',
          style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
        ),
      );
    }

    final labResults = labResultsData.cast<Map<String, dynamic>>();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 15,
        headingRowHeight: 30,
        dataRowMinHeight: 30,
        dataRowMaxHeight: 40,
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        dataTextStyle: const TextStyle(fontSize: 12),
        columns: const [
          DataColumn(label: Text('Test Name')),
          DataColumn(label: Text('Value')),
          DataColumn(label: Text('Units')),
          DataColumn(label: Text('Reference')),
        ],
        rows:
            labResults.map((result) {
              return DataRow(
                cells: [
                  DataCell(Text(result['test_name']?.toString() ?? '')),
                  DataCell(Text(result['value']?.toString() ?? '')),
                  DataCell(Text(result['units']?.toString() ?? '')),
                  DataCell(Text(result['reference_range']?.toString() ?? '')),
                ],
              );
            }).toList(),
      ),
    );
  }
  // --- End Helper Function ---

  @override
  Widget build(BuildContext context) {
    // Watch the medoki content provider for the selected file
    final medokiDataAsync =
        widget.selectedFilePath != null
            ? ref.watch(medokiFileContentProvider(widget.selectedFilePath!))
            : const AsyncValue.data(null);

    // Watch the extraction state provider for the selected file
    final extractionState = ref.watch(
      fileExtractionProvider(
        widget.selectedFilePath,
      ), // Watch state even if path is null
    );

    // --- Listener for Auto-Refresh after Extraction ---
    // Listen to the extraction provider state changes to trigger medoki refresh
    if (widget.selectedFilePath != null) {
      ref.listen<
        FileExtractionState
      >(fileExtractionProvider(widget.selectedFilePath!), (previous, next) {
        // Check if extraction just finished successfully
        if (previous?.isLoading == true &&
            !next.isLoading &&
            next.error == null) {
          print(
            "Extraction finished for ${widget.selectedFilePath!}, refreshing medoki content.",
          );
          // Refresh the medoki content provider to load the new data
          ref.refresh(medokiFileContentProvider(widget.selectedFilePath!));
        }
      });
    }
    // --- End Listener ---

    // Build the main content structure using Column
    return Column(
      children: [
        // --- Scrollable Content Area ---
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
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
                          Builder(
                            builder: (context) {
                              final filePath =
                                  widget
                                      .selectedFilePath!; // Safe ! due to outer check
                              final isImage = [
                                '.png',
                                '.jpg',
                                '.jpeg',
                                '.gif',
                                '.bmp',
                                '.webp',
                              ].any(
                                (ext) => filePath.toLowerCase().endsWith(ext),
                              );

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isImage)
                                    GestureDetector(
                                      onTap:
                                          () => _showImageDialog(
                                            context,
                                            filePath,
                                          ),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxHeight: 200,
                                        ),
                                        child: Container(
                                          margin: EdgeInsets.zero,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                              width: 1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4.0,
                                            ),
                                          ),
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Center(
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        3.0,
                                                      ),
                                                  child: Image.file(
                                                    File(filePath),
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
                                                              Icons
                                                                  .error_outline,
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
                                              Positioned(
                                                bottom: 4,
                                                right: 4,
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(0.4),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.zoom_in_map,
                                                    color: Colors.white,
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                            ],
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
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  const Text(
                                    'Test Date: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Expanded(
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
                          Container(
                            constraints: const BoxConstraints(minHeight: 100),
                            child: _buildSummaryContent(
                              context,
                              medokiDataAsync,
                              extractionState, // Pass extraction state
                            ),
                          ),
                          // --- End AI Summary Section ---

                          // --- Lab Results Section (Collapsible) ---
                          if (medokiDataAsync.hasValue &&
                              medokiDataAsync.value != null &&
                              (medokiDataAsync.value?['lab_results'] as List?)
                                      ?.isNotEmpty ==
                                  true)
                            Theme(
                              data: Theme.of(
                                context,
                              ).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 0,
                                ),
                                childrenPadding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 4.0,
                                ),
                                title: const Text(
                                  'Lab Results',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                initiallyExpanded: true,
                                children: [
                                  _buildLabResultsTable(
                                    context,
                                    medokiDataAsync.value?['lab_results'],
                                  ),
                                ],
                              ),
                            ),

                          // --- End Lab Results Section ---
                          const Divider(height: 8.0), // Add divider
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
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                      vertical: 8.0,
                                    ),
                                    child: SingleChildScrollView(
                                      child: SelectableText(
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
        DocumentChatWidget(selectedFilePath: widget.selectedFilePath),
        // --- End Floating Chat Widget ---
      ], // End of main Column
    );
  }
}
