import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:io'; // Import dart:io for Directory/File operations
import 'package:path/path.dart' as p; // Import path package

import '../providers/selected_file_provider.dart';
import '../providers/settings_provider.dart'; // Import settings provider
import '../services/ai_service.dart'; // Import AI Service
import '../services/file_service.dart';
import 'medical_records_page.dart'; // Import providers for filtering (Renamed file)
import '../providers/file_extraction_provider.dart'; // Import the new provider
import 'recommendations_confirmation_dialog.dart';
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
  bool _isAnalysisRunning = false; // State to track analysis progress

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
      return Row(
        mainAxisAlignment: MainAxisAlignment.start, // Align button to the left
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            // Restore original placeholder behavior for Start Analysis button
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement actual analysis logic based on existing .medoki.md files or other criteria
                print('Start Analysis button pressed - Placeholder');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Analysis of existing data not yet implemented.',
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.science_outlined), // Keep icon
              label: const Text('Start Analysis...'), // Keep label
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Recommendations Button - No longer needs to be disabled by _isAnalysisRunning here
          ElevatedButton.icon(
            onPressed: () async {
              final bool? confirmed = await showDialog<bool>(
                context: context,
                builder: (BuildContext context) {
                  return const RecommendationsConfirmationDialog();
                },
              );

              if (confirmed == true) {
                // User confirmed
                print('Recommendations confirmed by user.');
                // Show success indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Recommendations request confirmed.'),
                      ],
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );
                // TODO: Implement actual recommendations logic here
              } else {
                // User cancelled or dialog dismissed
                print('Recommendations cancelled.');
              }
            },
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('Recommendations'),
            // Optional: Style differently if needed
            // style: ElevatedButton.styleFrom(
            //   backgroundColor: Theme.of(context).colorScheme.secondary,
            //   foregroundColor: Theme.of(context).colorScheme.onSecondary,
            // ),
          ),
          // Add other analysis-specific toolbar items here if needed in the future
        ],
      );
    } else {
      // Content for the Medical Records tab toolbar
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
                      final fileService = FileService(
                        ref,
                      ); // Instantiate service
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
                // Rescan Button Removed - Functionality exists in FAB on MedicalRecordsPage
                const SizedBox(width: 16), // Keep spacing before filters
                // Filter Chips
                Expanded(
                  child: _buildFilterChips(ref),
                ), // Wrap chips in Expanded
                const SizedBox(
                  width: 8,
                ), // Reduced spacing before search icon/field
                // AnimatedSwitcher for Search Icon/Field
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (
                    Widget child,
                    Animation<double> animation,
                  ) {
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
                                    ref
                                            .read(searchQueryProvider.notifier)
                                            .state =
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
                /* IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: () {
                  },
                ), */
                /* IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: () {
                    // Placeholder action for filter
                  },
                ), */
              ],
            ),
          ),
          // Add back the divider and a SizedBox to constrain the Expanded section above
          const VerticalDivider(
            width: 1,
            thickness: 1,
            indent: 8,
            endIndent: 8,
          ),
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

  // Helper to build filter chips
  Widget _buildFilterChips(WidgetRef ref) {
    final availableYears = ref.watch(yearFoldersProvider);
    final selectedYear = ref.watch(yearFilterProvider);
    final yearNotifier = ref.read(yearFilterProvider.notifier);

    return availableYears.when(
      data: (years) {
        if (years.isEmpty) {
          return const SizedBox.shrink(); // No folders, show nothing
        }
        // Sort years in descending order (newest first)
        // Create a mutable copy before sorting
        final sortedYears = List<String>.from(years);
        sortedYears.sort(
          (a, b) => b.compareTo(a),
        ); // Simple string sort works for YYYY format

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
                    yearNotifier.state = null; // Set filter to null for 'All'
                  },
                  showCheckmark: false, // Cleaner look without checkmark
                  visualDensity: VisualDensity.compact, // Make chips smaller
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                ),
              ),
              // Year Chips (use sortedYears)
              ...sortedYears.map(
                (year) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: FilterChip(
                    label: Text(year),
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
            // Show a small indicator while loading folders
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      error:
          (err, stack) => const Tooltip(
            // Show error icon on failure
            message: 'Error loading year filters',
            child: Icon(Icons.error_outline, color: Colors.red, size: 18),
          ),
    );
  }

  // Method to handle the batch analysis process
  Future<void> _startBatchAnalysis() async {
    // 1. Check if already running
    if (_isAnalysisRunning) return;

    // 2. Get settings and base path
    final settingsState = ref.read(settingsProvider);
    final basePath = settingsState.medicalRecordsPath;

    if (basePath == null || basePath.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Medical records path not set. Please configure it in Settings.',
            ),
          ),
        );
      }
      return;
    }

    final baseDir = Directory(basePath);
    if (!await baseDir.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Medical records directory not found: $basePath'),
          ),
        );
      }
      return;
    }

    // 3. Set state to running and show initial feedback
    setState(() {
      _isAnalysisRunning = true;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Starting analysis of medical records...'),
          duration: Duration(seconds: 2),
        ),
      );
      // Update the analysis results provider immediately
      ref.read(analysisResultsProvider.notifier).state =
          'Analysis in progress...';
    }

    // 4. Prepare AI Service and File List
    final aiService = AIService();
    final List<FileSystemEntity> allFiles =
        await baseDir.list(recursive: true).toList();
    final List<File> filesToProcess = [];
    final Set<String> existingMedokiFiles = {};

    // Helper to check supported extensions
    bool isSupported(String path) {
      final ext = p.extension(path).toLowerCase();
      return [
        '.pdf',
        '.png',
        '.jpg',
        '.jpeg',
        '.webp',
        '.heic',
        '.heif',
      ].contains(ext);
    }

    // Find existing .medoki.md files and files to process
    for (final entity in allFiles) {
      if (entity is File) {
        if (entity.path.endsWith('.medoki.md')) {
          // Store the base name without the .medoki.md extension
          existingMedokiFiles.add(entity.path.replaceAll('.medoki.md', ''));
        } else if (isSupported(entity.path)) {
          // Add supported files initially
          filesToProcess.add(entity);
        }
      }
    }

    // Filter out files that already have a .medoki.md file
    filesToProcess.removeWhere(
      (file) => existingMedokiFiles.contains(file.path),
    );

    if (filesToProcess.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No new medical records found to analyse.'),
          ),
        );
      }
      setState(() {
        _isAnalysisRunning = false;
      });
      // Update analysis results provider if needed
      ref.read(analysisResultsProvider.notifier).state =
          'No new files to analyse.';
      return;
    }

    // 5. Process Files
    int successCount = 0;
    int errorCount = 0;
    List<String> errorMessages = [];
    final totalFiles = filesToProcess.length;

    for (int i = 0; i < totalFiles; i++) {
      final file = filesToProcess[i];
      if (!mounted) break; // Stop if widget is disposed

      // Update progress in the analysis tab
      ref.read(analysisResultsProvider.notifier).state =
          'Analysing file ${i + 1} of $totalFiles: ${p.basename(file.path)}...';

      try {
        print("Processing: ${file.path}");
        final result = await aiService.extractDataFromFile(file.path);
        if (result != null && !result.startsWith("Error:")) {
          successCount++;
          print("Success: ${file.path} - Summary: $result");
        } else {
          errorCount++;
          final errorMessage = result ?? "Unknown error";
          errorMessages.add('${p.basename(file.path)}: $errorMessage');
          print("Error processing ${file.path}: $errorMessage");
        }
      } catch (e) {
        errorCount++;
        errorMessages.add('${p.basename(file.path)}: $e');
        print("Exception processing ${file.path}: $e");
      }

      // Optional: Add a small delay between API calls if needed
      // await Future.delayed(Duration(milliseconds: 500));
    }

    // 6. Final Feedback and State Update
    if (mounted) {
      String completionMessage;
      if (errorCount == 0) {
        completionMessage =
            'Analysis complete. Processed $successCount file(s).';
      } else {
        completionMessage =
            'Analysis finished. $successCount succeeded, $errorCount failed.';
        // Optionally show detailed errors in a dialog or log
        print("Analysis Errors:\n${errorMessages.join('\n')}");
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(completionMessage)));

      // Update the analysis results provider with the final status
      ref.read(analysisResultsProvider.notifier).state = completionMessage;

      setState(() {
        _isAnalysisRunning = false;
      });

      // TODO: Consider refreshing the file list view if analysis adds/changes files shown there
      // ref.invalidate(medicalRecordsProvider); // Example invalidation
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
