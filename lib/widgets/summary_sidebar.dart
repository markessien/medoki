import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path/path.dart'
    as p; // Keep path import if needed, though basename is used in main
import 'document_chat_widget.dart'; // Import the chat widget

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
  final String? aiSummaryContent;
  final String? extractionError;
  final bool isExtracting; // Add extracting flag
  final VoidCallback? onExtractDataPressed;

  const SummarySidebar({
    super.key,
    required this.selectedFilePath,
    required this.selectedFileName,
    required this.selectedFileSize,
    this.aiSummaryContent,
    this.extractionError,
    required this.isExtracting, // Make required or provide default
    this.onExtractDataPressed,
  });

  // Helper method to build the summary content area
  Widget _buildSummaryContent(BuildContext context) {
    // Priority: Extracting > Error > Content > Button
    if (isExtracting) {
      // Display loading indicator
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
    } else if (extractionError != null && extractionError!.isNotEmpty) {
      // Display the error message
      return SingleChildScrollView(
        // Allow scrolling for long errors
        child: Text(
          extractionError!,
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontSize: 13,
          ),
        ),
      );
    } else if (aiSummaryContent != null && aiSummaryContent!.isNotEmpty) {
      // Display the summary text
      return TextField(
        controller: TextEditingController(text: aiSummaryContent),
        maxLines: null, // Allows multiple lines
        // expands: true, // REMOVED: This caused the infinite height error in SingleChildScrollView
        readOnly: true,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true, // Make it more compact if needed
          contentPadding: EdgeInsets.zero, // Remove extra padding
        ),
        style: const TextStyle(fontSize: 13),
      );
    } else {
      // Display the button
      return Center(
        // Center the button
        child: ElevatedButton.icon(
          icon: const Icon(Icons.biotech_outlined), // Example icon
          label: const Text('Extract Data with AI'),
          onPressed: onExtractDataPressed, // Use the callback
          style: ElevatedButton.styleFrom(
            // Optional: Add some styling
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      );
    }
  }

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

    // Use Stack for layering floating chat widget
    return Stack(
      children: [
        // --- Main Scrollable Content ---
        Positioned.fill(
          // Fill all space except where chat widget is
          bottom:
              60, // Estimate chat widget height + padding (adjust as needed)
          child: SingleChildScrollView(
            child: Padding(
              // Add padding to scrollable area
              padding: const EdgeInsets.only(
                bottom: 8.0,
              ), // Padding at the bottom of scroll
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Top Section (Image/Placeholder, Details) ---
                  if (isImage)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: Container(
                        margin: EdgeInsets.zero,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4.0),
                          child: Center(
                            child: Image.file(
                              File(selectedFilePath!),
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
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
                  else
                    Container(
                      height: 150,
                      margin: EdgeInsets.zero,
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
                  const SizedBox(height: 8.0),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            selectedFileName ?? 'Unknown File',
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
                          selectedFileSize != null
                              ? formatBytes(selectedFileSize!)
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

                  // --- AI Summary Section ---
                  const Divider(height: 8.0),
                  const Text(
                    'AI Summary / Actions:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8.0),
                  // Use Container with height constraints for summary area
                  // instead of Expanded inside Column inside SingleChildScrollView
                  Container(
                    constraints: const BoxConstraints(
                      minHeight: 100,
                    ), // Ensure minimum space
                    child: _buildSummaryContent(context),
                  ),
                  // --- End AI Summary Section ---
                ],
              ),
            ),
          ),
        ),
        // --- Floating Chat Widget ---
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: DocumentChatWidget(selectedFilePath: selectedFilePath),
        ),
        // --- End Floating Chat Widget ---
      ],
    );
    /* Original Column structure (pre-Stack) - keeping for reference if needed
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

        const SizedBox(height: 8.0), // Add spacing between image and text
        // Removed Transform.translate
        Padding(
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
                    ? formatBytes(selectedFileSize!) // Use the helper function
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
        const SizedBox(height: 8.0), // Add spacing before the divider
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
              // Use the helper method to build the content
              Expanded(child: _buildSummaryContent(context)),
            ],
          ),
        ),
        // --- End Bottom Scrollable Section ---

        // --- Floating Chat Widget ---
        // const Divider(height: 1, thickness: 1), // Separator removed, handled by chat widget border/shadow
        // DocumentChatWidget(selectedFilePath: selectedFilePath), // Moved to Stack
        // --- End Floating Chat Widget ---
      ],
    );
*/
  }
}
