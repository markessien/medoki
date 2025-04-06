import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p; // Use prefix to avoid conflicts
// file_picker import is needed if _addRecord logic were here, but it's moved
// import 'package:file_picker/file_picker.dart';

class YearRecordsGrid extends StatefulWidget {
  final String yearName;
  final String? basePath; // Base path from settings
  final VoidCallback? onAddRecord; // Callback for FAB press

  const YearRecordsGrid({
    super.key,
    required this.yearName,
    required this.basePath,
    this.onAddRecord, // Add to constructor
  });

  @override
  State<YearRecordsGrid> createState() => _YearRecordsGridState();
}

class _YearRecordsGridState extends State<YearRecordsGrid> {
  List<FileSystemEntity> _items = [];
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

      if (mounted) {
        setState(() {
          _items =
              itemsList; // Update items (will be empty if dir doesn't exist)
          _isLoading = false;
          _error = null; // Clear any previous error
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

          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                // TODO: Handle tap
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Tapped on: $name')));
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isDirectory ? Icons.folder : Icons.insert_drive_file,
                    size: 48.0,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 8.0),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
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
}
