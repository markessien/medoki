import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert'; // For JSON decoding
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart'; // For kDebugMode

import '../providers/selected_file_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_service.dart'; // Still needed for settings enum? Maybe not.
import '../services/file_service.dart';
import '../services/batch_analysis_service.dart';
import '../services/settings_service.dart'; // Needed to get records path
import '../services/trend_analysis_service.dart'; // Import the new service
import 'medical_records_page.dart';
import '../providers/file_extraction_provider.dart';
import 'recommendations_confirmation_dialog.dart'; // Keep for batch analysis button
import '../widgets/analysis_tab_page.dart'; // Import analysisResultsProvider

// Change to ConsumerStatefulWidget to manage TextEditingController and debounce Timer
class AppToolbar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  final int currentIndex;
  final int analysisTabIndex;
  final VoidCallback onAddRecord;
  // Add other callbacks if needed

  const AppToolbar({
    super.key,
    required this.currentIndex,
    required this.analysisTabIndex,
    required this.onAddRecord,
    // Add other callbacks if needed
  });

  @override
  ConsumerState<AppToolbar> createState() => _AppToolbarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _AppToolbarState extends ConsumerState<AppToolbar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  bool _isSearchExpanded = false;
  bool _isBatchAnalysisRunning = false; // Renamed for clarity
  bool _isTrendAnalysisRunning = false; // State for the new analysis

  @override
  void initState() {
    super.initState();
    // Initialize search field if needed from provider state (optional)
    // _searchController.text = ref.read(searchQueryProvider);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose(); // Dispose focus node
    _debounce?.cancel();
    super.dispose();
  }

  // Debounce search input
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      // Update the provider only after debounce duration
      if (mounted) {
        // Check if widget is still mounted
        ref.read(searchQueryProvider.notifier).state = _searchController.text;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch the provider state needed for the header
    final selectedFileState = ref.watch(selectedFileProvider);

    return Container(
      height: kToolbarHeight, // Use standard toolbar height
      color: Theme.of(context).colorScheme.surface,
      child: _buildToolbarContent(context, ref, selectedFileState),
    );
  }

  // Build the content based on the current tab
  Widget _buildToolbarContent(
    BuildContext context,
    WidgetRef ref, // ref is available via ConsumerState
    SelectedFileState selectedFileState,
  ) {
    // Access widget properties using widget.propertyName
    if (widget.currentIndex == widget.analysisTabIndex) {
      // Content for the Analysis tab toolbar
      return _buildAnalysisToolbarContent(context, ref);
    } else {
      // Content for the Medical Records tab toolbar
      return _buildMedicalRecordsToolbarContent(
        context,
        ref,
        selectedFileState,
      );
    }
  }

  // --- Helper Method for Analysis Tab Toolbar ---
  Widget _buildAnalysisToolbarContent(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start, // Align button to the left
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0),
          // Restore original placeholder behavior for Start Analysis button
          child: ElevatedButton.icon(
            onPressed:
                _isTrendAnalysisRunning
                    ? null
                    : _startTrendAnalysis, // Call the new method
            icon:
                _isTrendAnalysisRunning
                    ? Container(
                      width: 24,
                      height: 24,
                      padding: const EdgeInsets.all(2.0),
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                    : const Icon(Icons.science_outlined), // Keep icon
            label: Text(
              _isTrendAnalysisRunning ? 'Analyzing...' : 'Start Trend Analysis',
            ), // Update label based on state
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
        // Add other analysis-specific toolbar items here if needed in the future
      ],
    );
  }

  // --- Helper Method for Medical Records Tab Toolbar ---
  Widget _buildMedicalRecordsToolbarContent(
    BuildContext context,
    WidgetRef ref,
    SelectedFileState selectedFileState,
  ) {
    return Row(
      children: [
        // Left side: Controls (Add button and Filters)
        Expanded(
          child: Row(
            children: [
              // Add Button
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Make async
                    final fileService = FileService(ref); // Instantiate service
                    final resultMessage = await fileService.pickAndAddFiles(
                      context,
                    ); // Call service
                    // Show result in SnackBar
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(resultMessage)));
                    }
                    // Note: widget.onAddRecord is likely obsolete now, but kept for compatibility unless removed elsewhere
                    // widget.onAddRecord();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Medical Records...'), // Rename label
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 16), // Keep spacing before filters
              // Filter Chips
              Expanded(child: _buildFilterChips(ref)), // Wrap chips in Expanded
              const SizedBox(
                width: 8,
              ), // Reduced spacing before search icon/field
              // AnimatedSwitcher for Search Icon/Field
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child:
                    _isSearchExpanded
                        ? Container(
                          // Container to constrain width
                          key: const ValueKey('searchField'),
                          width: 250, // Adjust width as needed
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            decoration: InputDecoration(
                              hintText: 'Search files...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              border: OutlineInputBorder(
                                // Corrected border definition
                                borderRadius: BorderRadius.circular(20.0),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.7),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 0,
                              ),
                              isDense: true,
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _isSearchExpanded = false;
                                  });
                                  _searchFocusNode
                                      .unfocus(); // Unfocus when closing
                                  ref.read(searchQueryProvider.notifier).state =
                                      ''; // Clear provider state immediately
                                },
                              ),
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        )
                        : IconButton(
                          // Show search icon when not expanded
                          key: const ValueKey('searchIcon'),
                          icon: const Icon(Icons.search),
                          tooltip: 'Search Files',
                          onPressed: () {
                            setState(() {
                              _isSearchExpanded = true;
                            });
                            _searchFocusNode
                                .requestFocus(); // Focus field on expand
                          },
                        ),
              ),
              // Optional: Keep filter icon if needed for advanced filtering
            ],
          ),
        ),
        // Add back the divider and a SizedBox to constrain the Expanded section above
        const VerticalDivider(width: 1, thickness: 1, indent: 8, endIndent: 8),
        // Replace SizedBox with the actual header content
        Container(
          width: 350, // Match sidebar width
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          alignment: Alignment.center,
          child: _buildDynamicSidebarHeader(
            ref,
            selectedFileState,
          ), // Call helper
        ),
      ],
    );
  }

  // --- New Helper Method for Dynamic Sidebar Header ---
  Widget _buildDynamicSidebarHeader(
    WidgetRef ref,
    SelectedFileState selectedFileState,
  ) {
    final selectedFilePath = selectedFileState.path;

    if (selectedFilePath == null) {
      // Default "Details" title when no file is selected
      // Consistent padding/border might not be needed if toolbar has its own styling
      return const Center(
        child: Text(
          'Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );
    } else {
      // Watch the extraction state for the selected file
      final extractionState = ref.watch(
        fileExtractionProvider(selectedFilePath),
      );
      final bool isExtracting = extractionState.isLoading;

      // Header when a file is selected: Back button, Title, Refresh button
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed:
                () => ref.read(selectedFileProvider.notifier).clearSelection(),
            tooltip: 'Back to Details',
            iconSize: 20.0,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          // Title (takes available space)
          const Expanded(
            child: Text(
              'File Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Refresh Button (conditionally enabled)
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed:
                isExtracting
                    ? null // Disable if already extracting
                    : () =>
                        ref
                            .read(
                              fileExtractionProvider(selectedFilePath).notifier,
                            )
                            .extractData(), // Call provider method
            tooltip: 'Rescan file with AI',
            iconSize: 20.0,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color:
                isExtracting
                    ? Colors
                        .grey // Grey out when disabled
                    : Theme.of(context).colorScheme.primary,
          ),
        ],
      );
    }
  }
  // --- End New Helper Method ---

  // Removed _buildSidebarHeader method - logic moved to SummarySidebar

  // Helper to build filter chips using medicalRecordsProvider
  Widget _buildFilterChips(WidgetRef ref) {
    // Watch the main provider that now contains available years
    final recordsAsyncValue = ref.watch(medicalRecordsProvider);
    final selectedYear = ref.watch(
      yearFilterProvider,
    ); // Still watch the filter state (int?)
    final yearNotifier = ref.read(yearFilterProvider.notifier);

    return recordsAsyncValue.when(
      data: (data) {
        final availableYears =
            data.availableYears; // This is List<int>, already sorted descending
        if (availableYears.isEmpty) {
          return const SizedBox.shrink(); // No years derived, show nothing
        }

        // Use SingleChildScrollView for horizontal scrolling
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // "All" Chip
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: FilterChip(
                  label: const Text('All'),
                  selected: selectedYear == null,
                  onSelected: (selected) {
                    if (selected) {
                      yearNotifier.state = null; // Set filter to null for 'All'
                    }
                  },
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                ),
              ),
              // Year Chips (use availableYears - List<int>)
              ...availableYears.map(
                (year) => Padding(
                  // year is an int here
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: FilterChip(
                    label: Text(
                      year.toString(),
                    ), // Convert int year to String for label
                    selected: selectedYear == year, // Compare int? with int
                    onSelected: (selected) {
                      // Assign int year directly to the StateProvider<int?>
                      yearNotifier.state = selected ? year : null;
                    },
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading:
          () => const SizedBox(
            // Show a small indicator while loading records/years
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      error:
          (err, stack) => Tooltip(
            // Show error icon on failure
            message: 'Error loading year filters: $err', // Show error message
            child: const Icon(Icons.error_outline, color: Colors.red, size: 18),
          ),
    );
  }

  // Method to handle the BATCH analysis process (generating .medoki.md files)
  Future<void> _startBatchAnalysis() async {
    if (_isBatchAnalysisRunning) return; // Use renamed state variable

    // Show Confirmation Dialog first (using settings for path check within service)
    // We need to estimate the count beforehand or show a generic message.
    // For simplicity, let's show a generic confirmation first.
    // A more advanced approach would involve a preliminary scan by the service.
    final bool? shouldProceed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        // Using a generic message as file count isn't known yet easily
        return const RecommendationsConfirmationDialog();
      },
    );

    if (shouldProceed != true) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Analysis cancelled.')));
      }
      return; // Exit if user cancels
    }

    // Set state to running and show initial feedback
    setState(() {
      _isBatchAnalysisRunning = true; // Use renamed state variable
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Starting analysis of medical records...'),
          duration: Duration(seconds: 2),
        ),
      );
      ref.read(analysisResultsProvider.notifier).state =
          'Analysis starting... Please wait.';
    }

    final batchService = ref.read(
      batchAnalysisServiceProvider,
    ); // Read the provider
    int totalFiles = 0; // Keep track of total files reported by the service
    int processedCount = 0;
    final List<String> errorMessages = [];

    try {
      await batchService.runBatchAnalysis(
        // Call without ref argument
        onProgress: (message) {
          print("Batch Progress: $message");
          if (mounted) {
            // Update the analysis results provider with progress
            ref.read(analysisResultsProvider.notifier).state = message;
          }
        },
        onError: (error) {
          print("Batch Error: $error");
          errorMessages.add(error);
          if (mounted) {
            // Show errors as they occur? Or just collect them?
            // Let's collect and show a summary at the end.
            // Optionally update the provider state with error count?
          }
        },
        onFileProcessed: (processed, total) {
          // Update counts for final summary
          processedCount = processed;
          totalFiles = total;
          // Optional: Update UI more granularly if needed
          // ref.read(analysisResultsProvider.notifier).state = 'Processed $processed of $total files...';
        },
      );

      // Analysis finished (successfully or with errors handled by onError)
      if (mounted) {
        String finalMessage;
        if (errorMessages.isEmpty) {
          finalMessage =
              'Batch analysis completed successfully. Processed $processedCount files.';
        } else {
          finalMessage =
              'Batch analysis completed with ${errorMessages.length} errors out of $totalFiles files processed.';
          // Optionally show detailed errors
          print('Errors encountered:\n${errorMessages.join('\n')}');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(finalMessage),
            duration: const Duration(seconds: 5),
          ),
        );
        ref.read(analysisResultsProvider.notifier).state = finalMessage;
      }
    } catch (e) {
      // Catch unexpected errors during the service call itself
      print("Unexpected error during batch analysis service execution: $e");
      if (mounted) {
        final errorMessage =
            'An unexpected error occurred during batch analysis: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
          ),
        );
        ref.read(analysisResultsProvider.notifier).state = errorMessage;
      }
    } finally {
      // Ensure the running state is always reset
      if (mounted) {
        setState(() {
          _isBatchAnalysisRunning = false; // Use renamed state variable
        });
      }
    }
  }

  // --- New Method for Trend Analysis ---
  Future<void> _startTrendAnalysis() async {
    if (_isTrendAnalysisRunning) return;

    setState(() {
      _isTrendAnalysisRunning = true;
    });
    final analysisNotifier = ref.read(analysisResultsProvider.notifier);
    analysisNotifier.state = 'Starting trend analysis... Preparing data.';
    _showSnackBar('Starting trend analysis...');

    try {
      // 1. Get Services and Settings
      final settingsService = SettingsService();
      final trendAnalysisService = ref.read(trendAnalysisServiceProvider);
      final recordsPath = await settingsService.getMedicalRecordsPath();

      if (recordsPath == null || recordsPath.isEmpty) {
        analysisNotifier.state =
            'Error: Medical records path not set in Settings.';
        _showSnackBar('Error: Medical records path not set.', isError: true);
        return; // Exit early
      }

      final recordsDir = Directory(recordsPath);
      if (!await recordsDir.exists()) {
        analysisNotifier.state =
            'Error: Medical records directory not found: $recordsPath';
        _showSnackBar(
          'Error: Medical records directory not found.',
          isError: true,
        );
        return; // Exit early
      }

      // 2. Find and Read .medoki.md files
      analysisNotifier.state = 'Scanning for analysis files...';
      final List<Map<String, dynamic>> allData = [];
      final List<String> errors = [];

      await for (final entity in recordsDir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File && entity.path.endsWith('.medoki.md')) {
          try {
            final content = await entity.readAsString();
            final jsonData = jsonDecode(content) as Map<String, dynamic>;
            // Basic validation
            if (jsonData.containsKey('summary') &&
                jsonData.containsKey('lab_results') &&
                jsonData.containsKey('testDateUTC')) {
              allData.add({
                'filePath': entity.path, // Keep track of origin for context
                'summary': jsonData['summary'],
                'testDateUTC': jsonData['testDateUTC'],
                'lab_results': jsonData['lab_results'],
              });
            } else {
              errors.add(
                'Skipping ${p.basename(entity.path)}: Missing required keys (summary, lab_results, testDateUTC).',
              );
            }
          } catch (e) {
            errors.add(
              'Error reading or parsing ${p.basename(entity.path)}: $e',
            );
          }
        }
      }

      if (allData.isEmpty) {
        analysisNotifier.state =
            'No valid .medoki.md files found for analysis.';
        _showSnackBar(
          'No analysis data found. Process files first.',
          isError: true,
        );
        return; // Exit early
      }

      // Sort data by date (ascending) - handle null dates (place them first?)
      allData.sort((a, b) {
        final dateA =
            a['testDateUTC'] != null
                ? DateTime.tryParse(a['testDateUTC'])
                : null;
        final dateB =
            b['testDateUTC'] != null
                ? DateTime.tryParse(b['testDateUTC'])
                : null;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return -1; // Nulls first
        if (dateB == null) return 1;
        return dateA.compareTo(dateB);
      });

      // 3. Consolidate Data for Prompt
      analysisNotifier.state =
          'Consolidating data from ${allData.length} records...';
      final buffer = StringBuffer();
      for (final data in allData) {
        buffer.writeln('---');
        buffer.writeln('File: ${p.basename(data['filePath'])}');
        buffer.writeln('Date: ${data['testDateUTC'] ?? 'Unknown'}');
        buffer.writeln('Summary: ${data['summary']}');
        if (data['lab_results'] is List &&
            (data['lab_results'] as List).isNotEmpty) {
          buffer.writeln('Lab Results:');
          for (final lab in data['lab_results']) {
            if (lab is Map) {
              buffer.writeln(
                '  - ${lab['test_name']}: ${lab['value']} ${lab['units']} (${lab['reference_range']})',
              );
            }
          }
        }
        buffer.writeln();
      }
      final consolidatedData = buffer.toString();

      // 4. Define the Analysis Prompt
      final analysisPrompt = '''
Analyze the following consolidated medical record data, which includes summaries and lab results sorted chronologically. Identify any significant trends, patterns, or potential areas of concern over time based *only* on the provided data. Focus on changes in lab values relative to their reference ranges and any recurring themes in the summaries. Provide a concise, bulleted list of observations. Do not provide medical advice.
''';

      // 5. Call the Trend Analysis Service
      analysisNotifier.state = 'Sending data to AI for trend analysis...';
      final String? result = await trendAnalysisService.performTrendAnalysis(
        consolidatedData,
        analysisPrompt,
        (step) {
          // Update UI with detailed steps from the service
          if (mounted) {
            analysisNotifier.state = 'AI Analysis Step: $step';
            print('Trend Analysis Progress: $step');
          }
        },
      );

      // 6. Handle Result
      if (result != null && !result.startsWith('Error:')) {
        analysisNotifier.state = result; // Display the AI's analysis
        _showSnackBar('Trend analysis completed successfully.');
        if (kDebugMode) {
          print("--- Trend Analysis Result ---");
          print(result);
          print("--- End Trend Analysis Result ---");
        }
      } else {
        analysisNotifier.state = result ?? 'Error: Trend analysis failed.';
        _showSnackBar(result ?? 'Trend analysis failed.', isError: true);
      }

      // Report any file reading errors
      if (errors.isNotEmpty) {
        print("--- File Reading/Parsing Errors ---");
        errors.forEach(print);
        print("--- End File Reading/Parsing Errors ---");
        // Optionally show a summary of these errors in the UI too
        _showSnackBar(
          'Completed with ${errors.length} file reading errors (see console).',
          durationSeconds: 5,
        );
      }
    } catch (e, stacktrace) {
      print("Error during Trend Analysis setup or execution: $e\n$stacktrace");
      analysisNotifier.state =
          'Error: An unexpected error occurred during trend analysis: $e';
      _showSnackBar('An unexpected error occurred: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isTrendAnalysisRunning = false;
        });
      }
    }
  }

  // Helper for showing SnackBars
  void _showSnackBar(
    String message, {
    bool isError = false,
    int durationSeconds = 3,
  }) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.redAccent : null,
          duration: Duration(seconds: durationSeconds),
        ),
      );
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
