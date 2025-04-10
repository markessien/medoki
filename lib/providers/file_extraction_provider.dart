import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_service.dart'; // Import your AI service
import '../widgets/summary_sidebar.dart'; // Import the medoki file content provider
import '../widgets/medical_records_page.dart'; // Import for medicalRecordsProvider

// State class for the extraction process
class FileExtractionState {
  final bool isLoading;
  final String? error;
  final String? currentStep; // Added to track progress

  const FileExtractionState({
    this.isLoading = false,
    this.error,
    this.currentStep, // Added
  });

  FileExtractionState copyWith({
    bool? isLoading,
    String? error,
    String? currentStep, // Added
    bool clearError = false, // Helper to clear error explicitly
    bool clearStep = false, // Helper to clear step explicitly
  }) {
    return FileExtractionState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      currentStep:
          clearStep ? null : currentStep ?? this.currentStep, // Added logic
    );
  }
}

// StateNotifier for managing single file extraction
class FileExtractionNotifier extends StateNotifier<FileExtractionState> {
  final String? filePath;
  final Ref ref; // Keep ref to read other providers/services

  FileExtractionNotifier(this.filePath, this.ref)
    : super(const FileExtractionState());

  Future<void> extractData() async {
    if (filePath == null || state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      currentStep: "Initializing...",
    ); // Set initial step

    final aiService = ref.read(
      aiServiceProvider,
    ); // Read the AI service provider
    try {
      // Define the progress callback
      void updateProgress(String step) {
        if (mounted) {
          // Check if notifier is still mounted
          state = state.copyWith(currentStep: step);
        }
      }

      final result = await aiService.extractDataFromFile(
        filePath!,
        updateProgress, // Pass the callback
      );

      if (result != null && result.startsWith("Error:")) {
        state = state.copyWith(
          isLoading: false,
          error: result,
          clearStep: true,
        ); // Clear step on error
      } else {
        // Success! Invalidate providers to force re-read/refresh
        ref.invalidate(
          medokiFileContentProvider(filePath!),
        ); // Refresh sidebar content
        ref.invalidate(medicalRecordsProvider); // Refresh the main file list
        state = state.copyWith(
          isLoading: false,
          clearError: true,
          clearStep: true,
        ); // Clear step on success
        // Optionally return success or data if needed elsewhere
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Extraction failed: $e',
        clearStep: true,
      ); // Clear step on exception
    }
  }
}

// The StateNotifierProvider family
// It takes the file path as an argument
final fileExtractionProvider = StateNotifierProvider.family<
  FileExtractionNotifier,
  FileExtractionState,
  String?
>((ref, filePath) {
  return FileExtractionNotifier(filePath, ref);
});
