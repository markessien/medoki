import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path/path.dart'
    as p; // Keep path import if needed, though basename is used in main

// Helper function to format bytes (moved from main.dart)
String formatBytes(int bytes, [int decimals = 2]) {
  if (bytes <= 0) return "0 B";
  const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
  var i = (log(bytes) / log(1024)).floor();
  return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
}

class SummarySidebar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // This is the logic moved from _buildSidebarContent in main.dart
    if (selectedFilePath == null) {
      return const Center(
        child: Text(
          'Select a file to see details.',
          textAlign: TextAlign.center,
        ),
      );
    }

    // Basic image extension check
    final isImage = [
      '.png',
      '.jpg',
      '.jpeg',
      '.gif',
      '.bmp',
      '.webp',
    ].any((ext) => selectedFilePath!.toLowerCase().endsWith(ext));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Top Sticky Section ---
        // Image Preview (if applicable) - Removed Expanded, added ConstrainedBox
        if (isImage)
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 200, // Limit max height of the image preview
            ),
            child: Container(
              margin: EdgeInsets.zero, // Removed bottom margin completely
              // Removed decoration to remove the border
              child: ClipRRect(
                // Clip the image to rounded corners (optional, but keeps rounding)
                borderRadius: BorderRadius.circular(4.0),
                child: Center(
                  // Center the image within the ClipRRect
                  child: Image.file(
                    File(selectedFilePath!),
                    fit: BoxFit.contain, // Show the whole image
                    errorBuilder: (context, error, stackTrace) {
                      // Show an error icon if image fails to load
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 40,
                            ),
                            SizedBox(height: 8),
                            Text('Could not load image preview.'),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          )
        else // Placeholder if not an image
          Container(
            height: 150, // Fixed height placeholder
            margin: EdgeInsets.zero, // Removed bottom margin completely
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: const Center(
              child: Icon(
                Icons.insert_drive_file_outlined,
                size: 50,
                color: Colors.grey,
              ),
            ),
          ),

        // Removed SizedBox

        // Apply negative offset to pull text up
        Transform.translate(
          offset: const Offset(0, -20.0), // Further increased negative offset
          child: Padding(
            // Add padding for the row
            padding: const EdgeInsets.symmetric(
              horizontal: 4.0,
            ), // Add horizontal padding if needed
            child: Row(
              // Use Row for horizontal layout
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween, // Space between items
              children: [
                // File Name (Smaller Font) - Use Expanded to handle overflow
                Expanded(
                  child: Text(
                    selectedFileName ?? 'Unknown File',
                    style: const TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 11,
                      height: 0.8, // Further reduce line height
                    ), // Smaller font, normal weight
                    overflow: TextOverflow.ellipsis, // Handle long filenames
                    maxLines: 1, // Ensure it stays on one line
                  ),
                ),
                // Spacer removed, using MainAxisAlignment.spaceBetween
                // File Size (Smaller Font)
                Text(
                  selectedFileSize != null
                      ? formatBytes(
                        selectedFileSize!,
                      ) // Use the helper function
                      : 'Unknown size',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 10,
                    height: 0.8, // Further reduce line height
                  ), // Smaller font
                ),
              ],
            ),
          ),
        ),
        // --- End Top Sticky Section ---

        // --- Bottom Scrollable Section ---
        // Wrap the rest in an Expanded Column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // Keep alignment
            children: [
              const Divider(height: 8.0), // Further reduced Divider height
              // Placeholder for future AI summary or actions
              const Text(
                'AI Summary / Actions:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8.0),
              // Keep the TextField Expanded within this Column
              const Expanded(
                child: TextField(
                  maxLines: null,
                  expands: true,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'AI analysis will appear here...',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        // --- End Bottom Scrollable Section ---
      ],
    );
  }
}
