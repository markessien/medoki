import 'dart:io';
import 'dart:math'; // Import for min/max
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for keyboard events
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:mediciapp/providers/selected_file_provider.dart'; // Use package import
import 'package:mediciapp/providers/settings_provider.dart'; // Use package import
import 'package:mediciapp/services/file_service.dart'; // Use package import, Import the file service
import 'package:intl/intl.dart'; // Import date formatting package
import 'dart:convert'; // For jsonDecode
import 'package:mediciapp/widgets/summary_sidebar.dart'; // Use package import, Re-use the summary sidebar
import 'package:mediciapp/providers/file_processing_provider.dart'; // Import the processing status provider
import 'package:mediciapp/providers/newly_added_files_provider.dart'; // Import the newly added files provider

// --- Providers for File Listing and Filtering ---

// Define a type for the file list item data, including medoki status, diagnosis date, and processing status
typedef FileListItem =
    ({
      File file,
      DateTime modified,
      bool hasMedoki,
      DateTime? diagnosisDate, // Added diagnosis date
      ProcessingStatus status, // Added processing status
      bool isNew, // Flag for newly added files
    });

// Provider to hold the currently selected year filter (null means 'All')
final yearFilterProvider = StateProvider<int?>(
  (ref) => null,
); // Changed to int?

// Provider to hold the current search query
final searchQueryProvider = StateProvider<String>((ref) => '');

// Provider to hold the set of multi-selected file paths
final multiSelectedFilesProvider = StateProvider<Set<String>>((ref) => {});

// yearFoldersProvider removed - years are now derived from data

// Define a type for the provider result, including items and available years
typedef MedicalRecordsResult =
    ({List<FileListItem> items, List<int> availableYears});

// Provider to fetch records, extract diagnosis dates, determine available years, and get processing status
final medicalRecordsProvider = FutureProvider<MedicalRecordsResult>((
  ref,
) async {
  final settings = ref.watch(settingsProvider);
  final basePath = settings.medicalRecordsPath;
  final selectedYearFilter = ref.watch(yearFilterProvider); // Now int?
  final searchQuery = ref.watch(searchQueryProvider).toLowerCase();

  if (basePath == null || basePath.isEmpty) {
    // Return empty result if base path is invalid
    return (items: <FileListItem>[], availableYears: <int>[]);
  }

  final directory = Directory(basePath);
  if (!await directory.exists()) {
    // Return empty result if directory doesn't exist
    return (items: <FileListItem>[], availableYears: <int>[]);
  }

  // --- Step 1: Get ALL files recursively (excluding trash and .medoki.md) ---
  final List<File> allFiles = [];
  final trashPath = p.join(basePath, 'trash');
  final stream = directory.list(recursive: true, followLinks: false);
  await for (final entity in stream) {
    // Check if the entity is within the trash directory
    if (entity.path.startsWith(trashPath)) {
      continue; // Skip files/dirs inside trash
    }
    if (entity is File) {
      // Exclude .medoki.md files directly
      if (!entity.path.toLowerCase().endsWith('.medoki.md')) {
        allFiles.add(entity);
      }
    }
  }
  // filesToProcess is now allFiles, year filtering happens later
  final List<File> filesToProcess = allFiles;

  // --- Step 2: Filter by Search Query (Filename and .medoki.md content) ---
  List<File> searchedFiles = [];
  if (searchQuery.isEmpty) {
    searchedFiles = filesToProcess; // No search query, use year-filtered list
  } else {
    // Use Future.wait for potentially parallel file reads
    List<File?> results = await Future.wait(
      filesToProcess.map((file) async {
        final fileNameLower = p.basename(file.path).toLowerCase();
        // Check filename first
        if (fileNameLower.contains(searchQuery)) {
          return file; // Return file if filename matches
        }

        // If filename doesn't match, check .medoki.md content
        final medokiFile = File('${file.path}.medoki.md');
        if (await medokiFile.exists()) {
          try {
            final content = await medokiFile.readAsString();
            if (content.toLowerCase().contains(searchQuery)) {
              return file; // Return file if content matches
            }
          } catch (e) {
            // TODO: Implement proper logging
          }
        }
        return null; // Return null if no match
      }),
    );
    // Filter out nulls (files that didn't match)
    searchedFiles = results.whereType<File>().toList();
  }

  // --- Step 3: Get modification dates, check medoki status, extract diagnosis date ---
  final List<FileListItem> allFileItems = [];
  final Set<int> availableYearsSet = {}; // Use a Set to store unique years
  final statusMap = ref.watch(
    fileProcessingStatusMapProvider,
  ); // Watch the status map
  final newlyAddedPaths = ref.watch(
    newlyAddedFilesProvider,
  ); // Watch the newly added files set
  for (final file in searchedFiles) {
    try {
      final modifiedDate = await file.lastModified();
      final medokiPath = '${file.path}.medoki.md';
      final medokiFile = File(medokiPath);
      final hasMedoki = await medokiFile.exists();
      DateTime? diagnosisDate;

      if (hasMedoki) {
        try {
          final content = await medokiFile.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;
          final dateString =
              data['testDateUTC'] is String
                  ? data['testDateUTC'] as String
                  : null;
          if (dateString != null && dateString.isNotEmpty) {
            diagnosisDate = DateTime.tryParse(dateString)?.toLocal();
            if (diagnosisDate != null) {
              availableYearsSet.add(diagnosisDate.year); // Add year to the set
            }
          }
        } catch (e) {
          print("Error reading/parsing medoki file $medokiPath: $e");
        }
      }

      // Get the processing status for the current file
      // Get the status record from the map, or null if not present
      final statusRecord = statusMap[file.path];
      // Extract the status enum, defaulting to none if the record is null
      final status = statusRecord?.status ?? ProcessingStatus.none;

      allFileItems.add((
        file: file,
        modified: modifiedDate,
        hasMedoki: hasMedoki,
        diagnosisDate: diagnosisDate,
        status: status, // Include the status
        isNew: newlyAddedPaths.contains(file.path), // Check if file is new
      ));
    } catch (e) {
      print("Error processing file ${file.path}: $e");
    }
  }

  // --- Step 4: Filter by Selected Year (if any) ---
  final List<FileListItem> filteredItems;
  final selectedYear = ref.watch(
    yearFilterProvider,
  ); // Read the selected year (int?)
  if (selectedYear == null) {
    filteredItems = allFileItems; // No year filter, show all
  } else {
    filteredItems =
        allFileItems.where((item) {
          // Keep item if its diagnosis year matches the filter
          if (item.diagnosisDate?.year == selectedYear) {
            return true;
          }
          // Keep item if it's new and hasn't completed processing yet
          if (item.isNew &&
              (item.status == ProcessingStatus.none ||
                  item.status == ProcessingStatus.pending ||
                  item.status == ProcessingStatus.processing)) {
            return true;
          }
          // Otherwise, exclude it
          return false;
        }).toList();
  }

  // --- Step 5: Sort the filtered list ---
  // --- Step 5: Sort the filtered list (Prioritize Processing/Pending) ---
  filteredItems.sort((a, b) {
    // Priority: Processing > Pending > Others
    if (a.status == ProcessingStatus.processing &&
        b.status != ProcessingStatus.processing)
      return -1;
    if (b.status == ProcessingStatus.processing &&
        a.status != ProcessingStatus.processing)
      return 1;
    if (a.status == ProcessingStatus.pending &&
        b.status != ProcessingStatus.pending)
      return -1;
    if (b.status == ProcessingStatus.pending &&
        a.status != ProcessingStatus.pending)
      return 1;

    // If statuses are the same priority level (or both are completed/failed/none), sort by date/name
    final dateA = a.diagnosisDate;
    final dateB = b.diagnosisDate;

    if (dateA != null && dateB != null) {
      // Both have dates, sort descending by date
      final dateComparison = dateB.compareTo(dateA);
      if (dateComparison != 0) return dateComparison;
      // If dates are the same, sort by filename ascending
      return p.basename(a.file.path).compareTo(p.basename(b.file.path));
    } else if (dateA != null) {
      // Only A has a date, A comes first (among non-processing/pending)
      return -1;
    } else if (dateB != null) {
      // Only B has a date, B comes first (among non-processing/pending)
      return 1;
    } else {
      // Neither has a date, sort by filename ascending
      return p.basename(a.file.path).compareTo(p.basename(b.file.path));
    }
  });

  // --- Step 6: Prepare and return the result ---
  final List<int> availableYears =
      availableYearsSet.toList()
        ..sort((a, b) => b.compareTo(a)); // Sort years descending

  return (items: filteredItems, availableYears: availableYears);
});

// --- End Providers ---

// Removed the separate medokiStatusProvider as status is now part of medicalRecordsProvider result

// Convert to ConsumerStatefulWidget for keyboard state management
class MedicalRecordsPage extends ConsumerStatefulWidget {
  const MedicalRecordsPage({super.key});

  @override
  ConsumerState<MedicalRecordsPage> createState() => _MedicalRecordsPageState();
}

class _MedicalRecordsPageState extends ConsumerState<MedicalRecordsPage> {
  // State variables for keyboard modifiers
  bool _isShiftPressed = false;
  bool _isCtrlPressed = false; // Or Meta on macOS
  int? _shiftAnchorIndex; // For range selection

  // FocusNode to allow the area to receive keyboard events
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // --- Helper Function for Deleting Files --- (Will be moved later)
  Future<void> _deleteFiles(
    BuildContext context,
    WidgetRef ref,
    Set<String> filesToDeletePaths,
  ) async {
    if (filesToDeletePaths.isEmpty) return;

    // 1. Show Confirmation Dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text(
            'Are you sure you want to move ${filesToDeletePaths.length} file(s) to the trash folder?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return; // User cancelled

    // 2. Perform Deletion (Move to Trash)
    final settings = ref.read(settingsProvider);
    final basePath = settings.medicalRecordsPath; // Use renamed property
    if (basePath == null || basePath.isEmpty) {
      if (context.mounted) {
        // Check context before showing SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Base path not set.')),
        );
      }
      return;
    }

    final trashPath = p.join(basePath, 'trash');
    final trashDir = Directory(trashPath);

    try {
      // Create trash directory if it doesn't exist
      if (!await trashDir.exists()) {
        await trashDir.create(recursive: true);
      }

      int successCount = 0;
      List<String> errors = [];

      for (final filePath in filesToDeletePaths) {
        final file = File(filePath);
        final medokiFile = File('$filePath.medoki.md');
        final fileName = p.basename(filePath);
        final destinationPath = p.join(trashPath, fileName);
        final medokiDestinationPath = p.join(trashPath, '$fileName.medoki.md');

        try {
          if (await file.exists()) {
            await file.rename(destinationPath); // Move original file
          }
          if (await medokiFile.exists()) {
            await medokiFile.rename(medokiDestinationPath); // Move .medoki file
          }
          successCount++;
        } catch (e) {
          errors.add('Error moving ${fileName}: $e');
          // TODO: Implement proper logging
        }
      }

      // 3. Show Feedback
      String feedbackMessage;
      if (errors.isEmpty) {
        feedbackMessage = '$successCount file(s) moved to trash.';
      } else {
        feedbackMessage =
            '$successCount file(s) moved. Errors: ${errors.join(', ')}';
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(feedbackMessage)));
      }

      // 4. Clear Selection, Remove Statuses, and Refresh List
      ref.read(multiSelectedFilesProvider.notifier).state = {};
      ref
          .read(selectedFileProvider.notifier)
          .clearSelection(); // Also clear single select
      ref
          .read(fileProcessingStatusProvider.notifier)
          .removeStatuses(filesToDeletePaths); // Remove statuses
      ref.refresh(medicalRecordsProvider); // Refresh the record list
    } catch (e) {
      // TODO: Implement proper logging
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred during deletion: $e')),
        );
      }
    }
  }
  // --- End Helper Function ---

  // Method to show the context menu (similar to YearRecordsGrid)
  void _showContextMenu(
    BuildContext context,
    Offset position,
    String filePath,
    String fileName,
    // bool isDirectory, // Removed as it's always false here
    WidgetRef ref,
  ) {
    // if (isDirectory) return; // Condition removed as isDirectory is always false

    final multiSelectedFiles = ref.read(multiSelectedFilesProvider);
    final bool isMultiSelectDelete =
        multiSelectedFiles.isNotEmpty && multiSelectedFiles.contains(filePath);
    final int deleteCount = isMultiSelectDelete ? multiSelectedFiles.length : 1;

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    // Build menu items dynamically
    List<PopupMenuEntry<String>> menuItems = [
      const PopupMenuItem<String>(
        value: 'open',
        child: ListTile(
          leading: Icon(Icons.open_in_browser),
          title: Text('Open'),
        ),
      ),
      const PopupMenuItem<String>(
        value: 'open_external',
        child: ListTile(
          leading: Icon(Icons.open_in_new),
          title: Text('Open with External App...'),
        ),
      ),
      const PopupMenuItem<String>(
        value: 'open_folder',
        child: ListTile(
          leading: Icon(Icons.folder_open),
          title: Text('Open Containing Folder'),
        ),
      ),
      const PopupMenuItem<String>(
        value: 'properties',
        child: ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Properties'),
        ),
      ),
      const PopupMenuDivider(),
      // Dynamic Delete Option
      PopupMenuItem<String>(
        value: isMultiSelectDelete ? 'delete_selected' : 'delete',
        child: ListTile(
          leading: const Icon(Icons.delete_outline, color: Colors.red),
          title: Text(
            isMultiSelectDelete
                ? 'Delete $deleteCount Selected Files'
                : 'Delete',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    ];

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: menuItems,
      elevation: 8.0,
    ).then<void>((String? selectedValue) async {
      if (selectedValue == null) return;

      // Read multi-select state again inside the 'then' block if needed for action
      final currentMultiSelected = ref.read(multiSelectedFilesProvider);

      String actionMessage = '';
      try {
        switch (selectedValue) {
          case 'open':
            // If multi-selecting, clear multi-select when opening single file
            if (currentMultiSelected.isNotEmpty) {
              ref.read(multiSelectedFilesProvider.notifier).state = {};
            }
            ref.read(selectedFileProvider.notifier).selectFile(filePath);
            actionMessage = '';
            break;
          case 'open_external':
            // Opening external doesn't affect multi-select state
            final result = await OpenFile.open(filePath);
            actionMessage =
                result.type == ResultType.done
                    ? 'Opening "$fileName"...'
                    : 'Could not open "$fileName": ${result.message}';
            break;
          case 'open_folder':
            // Opening folder doesn't affect multi-select state
            final dirPath = p.dirname(filePath);
            final dirUri = Uri.file(dirPath);
            if (await canLaunchUrl(dirUri)) {
              await launchUrl(dirUri);
              actionMessage = 'Opening folder for "$fileName"...';
            } else {
              actionMessage = 'Could not open folder for "$fileName".';
            }
            break;
          case 'properties':
            // Properties doesn't affect multi-select state
            actionMessage = 'Placeholder: Show properties for $fileName';
            break;
          case 'delete':
            // Handle single delete
            if (context.mounted) {
              // Check context before async gap
              _deleteFiles(context, ref, {filePath}); // Call helper
            }
            actionMessage = ''; // Message handled by helper
            break;
          case 'delete_selected':
            // Handle multi-delete
            if (context.mounted) {
              // Check context before async gap
              _deleteFiles(context, ref, currentMultiSelected); // Call helper
            }
            actionMessage = ''; // Message handled by helper
            break;
        }
        // Show action messages for non-delete actions
        if (actionMessage.isNotEmpty && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(actionMessage)));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Remove WidgetRef ref from signature
    // Access ref via 'this.ref' or just 'ref' inside ConsumerState
    final recordsAsyncValue = ref.watch(
      medicalRecordsProvider,
    ); // Use renamed provider
    final selectedFileState = ref.watch(selectedFileProvider);
    final multiSelectedFiles = ref.watch(
      multiSelectedFilesProvider,
    ); // Watch multi-select state
    final multiSelectNotifier = ref.read(multiSelectedFilesProvider.notifier);
    final singleSelectNotifier = ref.read(selectedFileProvider.notifier);
    final selectedYear = ref.watch(yearFilterProvider); // Watch selected year
    final yearFilterNotifier = ref.read(yearFilterProvider.notifier);

    // Wrap the Row in a Scaffold to allow for a FloatingActionButton
    return Scaffold(
      body: RawKeyboardListener(
        // Add keyboard listener
        focusNode: _focusNode, // Assign focus node
        autofocus: true, // Request focus automatically
        onKey: (RawKeyEvent event) {
          final isKeyDown = event is RawKeyDownEvent;
          final key = event.logicalKey;

          // Update state based on modifier keys
          // Use LogicalKeyboardKey constants
          if (key == LogicalKeyboardKey.shiftLeft ||
              key == LogicalKeyboardKey.shiftRight) {
            if (_isShiftPressed != isKeyDown) {
              // Avoid unnecessary rebuilds
              setState(() => _isShiftPressed = isKeyDown);
            }
          } else if (key == LogicalKeyboardKey.controlLeft ||
              key == LogicalKeyboardKey.controlRight ||
              key ==
                  LogicalKeyboardKey
                      .metaLeft || // Include Meta for macOS Command key
              key == LogicalKeyboardKey.metaRight) {
            if (_isCtrlPressed != isKeyDown) {
              // Avoid unnecessary rebuilds
              setState(() => _isCtrlPressed = isKeyDown);
            }
          }
        }, // Removed incorrect comment here
        child: Row(
          children: [
            // Main content area (File List + Year Filters)
            Expanded(
              child: Column(
                // Use Column to stack Filters and List
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Year Filter Chips Removed (Now handled in AppToolbar) ---
                  // --- File List ---
                  Expanded(
                    // Make the list take remaining space
                    child: Stack(
                      // Keep Stack for FAB
                      children: [
                        recordsAsyncValue.when(
                          loading:
                              () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                          error:
                              (err, stack) => Center(
                                child: Text('Error loading files: $err'),
                              ),
                          data: (data) {
                            final items =
                                data.items; // Extract items from tuple
                            if (items.isEmpty) {
                              // Show a centered button when no records are found
                              return Center(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.add_circle_outline),
                                  label: const Text('Add Medical Records'),
                                  onPressed: () async {
                                    final fileService = FileService(ref);
                                    final resultMessage = await fileService
                                        .pickAndAddFiles(context);
                                    // Show result in SnackBar
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text(resultMessage)),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                    textStyle:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                              );
                            }
                            // Use ListView
                            return ListView.builder(
                              itemCount: items.length, // Use items.length
                              itemBuilder: (context, index) {
                                final fileItem =
                                    items[index]; // Use items[index]
                                final file = fileItem.file;
                                final diagnosisDate =
                                    fileItem
                                        .diagnosisDate; // Get diagnosis date
                                final status =
                                    fileItem.status; // Get processing status
                                final isNew = fileItem.isNew; // Get new status
                                final name = p.basename(file.path);
                                final path = file.path;

                                // Format the diagnosis date if available
                                final String? formattedDate =
                                    diagnosisDate != null
                                        ? DateFormat.yMMMd().format(
                                          diagnosisDate,
                                        )
                                        : null; // Format only if date exists

                                // Determine selection state
                                final bool isSelected =
                                    multiSelectedFiles.isNotEmpty
                                        ? multiSelectedFiles.contains(path)
                                        : selectedFileState.path == path;
                                final Color? tileColor =
                                    isSelected
                                        ? Theme.of(
                                          context,
                                        ).colorScheme.primary.withOpacity(0.15)
                                        : null;

                                return GestureDetector(
                                  onSecondaryTapUp:
                                      (details) => _showContextMenu(
                                        context,
                                        details.globalPosition,
                                        path,
                                        name,
                                        // false, // Removed isDirectory parameter
                                        ref,
                                      ),
                                  onLongPress: () {
                                    // Initiate multi-select
                                    if (!multiSelectedFiles.contains(path)) {
                                      multiSelectNotifier.state = {
                                        ...multiSelectedFiles,
                                        path,
                                      };
                                      if (selectedFileState.path != null) {
                                        singleSelectNotifier.clearSelection();
                                      }
                                    }
                                  },
                                  child: ListTile(
                                    tileColor: tileColor,
                                    leading: const Icon(
                                      Icons.insert_drive_file,
                                    ),
                                    title: Row(
                                      // Use Row to add "New" label
                                      children: [
                                        Text(name),
                                        if (isNew) // Conditionally show the "New" chip
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 8.0,
                                            ),
                                            child: Chip(
                                              label: const Text('New'),
                                              padding: EdgeInsets.zero,
                                              labelPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4.0,
                                                  ),
                                              labelStyle: TextStyle(
                                                fontSize: 10,
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.onSecondary,
                                              ),
                                              backgroundColor:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.secondary,
                                              visualDensity:
                                                  VisualDensity.compact,
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle:
                                        formattedDate != null
                                            ? Text(
                                              formattedDate, // Display formatted diagnosis date
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            )
                                            : null, // Show nothing if no diagnosis date
                                    onTap: () {
                                      FocusScope.of(
                                        context,
                                      ).requestFocus(_focusNode);

                                      final currentSelection = Set<String>.from(
                                        multiSelectedFiles,
                                      );

                                      if (_isShiftPressed &&
                                          _shiftAnchorIndex != null) {
                                        // Shift+Click: Range selection
                                        final start = min(
                                          _shiftAnchorIndex!,
                                          index,
                                        );
                                        final end = max(
                                          _shiftAnchorIndex!,
                                          index,
                                        );
                                        for (int i = start; i <= end; i++) {
                                          // Access file path correctly
                                          currentSelection.add(
                                            items[i].file.path,
                                          );
                                        }
                                        multiSelectNotifier.state =
                                            currentSelection;
                                        singleSelectNotifier.clearSelection();
                                      } else if (_isCtrlPressed) {
                                        // Ctrl+Click: Toggle selection
                                        if (currentSelection.contains(path)) {
                                          currentSelection.remove(path);
                                        } else {
                                          currentSelection.add(path);
                                        }
                                        multiSelectNotifier.state =
                                            currentSelection;
                                        _shiftAnchorIndex = index;
                                        singleSelectNotifier.clearSelection();
                                      } else {
                                        // Simple Click: Single selection
                                        multiSelectNotifier.state = {};
                                        singleSelectNotifier.selectFile(path);
                                        _shiftAnchorIndex = index;
                                      }
                                    },
                                    trailing: _buildTrailingWidget(
                                      status,
                                      fileItem.hasMedoki,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        // Positioned FAB at the bottom-left
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: FloatingActionButton.extended(
                              onPressed: () {
                                // Placeholder action: Trigger a refresh
                                // TODO: Implement proper logging
                                ref.refresh(medicalRecordsProvider);
                                // TODO: Implement actual rescan logic
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Rescanning files... (refreshing list)',
                                      ),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                }
                              },
                              label: const Text('Rescan All Medical Records'),
                              icon: const Icon(Icons.refresh),
                            ),
                          ),
                        ),
                      ], // End Stack children
                    ),
                  ), // End Expanded (for ListView)
                ], // End Column children (Filters + List)
              ),
            ),
            // Vertical divider
            const VerticalDivider(width: 1, thickness: 1),
            // Sidebar (Re-use SummarySidebar)
            SizedBox(
              width: 350, // Match the width used in AppToolbar header
              child: SummarySidebar(
                selectedFilePath: selectedFileState.path,
                selectedFileName: selectedFileState.name,
                selectedFileSize: selectedFileState.size,
              ),
            ),
          ],
        ), // Closing Row
      ), // Closing RawKeyboardListener
    );
  }
}

// Helper widget to build the trailing icon/indicator based on status
Widget _buildTrailingWidget(ProcessingStatus status, bool hasMedoki) {
  switch (status) {
    case ProcessingStatus.processing:
      return const SizedBox(
        width: 20, // Give it some space
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.0),
      );
    case ProcessingStatus.pending:
      return const Tooltip(
        message: 'Pending Analysis',
        child: Icon(Icons.hourglass_empty, size: 18.0, color: Colors.blueGrey),
      );
    case ProcessingStatus.failed:
      return const Tooltip(
        message: 'Analysis Failed',
        child: Icon(Icons.error_outline, size: 18.0, color: Colors.redAccent),
      );
    case ProcessingStatus.completed:
    case ProcessingStatus.none: // Treat 'none' like 'completed' for display
    default: // Fallback
      // Show check only if medoki file exists (meaning analysis was successful at some point)
      return Icon(
        hasMedoki ? Icons.check_circle : Icons.help_outline,
        size: 18.0,
        color: hasMedoki ? Colors.green.shade600 : Colors.orange.shade700,
      );
  }
}
