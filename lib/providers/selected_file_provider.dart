import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

// 1. State Model
class SelectedFileState {
  final String? path;
  final String? name;
  final int? size;
  final String? aiSummaryContent;
  final String? extractionError;
  final bool isExtracting; // Flag for loading state

  const SelectedFileState({
    this.path,
    this.name,
    this.size,
    this.aiSummaryContent,
    this.extractionError,
    this.isExtracting = false, // Default to false
  });

  // Optional: Add copyWith for easier state updates
  SelectedFileState copyWith({
    String? path,
    String? name,
    int? size,
    String? aiSummaryContent,
    String? extractionError,
    bool clearError = false,
    bool? isExtracting, // Add isExtracting parameter
  }) {
    return SelectedFileState(
      path: path ?? this.path,
      name: name ?? this.name,
      size: size ?? this.size,
      aiSummaryContent: aiSummaryContent ?? this.aiSummaryContent,
      // Handle error clearing/updating
      extractionError:
          clearError ? null : extractionError ?? this.extractionError,
      // Update isExtracting flag
      isExtracting: isExtracting ?? this.isExtracting,
    );
  }
}

// 2. StateNotifier
class SelectedFileNotifier extends StateNotifier<SelectedFileState> {
  // Initialize with no file selected
  SelectedFileNotifier() : super(const SelectedFileState());

  Future<void> selectFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final fileStat = await file.stat();
        final fileName = p.basename(filePath);
        // Construct path within the data-files subdirectory
        final originalFileDir = p.dirname(filePath);
        final originalFileName = p.basename(filePath);
        final dataFilesDir = p.join(originalFileDir, 'data-files');
        final medokiFilePath = p.join(
          dataFilesDir,
          '$originalFileName.medoki.json',
        );
        String? summaryContent;

        try {
          final medokiFile = File(medokiFilePath);
          if (await medokiFile.exists()) {
            summaryContent = await medokiFile.readAsString();
          }
        } catch (e) {
          print("Error reading medoki file $medokiFilePath: $e");
          // Keep summaryContent as null
        }

        // Update state, ensuring error is cleared on successful selection/read
        // Update state, ensuring error and extracting flag are cleared
        state = SelectedFileState(
          path: filePath,
          name: fileName,
          size: fileStat.size,
          aiSummaryContent: summaryContent,
          extractionError: null,
          isExtracting: false, // Ensure false on successful selection
        );
      } else {
        // File doesn't exist, clear state
        clearSelection();
        // Optionally: throw error or log
      }
    } catch (e) {
      // Error occurred, clear state
      clearSelection();
      // Optionally: rethrow, log, or show error to user via another provider
      print("Error selecting file: $e");
    }
  }

  void clearSelection() {
    state = const SelectedFileState(); // Reset to initial empty state
  }

  // Method to specifically set an error state after an extraction attempt fails
  void setExtractionError(String error) {
    // Keep existing file info (path, name, size) but set the error
    // and clear any potentially stale summary content
    state = state.copyWith(
      aiSummaryContent: null,
      extractionError: error,
      isExtracting: false, // Ensure false when error is set
      clearError: false,
    );
  }

  // Method to set the extracting state
  void setExtracting(bool extracting) {
    // Clear error when starting extraction
    state = state.copyWith(isExtracting: extracting, clearError: true);
  }
}

// 3. Provider Definition
final selectedFileProvider =
    StateNotifierProvider<SelectedFileNotifier, SelectedFileState>((ref) {
      return SelectedFileNotifier();
    });
