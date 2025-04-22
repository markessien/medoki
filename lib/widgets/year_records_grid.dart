import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:open_file/open_file.dart'; // Import open_file package
import 'package:path/path.dart' as p; // Use prefix to avoid conflicts
// Needed for documents directory
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher
import '../providers/selected_file_provider.dart'; // Import the provider
// file_picker import is needed if _addRecord logic were here, but it's moved
// import 'package:file_picker/file_picker.dart';

// --- Provider for Medoki File Status ---
// Family provider: Keyed by yearName, holds a Set of file paths that have a .medoki.json file
final medokiStatusProvider = StateProvider.family<Set<String>, String>((
  ref,
  yearName,
) {
  // Initial state is an empty set, populated by _loadDirectoryContents
  return <String>{};
});
// --- End Provider ---

// Change to ConsumerStatefulWidget
class YearRecordsGrid extends ConsumerStatefulWidget {
  final String yearName;
  final String? basePath; // Base path from settings
  final VoidCallback? onAddRecord; // Callback for FAB press
  final Function(String filePath)? onFileSelected; // Callback for file tap
  // final String? selectedFilePath; // Removed - use provider

  const YearRecordsGrid({
    super.key,
    required this.yearName,
    required this.basePath,
    this.onAddRecord, // Add to constructor
    this.onFileSelected, // Add to constructor
  });

  @override
  // Change to ConsumerState
  ConsumerState<YearRecordsGrid> createState() => _YearRecordsGridState();
}

// Change to ConsumerState
class _YearRecordsGridState extends ConsumerState<YearRecordsGrid> {
  List<FileSystemEntity> _items = [];
  // Removed local state: Map<String, bool> _medokiFileStatus = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDirectoryContents();
  }

  // Watch for changes in basePath or yearName to reload
  @override
  void didUpdateWidget(covariant YearRecordsGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.basePath != oldWidget.basePath ||
        widget.yearName != oldWidget.yearName) {
      _loadDirectoryContents();
    }
  }

  Future<void> _loadDirectoryContents() async {
    // Avoid reload if already loading
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      // If called while already loading (e.g. quick tab switch), ensure state reflects loading
      if (mounted) {
        // Check if mounted before setState
        setState(() {
          _error = null; // Clear previous error if any
        });
      }
    }

    if (widget.basePath == null || widget.basePath!.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Medical records path not set. Please set it in Settings.';
          _items = []; // Ensure items are cleared
        });
      }
      return;
    }

    try {
      final fullPath = p.join(widget.basePath!, widget.yearName);
      final directory = Directory(fullPath);
      List<FileSystemEntity> itemsList = []; // Initialize empty list

      if (await directory.exists()) {
        itemsList = await directory.list().toList();
        // Filter out .medoki.json files
        itemsList =
            itemsList
                .where(
                  (item) => !item.path.toLowerCase().endsWith('.medoki.json'),
                )
                .toList();
        // Sort items: directories first, then files, alphabetically
        itemsList.sort((a, b) {
          bool aIsDir = a is Directory;
          bool bIsDir = b is Directory;
          if (aIsDir != bIsDir) {
            return aIsDir ? -1 : 1; // Directories first
          }
          return p
              .basename(a.path)
              .compareTo(p.basename(b.path)); // Then alphabetically
        });
      }
      // If directory doesn't exist, itemsList remains empty

      // Check for corresponding .medoki.json files and update the provider
      final Set<String> medokiFiles = {};
      for (var item in itemsList) {
        if (item is File) {
          // Construct path within the data-files subdirectory
          final originalFileDir = p.dirname(item.path);
          final originalFileName = p.basename(item.path);
          final dataFilesDir = p.join(originalFileDir, 'data-files');
          final medokiPath = p.join(
            dataFilesDir,
            '$originalFileName.medoki.json',
          );
          if (await File(medokiPath).exists()) {
            medokiFiles.add(item.path); // Add path if .medoki.json exists
          }
        }
      }
      // Update the provider state for this specific year
      ref.read(medokiStatusProvider(widget.yearName).notifier).state =
          medokiFiles;

      if (mounted) {
        // Only update items, isLoading, and error locally
        setState(() {
          _items = itemsList;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error accessing directory: $e';
          _items = []; // Clear items on error
        });
      }
    }
  }

  // _addRecord method is removed from here. Logic is in _MyHomePageState.

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;

    if (_isLoading) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      // Display error message
      bodyContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (_items.isEmpty) {
      // Display "No records found" message
      bodyContent = Center(
        child: Text('No records found in ${widget.yearName} folder.'),
      );
    } else {
      // Build the GridView if items exist
      bodyContent = GridView.builder(
        padding: const EdgeInsets.all(8.0),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 150.0,
          childAspectRatio: 1.0,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
        ),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final isDirectory = item is Directory;
          final name = p.basename(item.path);
          final path = item.path; // Store path for menu actions
          // Watch the provider for the current year's status
          final medokiStatuses = ref.watch(
            medokiStatusProvider(widget.yearName),
          );
          final hasMedokiFile = medokiStatuses.contains(path);

          // Use GestureDetector to detect right-clicks (onSecondaryTapUp)
          return GestureDetector(
            onSecondaryTapUp: (details) {
              // Show context menu only for files, not directories (for now)
              if (!isDirectory) {
                _showContextMenu(context, details.globalPosition, path, name);
              }
            },
            child: Container(
              // Wrap Card with Container for border
              decoration: BoxDecoration(
                border: Border.all(
                  // Use provider state for color condition
                  color:
                      ref.watch(selectedFileProvider).path == path
                          ? Colors
                              .blue // Blue border if selected
                          : Colors.transparent, // No border if not selected
                  width: 2.0, // Border width
                ),
                borderRadius: BorderRadius.circular(
                  4.0,
                ), // Match Card's default radius (approx)
              ),
              child: Card(
                clipBehavior: Clip.antiAlias,
                // Remove Card's default margin if Container adds too much space
                // margin: EdgeInsets.zero,
                child: InkWell(
                  onTap: () {
                    if (!isDirectory) {
                      // Call the callback only for files
                      widget.onFileSelected?.call(path);
                    } else {
                      // Optional: Handle directory tap differently if needed
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Tapped on folder: $name')),
                      );
                    }
                  },
                  // Use Stack to overlay the icon
                  child: Stack(
                    children: [
                      // Original content (Icon and Text)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isDirectory
                                ? Icons.folder
                                : Icons.insert_drive_file,
                            size: 48.0,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 8.0),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                            child: Text(
                              name,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              style: const TextStyle(fontSize: 12.0),
                            ),
                          ),
                        ],
                      ),
                      // Status Icon Overlay (only for files)
                      if (!isDirectory)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Icon(
                            hasMedokiFile
                                ? Icons
                                    .check_circle // Checkmark if exists
                                : Icons.help_outline, // Question mark if not
                            size: 18.0,
                            color:
                                hasMedokiFile
                                    ? Colors
                                        .green
                                        .shade600 // Green for checkmark
                                    : Colors
                                        .orange
                                        .shade700, // Orange for question mark
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    // Return the Scaffold wrapping the body content and adding the FAB
    return Scaffold(
      body: bodyContent,
      // Only show FAB if not loading and no critical error preventing interaction
      floatingActionButton:
          (_isLoading || _error != null && _error!.contains('path not set'))
              ? null // Hide FAB if loading or base path not set
              : FloatingActionButton(
                onPressed: widget.onAddRecord, // Call the passed-in callback
                tooltip: 'Add Record',
                child: const Icon(Icons.add),
              ),
    );
  }

  // Method to show the context menu
  void _showContextMenu(
    BuildContext context,
    Offset position,
    String filePath,
    String fileName,
  ) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40), // Small rectangle at tap position
        Offset.zero & overlay.size, // Overlay boundaries
      ),
      items: <PopupMenuEntry<String>>[
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
            leading: Icon(Icons.open_in_new), // Example icon
            title: Text('Open with External App...'),
          ),
        ),
        const PopupMenuItem<String>(
          // Added new menu item
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
        const PopupMenuDivider(), // Separator
        const PopupMenuItem<String>(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red),
            title: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ),
      ],
      elevation: 8.0,
    ).then<void>((String? selectedValue) async {
      // Make async for file operations
      if (selectedValue == null) return; // User dismissed the menu

      // --- Actions ---
      String actionMessage = '';
      try {
        switch (selectedValue) {
          case 'open':
            // Call the same callback used for direct taps to select the file
            widget.onFileSelected?.call(filePath);
            // No snackbar message needed here as the selection itself is the feedback
            actionMessage = ''; // Clear any potential default message
            break;
          case 'open_external':
            final result = await OpenFile.open(filePath);
            if (result.type == ResultType.done) {
              actionMessage =
                  'Opening "$fileName"...'; // Feedback that the attempt was made
            } else {
              // Handle specific errors if needed, or show a generic message
              actionMessage = 'Could not open "$fileName": ${result.message}';
            }
            break;
          case 'open_folder': // Added case for the new action
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
            actionMessage = 'Placeholder: Show properties for $fileName';
            // TODO: Implement properties view logic
            break;
          case 'delete':
            // Show confirmation dialog before moving
            final bool? confirmed = await showDialog<bool>(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Confirm Move to Trash'),
                  content: Text(
                    'Are you sure you want to move "$fileName" to the trash folder in your Documents?',
                  ),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () {
                        Navigator.of(context).pop(false); // Not confirmed
                      },
                    ),
                    TextButton(
                      child: const Text('Move to Trash'),
                      onPressed: () {
                        Navigator.of(context).pop(true); // Confirmed
                      },
                    ),
                  ],
                );
              },
            );

            if (confirmed == true) {
              // Ensure basePath is available
              if (widget.basePath == null || widget.basePath!.isEmpty) {
                throw Exception("Medical records base path is not set.");
              }

              // Create trash folder path within the base path
              final trashDirPath = p.join(widget.basePath!, 'trash');
              final trashDir = Directory(trashDirPath);

              // Create trash folder if it doesn't exist
              if (!await trashDir.exists()) {
                await trashDir.create(recursive: true);
              }

              // Create destination path
              final destinationPath = p.join(trashDirPath, fileName);

              // Move the file
              final fileToMove = File(filePath);
              if (await fileToMove.exists()) {
                await fileToMove.rename(destinationPath);
                actionMessage = '"$fileName" moved to trash.';
                _loadDirectoryContents(); // Refresh the grid
              } else {
                actionMessage = 'Error: File "$fileName" not found.';
              }
            } else {
              actionMessage = 'Move cancelled.'; // User cancelled
            }
            break; // End of delete case
        }
        // Show feedback only if an action was attempted or cancelled
        if (actionMessage.isNotEmpty && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(actionMessage)));
        }
      } catch (e) {
        // Handle errors during file operations or dialog display
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        }
      }
      // --- End Actions ---
    });
  }
}
