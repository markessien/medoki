import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_service.dart'; // Import your AI service
import '../widgets/summary_sidebar.dart'; // Import the medoki file content provider

// State class for the extraction process
class FileExtractionState {
  final bool isLoading;
  final String? error;
  // Add any other relevant state, e.g., progress if applicable

  const FileExtractionState({this.isLoading = false, this.error});

  FileExtractionState copyWith({bool? isLoading, String? error}) {
    return FileExtractionState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
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

    state = state.copyWith(isLoading: true, error: null);

    final aiService = AIService(); // Instantiate your AI service
    try {
      final result = await aiService.extractDataFromFile(filePath!);

      if (result != null && result.startsWith("Error:")) {
        state = state.copyWith(isLoading: false, error: result);
      } else {
        // Success! Invalidate the medoki content provider to force re-read
        ref.invalidate(medokiFileContentProvider(filePath!));
        state = state.copyWith(isLoading: false, error: null);
        // Optionally return success or data if needed elsewhere
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Extraction failed: $e');
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
