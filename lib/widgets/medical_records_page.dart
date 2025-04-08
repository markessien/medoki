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
import 'package:mediciapp/widgets/summary_sidebar.dart'; // Use package import, Re-use the summary sidebar

// --- Providers for File Listing and Filtering ---

// Define a type for the file list item data, including medoki status
typedef FileListItem = ({File file, DateTime modified, bool hasMedoki});

// Provider to hold the currently selected year filter (null means 'All')
final yearFilterProvider = StateProvider<String?>((ref) => null);

// Provider to hold the current search query
final searchQueryProvider = StateProvider<String>((ref) => '');

// Provider to hold the set of multi-selected file paths
final multiSelectedFilesProvider = StateProvider<Set<String>>((ref) => {});

// Provider to fetch the names of top-level directories (potential years)
final yearFoldersProvider = FutureProvider<List<String>>((ref) async {
  final settings = ref.watch(settingsProvider);
  final basePath = settings.medicalRecordsPath;
  if (basePath == null || basePath.isEmpty) return [];

  final directory = Directory(basePath);
  if (!await directory.exists()) return [];

  final List<String> folderNames = [];
  final items = await directory.list().toList();
  for (final item in items) {
    if (item is Directory) {
      final folderName = p.basename(item.path);
      // Exclude trash folder and potentially other non-year folders if needed
      if (folderName.toLowerCase() !=
          'trash' /* && int.tryParse(folderName) != null */ ) {
        folderNames.add(folderName);
      }
    }
  }
  folderNames.sort(); // Sort alphabetically
  return folderNames;
});

// Provider to fetch and hold the filtered list of records with modification dates
final medicalRecordsProvider = FutureProvider<List<FileListItem>>((ref) async {
  final settings = ref.watch(settingsProvider);
  final basePath = settings.medicalRecordsPath; // Use renamed property
  final selectedYear = ref.watch(yearFilterProvider);
  final searchQuery =
      ref.watch(searchQueryProvider).toLowerCase(); // Watch search query

  if (basePath == null || basePath.isEmpty) {
    return [];
  }

  final directory = Directory(basePath);
  if (!await directory.exists()) {
    return [];
  }

  // --- Step 1: Get initial list of files based on year filter ---
  final List<File> filesToProcess = [];
  if (selectedYear == null) {
    // No year filter: Get files from base and one level deep (excluding trash)
    final List<FileSystemEntity> topLevelItems =
        await directory.list().toList();
    for (final item in topLevelItems) {
      if (item is File) {
        if (!item.path.toLowerCase().endsWith('.medoki.md')) {
          filesToProcess.add(item);
        }
      } else if (item is Directory) {
        if (p.basename(item.path).toLowerCase() != 'trash') {
          try {
            final subItems = await item.list().toList();
            for (final subItem in subItems) {
              if (subItem is File) {
                if (!subItem.path.toLowerCase().endsWith('.medoki.md')) {
                  filesToProcess.add(subItem);
                }
              }
            }
          } catch (e) {
            // TODO: Implement proper logging
          }
        }
      }
    }
  } else {
    // Year filter active: Get files only from the selected year directory
    final yearDirectoryPath = p.join(basePath, selectedYear);
    final yearDirectory = Directory(yearDirectoryPath);
    if (await yearDirectory.exists()) {
      try {
        final subItems = await yearDirectory.list().toList();
        for (final subItem in subItems) {
          if (subItem is File) {
            if (!subItem.path.toLowerCase().endsWith('.medoki.md')) {
              filesToProcess.add(subItem);
            }
          }
        }
      } catch (e) {
        // TODO: Implement proper logging
      }
    }
  }

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

  // --- Step 3: Get modification dates, check medoki status, and create final list items ---
  final List<FileListItem> fileListItems = [];
  for (final file in searchedFiles) {
    // Use the final filtered list
    try {
      final modifiedDate = await file.lastModified();
      // Check for corresponding .medoki.md file
      final medokiPath = '${file.path}.medoki.md';
      final hasMedoki = await File(medokiPath).exists();
      fileListItems.add((
        file: file,
        modified: modifiedDate,
        hasMedoki: hasMedoki,
      ));
    } catch (e) {
      // TODO: Implement proper logging
      // Optionally add with a default date or skip
    }
  }

  // --- Step 4: Sort the final list ---
  fileListItems.sort(
    (a, b) => p.basename(a.file.path).compareTo(p.basename(b.file.path)),
  );

  return fileListItems;
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

      // 4. Clear Selection and Refresh List
      ref.read(multiSelectedFilesProvider.notifier).state = {};
      ref
          .read(selectedFileProvider.notifier)
          .clearSelection(); // Also clear single select just in case
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
            // Main content area (File List) - Wrap Expanded in a Stack
            Expanded(
              child: Stack(
                // Wrap with Stack for positioning the FAB
                children: [
                  // Original content (the file list based on async value)
                  recordsAsyncValue.when(
                    // Rename variable
                    loading:
                        () => const Center(child: CircularProgressIndicator()),
                    error:
                        (err, stack) =>
                            Center(child: Text('Error loading files: $err')),
                    data: (items) {
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
                                ScaffoldMessenger.of(context).showSnackBar(
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
                      // Use ListView for simplicity, could use GridView later
                      return ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final fileItem = items[index];
                          final file = fileItem.file;
                          final modifiedDate = fileItem.modified;
                          final name = p.basename(file.path);
                          final path = file.path;

                          // Format the date
                          final formattedDate = DateFormat.yMMMd().format(
                            modifiedDate,
                          );

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
                              leading: const Icon(Icons.insert_drive_file),
                              title: Text(name),
                              subtitle: Text(
                                formattedDate,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              onTap: () {
                                FocusScope.of(context).requestFocus(_focusNode);

                                final currentSelection = Set<String>.from(
                                  multiSelectedFiles,
                                );

                                if (_isShiftPressed &&
                                    _shiftAnchorIndex != null) {
                                  // Shift+Click: Range selection
                                  final start = min(_shiftAnchorIndex!, index);
                                  final end = max(_shiftAnchorIndex!, index);
                                  for (int i = start; i <= end; i++) {
                                    currentSelection.add(items[i].file.path);
                                  }
                                  multiSelectNotifier.state = currentSelection;
                                  singleSelectNotifier.clearSelection();
                                } else if (_isCtrlPressed) {
                                  // Ctrl+Click: Toggle selection
                                  if (currentSelection.contains(path)) {
                                    currentSelection.remove(path);
                                  } else {
                                    currentSelection.add(path);
                                  }
                                  multiSelectNotifier.state = currentSelection;
                                  _shiftAnchorIndex = index;
                                  singleSelectNotifier.clearSelection();
                                } else {
                                  // Simple Click: Single selection
                                  multiSelectNotifier.state = {};
                                  singleSelectNotifier.selectFile(path);
                                  _shiftAnchorIndex = index;
                                }
                              },
                              trailing: Icon(
                                // Add the status icon here
                                fileItem.hasMedoki
                                    ? Icons.check_circle
                                    : Icons.help_outline,
                                size: 18.0,
                                color:
                                    fileItem.hasMedoki
                                        ? Colors.green.shade600
                                        : Colors.orange.shade700,
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
                ],
              ),
            ),
            // Add vertical divider
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
