import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert'; // For JSON decoding
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart'; // For kDebugMode

import '../providers/selected_file_provider.dart';
import '../providers/settings_provider.dart';
// import '../services/ai_service.dart'; // No longer directly needed here
import '../services/file_service.dart';
import '../services/batch_analysis_service.dart';
import '../services/settings_service.dart'; // Needed to get records path and for refresh button
import '../services/trend_analysis_service.dart'; // Import the new service
import 'medical_records_page.dart'; // For medicalRecordsProvider, yearFilterProvider
import '../providers/file_extraction_provider.dart';
// import 'package:path/path.dart' as p; // Import path package for joining paths - Already imported on line 6
import 'recommendations_confirmation_dialog.dart'; // Keep for batch analysis button
import 'package:path_provider/path_provider.dart'; // Import for saving summary
import '../widgets/analysis_tab_page.dart'; // Import analysisSummaryProvider for refresh
import '../providers/analysis_providers.dart'; // Import the shared status and refresh providers
import '../services/html_report_generator.dart'; // Import the new HTML generator service

// final analysisStatusProvider = StateProvider<String>((ref) => 'Ready'); // MOVED to analysis_providers.dart

// --- Main AppToolbar Widget ---

class AppToolbar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  final int currentIndex;
  final int analysisTabIndex;
  final VoidCallback
  onAddRecord; // Kept for now, though FileService handles picking

  const AppToolbar({
    super.key,
    required this.currentIndex,
    required this.analysisTabIndex,
    required this.onAddRecord,
  });

  @override
  ConsumerState<AppToolbar> createState() => _AppToolbarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _AppToolbarState extends ConsumerState<AppToolbar> {
  // State remains here as it's shared or controls actions
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  bool _isTrendAnalysisRunning = false;
  bool _isBatchAnalysisRunning = false; // For the other analysis type if needed

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Debounce search input
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        ref.read(searchQueryProvider.notifier).state = _searchController.text;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedFileState = ref.watch(selectedFileProvider);

    return Container(
      height: kToolbarHeight,
      color: Theme.of(context).colorScheme.surface,
      child:
          widget.currentIndex == widget.analysisTabIndex
              ? _AnalysisToolbarContent(
                isTrendAnalysisRunning: _isTrendAnalysisRunning,
                onStartTrendAnalysis: _startTrendAnalysis,
              )
              : _MedicalRecordsToolbarContent(
                selectedFileState: selectedFileState,
                searchController: _searchController,
                searchFocusNode: _searchFocusNode,
                onAddRecord:
                    widget.onAddRecord, // Pass down if needed by Add button
              ),
    );
  }

  // --- Action Methods (Remain in the main state) ---

  // Method to handle the BATCH analysis process (generating .medoki.md files)
  // This might be moved if a dedicated button is added elsewhere
  Future<void> _startBatchAnalysis() async {
    if (_isBatchAnalysisRunning) return;

    final bool? shouldProceed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return const RecommendationsConfirmationDialog();
      },
    );

    if (shouldProceed != true) {
      _showSnackBar('Analysis cancelled.');
      return;
    }

    setState(() {
      _isBatchAnalysisRunning = true;
    });
    final statusNotifier = ref.read(analysisStatusProvider.notifier);
    statusNotifier.state = 'Batch analysis starting... Please wait.';
    _showSnackBar('Starting analysis of medical records...');

    final batchService = ref.read(batchAnalysisServiceProvider);
    int totalFiles = 0;
    int processedCount = 0;
    final List<String> errorMessages = [];

    try {
      await batchService.runBatchAnalysis(
        onProgress: (message) {
          print("Batch Progress: $message");
          if (mounted) {
            statusNotifier.state = message;
          }
        },
        onError: (error) {
          print("Batch Error: $error");
          errorMessages.add(error);
        },
        onFileProcessed: (processed, total) {
          processedCount = processed;
          totalFiles = total;
        },
      );

      if (mounted) {
        String finalMessage;
        if (errorMessages.isEmpty) {
          finalMessage =
              'Batch analysis completed successfully. Processed $processedCount files.';
        } else {
          finalMessage =
              'Batch analysis completed with ${errorMessages.length} errors out of $totalFiles files processed.';
          print('Errors encountered:\n${errorMessages.join('\n')}');
        }
        _showSnackBar(finalMessage, durationSeconds: 5);
        statusNotifier.state = finalMessage;
      }
    } catch (e) {
      print("Unexpected error during batch analysis service execution: $e");
      if (mounted) {
        final errorMessage =
            'An unexpected error occurred during batch analysis: $e';
        _showSnackBar(errorMessage, isError: true, durationSeconds: 5);
        statusNotifier.state = errorMessage;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBatchAnalysisRunning = false;
        });
      }
    }
  }

  // Method for Trend Analysis
  Future<void> _startTrendAnalysis() async {
    if (_isTrendAnalysisRunning) return;

    setState(() {
      _isTrendAnalysisRunning = true;
    });
    final statusNotifier = ref.read(analysisStatusProvider.notifier);
    statusNotifier.state = 'Starting trend analysis... Preparing data.';
    _showSnackBar('Starting trend analysis...');

    try {
      final settingsService = SettingsService();
      final trendAnalysisService = ref.read(trendAnalysisServiceProvider);
      final recordsPath = await settingsService.getMedicalRecordsPath();

      if (recordsPath == null || recordsPath.isEmpty) {
        statusNotifier.state =
            'Error: Medical records path not set in Settings.';
        _showSnackBar('Error: Medical records path not set.', isError: true);
        return;
      }

      final recordsDir = Directory(recordsPath);
      if (!await recordsDir.exists()) {
        statusNotifier.state =
            'Error: Medical records directory not found: $recordsPath';
        _showSnackBar(
          'Error: Medical records directory not found.',
          isError: true,
        );
        return;
      }

      statusNotifier.state = 'Scanning for analysis files...';
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
            if (jsonData.containsKey('summary') &&
                jsonData.containsKey('lab_results') &&
                jsonData.containsKey('testDateUTC')) {
              allData.add({
                'filePath': entity.path,
                'summary': jsonData['summary'],
                'testDateUTC': jsonData['testDateUTC'],
                'lab_results': jsonData['lab_results'],
              });
            } else {
              errors.add(
                'Skipping ${p.basename(entity.path)}: Missing required keys.',
              );
            }
          } catch (e) {
            errors.add('Error reading/parsing ${p.basename(entity.path)}: $e');
          }
        }
      }

      if (allData.isEmpty) {
        statusNotifier.state = 'No valid .medoki.md files found for analysis.';
        _showSnackBar(
          'No analysis data found. Process files first.',
          isError: true,
        );
        return;
      }

      // Sort data by date
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
        if (dateA == null) return -1;
        if (dateB == null) return 1;
        return dateA.compareTo(dateB);
      });

      statusNotifier.state =
          'Consolidating data from ${allData.length} records...';
      final buffer = StringBuffer();
      String latestRecordDataString = ''; // To store the latest record's data

      for (int i = 0; i < allData.length; i++) {
        final data = allData[i];
        final fileName = p.basename(data['filePath']);
        if (i == 0) {
          // Update status only for the first file during consolidation
          statusNotifier.state = 'Consolidating data starting with: $fileName';
        }

        final recordBuffer = StringBuffer(); // Buffer for individual record
        recordBuffer.writeln('---');
        recordBuffer.writeln('File: $fileName');
        recordBuffer.writeln('Date: ${data['testDateUTC'] ?? 'Unknown'}');
        recordBuffer.writeln('Summary: ${data['summary']}');
        if (data['lab_results'] is List &&
            (data['lab_results'] as List).isNotEmpty) {
          recordBuffer.writeln('Lab Results:');
          for (final lab in data['lab_results']) {
            if (lab is Map) {
              recordBuffer.writeln(
                '  - ${lab['test_name']}: ${lab['value']} ${lab['units']} (${lab['reference_range']})',
              );
            }
          }
        }
        recordBuffer.writeln();

        final currentRecordString = recordBuffer.toString();
        buffer.write(currentRecordString); // Append to the main buffer

        // Store the latest record (last one after sorting)
        if (i == allData.length - 1) {
          latestRecordDataString = currentRecordString;
        }
      }
      final consolidatedData = buffer.toString(); // All data consolidated

      // --- Step 1: Analyze Current Situation ---
      statusNotifier.state = 'Analyzing current health situation...';
      print("Step 1: Generating prompt for Current Situation");
      final currentSituationPrompt =
          HtmlReportGenerator.generateCurrentSituationPrompt(
            latestRecordDataString,
          );

      print("Step 1: Sending request to AI for Current Situation");
      final String?
      currentSituationResult = await trendAnalysisService.performTrendAnalysis(
        latestRecordDataString, // Pass only latest data for context if needed by service
        currentSituationPrompt, // Pass the specific prompt
        (step) {
          if (mounted) {
            statusNotifier.state = 'AI Analysis (Current Situation): $step';
          }
          print('Trend Analysis Progress (Current Situation): $step');
        },
      );

      if (currentSituationResult == null ||
          currentSituationResult.startsWith('Error:')) {
        statusNotifier.state =
            currentSituationResult ??
            'Error: Failed to analyze current situation.';
        _showSnackBar(
          currentSituationResult ?? 'Failed to analyze current situation.',
          isError: true,
        );
        // Optionally return or handle error differently
        return; // Stop further processing if the first step fails
      }
      print("Step 1: Received result for Current Situation");

      // --- Step 2: Analyze Trends ---
      statusNotifier.state = 'Analyzing historical trends...';
      print("Step 2: Generating prompt for Trends");
      final trendsPrompt = HtmlReportGenerator.generateTrendsPrompt(
        consolidatedData, // Use all data for trends
      );

      print("Step 2: Sending request to AI for Trends");
      final String? trendsResult = await trendAnalysisService
          .performTrendAnalysis(
            consolidatedData, // Pass all data for context if needed by service
            trendsPrompt, // Pass the specific prompt
            (step) {
              if (mounted) {
                statusNotifier.state = 'AI Analysis (Trends): $step';
              }
              print('Trend Analysis Progress (Trends): $step');
            },
          );

      if (trendsResult == null || trendsResult.startsWith('Error:')) {
        statusNotifier.state =
            trendsResult ?? 'Error: Failed to analyze trends.';
        _showSnackBar(
          trendsResult ?? 'Failed to analyze trends.',
          isError: true,
        );
        // Optionally save the partial result or handle error
        return; // Stop further processing if the second step fails
      }
      print("Step 2: Received result for Trends");

      // --- Step 3: Combine and Save Report ---
      statusNotifier.state = 'Generating final report...';
      print("Step 3: Combining results into final HTML");
      final String finalHtmlContent =
          HtmlReportGenerator.generateFullHtmlReport(
            currentSituationResult, // Result from step 1
            trendsResult, // Result from step 2
          );

      final String outputFileName = 'analysis.medoki.analysis.html';
      String? savedFilePath;

      try {
        // We already got recordsPath earlier, reuse it
        if (recordsPath != null && recordsPath.isNotEmpty) {
          final filePath = p.join(recordsPath, outputFileName);
          final outputFile = File(filePath);
          await outputFile.writeAsString(finalHtmlContent);
          savedFilePath = filePath; // Store the path if save succeeds
          print('Analysis HTML saved to: $filePath');
          statusNotifier.state =
              'Analysis complete. Report saved.'; // Update status
          _showSnackBar('Trend analysis completed successfully.');
        } else {
          // This case should have been caught earlier, but handle defensively
          throw Exception('Medical records path is not available.');
        }
      } catch (e) {
        print('Error saving analysis HTML: $e');
        statusNotifier.state = 'Error saving analysis report: $e';
        _showSnackBar('Error saving analysis report.', isError: true);
        // Don't update the HTML path provider if saving failed
      }

      // Update the provider with the path ONLY if saving was successful
      ref.read(analysisHtmlPathProvider.notifier).state = savedFilePath;

      if (kDebugMode && savedFilePath != null) {
        // Optionally log only parts if the full HTML is too long
        print(
          "--- Trend Analysis Combined Report Saved ---\nPath: $savedFilePath\n--- End Report ---",
        );
      }

      // Handle file reading/parsing errors collected earlier
      if (errors.isNotEmpty) {
        print(
          "--- File Reading/Parsing Errors ---\n${errors.join('\n')}\n--- End File Reading/Parsing Errors ---",
        );
        _showSnackBar(
          'Completed with ${errors.length} file reading errors (see console).',
          durationSeconds: 5,
        );
      }
    } catch (e, stacktrace) {
      print("Error during Trend Analysis setup or execution: $e\n$stacktrace");
      statusNotifier.state =
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
}

// --- Extracted Private Widgets ---

// --- Analysis Tab Content ---
class _AnalysisToolbarContent extends ConsumerWidget {
  // Changed to ConsumerWidget
  final bool isTrendAnalysisRunning;
  final VoidCallback onStartTrendAnalysis;

  const _AnalysisToolbarContent({
    required this.isTrendAnalysisRunning,
    required this.onStartTrendAnalysis,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Added WidgetRef ref
    // No longer need to watch analysisHtmlPath here for enabling/disabling

    return Row(
      // mainAxisAlignment: MainAxisAlignment.start, // Removed to allow Spacer
      children: [
        // Start Trend Analysis Button
        Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: ElevatedButton.icon(
            onPressed: isTrendAnalysisRunning ? null : onStartTrendAnalysis,
            icon:
                isTrendAnalysisRunning
                    ? Container(
                      width: 24,
                      height: 24,
                      padding: const EdgeInsets.all(2.0),
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                    : const Icon(Icons.science_outlined),
            label: Text(
              isTrendAnalysisRunning ? 'Analyzing...' : 'Start Trend Analysis',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
        const Spacer(), // Pushes the refresh button to the right
        // Refresh Button
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload Analysis Report from Disk',
            onPressed: () async {
              // Make onPressed async
              final settingsService = SettingsService();
              final recordsPath = await settingsService.getMedicalRecordsPath();
              final statusNotifier = ref.read(
                analysisStatusProvider.notifier,
              ); // For potential errors
              final htmlPathNotifier = ref.read(
                analysisHtmlPathProvider.notifier,
              );
              final refreshNotifier = ref.read(
                analysisRefreshTriggerProvider.notifier,
              );

              if (recordsPath == null || recordsPath.isEmpty) {
                statusNotifier.state =
                    'Error: Medical records path not set in Settings.';
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Error: Medical records path not set in Settings.',
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
                return; // Stop if path isn't set
              }

              final expectedFilePath = p.join(
                recordsPath,
                'analysis.medoki.analysis.html',
              );

              // Update the path provider *before* triggering refresh
              htmlPathNotifier.state = expectedFilePath;

              // Increment the trigger provider to signal a refresh in the AnalysisTabPage
              refreshNotifier.state++;

              print('Refresh requested. Attempting to load: $expectedFilePath');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Attempting to reload analysis report...'),
                  ),
                );
              }
            }, // Button is always enabled
          ),
        ),
      ],
    );
  }
}

// --- Medical Records Tab Content ---
class _MedicalRecordsToolbarContent extends ConsumerWidget {
  final SelectedFileState selectedFileState;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback onAddRecord; // Keep if Add button needs it

  const _MedicalRecordsToolbarContent({
    required this.selectedFileState,
    required this.searchController,
    required this.searchFocusNode,
    required this.onAddRecord,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        // Left side: Controls (Add button, Filters, Search)
        Expanded(
          child: Row(
            children: [
              // Add Button
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final fileService = FileService(ref);
                    final resultMessage = await fileService.pickAndAddFiles(
                      context,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(resultMessage)));
                    }
                    // onAddRecord(); // Call if still needed
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Medical Records...'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Filter Chips
              const Expanded(
                child: _FilterChipsWidget(),
              ), // Use extracted widget
              const SizedBox(width: 8),
              // Search Item
              _SearchToolbarItem(
                // Use extracted widget
                searchController: searchController,
                searchFocusNode: searchFocusNode,
              ),
            ],
          ),
        ),
        // Divider
        const VerticalDivider(width: 1, thickness: 1, indent: 8, endIndent: 8),
        // Right side: Dynamic Header
        Container(
          width: 350, // Match sidebar width
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          alignment: Alignment.center,
          child: _DynamicSidebarHeader(
            selectedFileState: selectedFileState,
          ), // Use extracted widget
        ),
      ],
    );
  }
}

// --- Filter Chips Widget ---
class _FilterChipsWidget extends ConsumerWidget {
  const _FilterChipsWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsyncValue = ref.watch(medicalRecordsProvider);
    final selectedYear = ref.watch(yearFilterProvider);
    final yearNotifier = ref.read(yearFilterProvider.notifier);

    return recordsAsyncValue.when(
      data: (data) {
        final availableYears = data.availableYears;
        if (availableYears.isEmpty) {
          return const SizedBox.shrink();
        }

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
                      yearNotifier.state = null;
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
              // Year Chips
              ...availableYears.map(
                (year) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: FilterChip(
                    label: Text(year.toString()),
                    selected: selectedYear == year,
                    onSelected: (selected) {
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
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      error:
          (err, stack) => Tooltip(
            message: 'Error loading year filters: $err',
            child: const Icon(Icons.error_outline, color: Colors.red, size: 18),
          ),
    );
  }
}

// --- Search Toolbar Item Widget ---
class _SearchToolbarItem extends ConsumerStatefulWidget {
  final TextEditingController searchController;
  final FocusNode searchFocusNode;

  const _SearchToolbarItem({
    required this.searchController,
    required this.searchFocusNode,
  });

  @override
  ConsumerState<_SearchToolbarItem> createState() => _SearchToolbarItemState();
}

class _SearchToolbarItemState extends ConsumerState<_SearchToolbarItem> {
  bool _isSearchExpanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return ScaleTransition(scale: animation, child: child);
      },
      child:
          _isSearchExpanded
              ? Container(
                key: const ValueKey('searchField'),
                width: 250,
                child: TextField(
                  controller: widget.searchController,
                  focusNode: widget.searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Search files...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
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
                        widget.searchController.clear();
                        setState(() {
                          _isSearchExpanded = false;
                        });
                        widget.searchFocusNode.unfocus();
                        ref.read(searchQueryProvider.notifier).state = '';
                      },
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              )
              : IconButton(
                key: const ValueKey('searchIcon'),
                icon: const Icon(Icons.search),
                tooltip: 'Search Files',
                onPressed: () {
                  setState(() {
                    _isSearchExpanded = true;
                  });
                  widget.searchFocusNode.requestFocus();
                },
              ),
    );
  }
}

// --- Dynamic Sidebar Header Widget ---
class _DynamicSidebarHeader extends ConsumerWidget {
  final SelectedFileState selectedFileState;

  const _DynamicSidebarHeader({required this.selectedFileState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFilePath = selectedFileState.path;

    if (selectedFilePath == null) {
      // Default "Details" title
      return const Center(
        child: Text(
          'Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );
    } else {
      // Header when a file is selected
      final extractionState = ref.watch(
        fileExtractionProvider(selectedFilePath),
      );
      final bool isExtracting = extractionState.isLoading;

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
          // Title
          const Expanded(
            child: Text(
              'File Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed:
                isExtracting
                    ? null
                    : () =>
                        ref
                            .read(
                              fileExtractionProvider(selectedFilePath).notifier,
                            )
                            .extractData(),
            tooltip: 'Rescan file with AI',
            iconSize: 20.0,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color:
                isExtracting
                    ? Colors.grey
                    : Theme.of(context).colorScheme.primary,
          ),
        ],
      );
    }
  }
}
