import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Ref

import 'ai_service.dart';
import 'settings_service.dart';
// For SettingsState access if needed directly

// TODO: Consider using Riverpod for service provision if appropriate for the project.

class BatchAnalysisService {
  final Ref _ref; // Store ref internally
  final SettingsService _settingsService = SettingsService();
  final AIService _aiService; // Store AI Service instance

  // Private constructor
  BatchAnalysisService._(this._ref) : _aiService = _ref.read(aiServiceProvider);

  // TODO: Define method signature. How should progress/completion be reported?
  // Options: Future<ResultType>, Stream<ProgressUpdate>, Callbacks
  Future<void> runBatchAnalysis({
    // Remove Ref from arguments
    Function(String message)? onProgress, // Callback for progress updates
    Function(String error)? onError, // Callback for errors
    Function(int processed, int total)? onFileProcessed, // Callback per file
  }) async {
    // Use the stored _aiService instance initialized in the constructor
    onProgress?.call('Starting batch analysis...');

    // 1. Get base path from settings
    final basePath = await _settingsService.getMedicalRecordsPath();

    if (basePath == null || basePath.isEmpty) {
      onError?.call(
        'Medical records path not set. Please configure it in Settings.',
      );
      return;
    }

    final baseDir = Directory(basePath);
    if (!await baseDir.exists()) {
      onError?.call('Medical records directory not found: $basePath');
      return;
    }

    onProgress?.call('Scanning directory: $basePath');

    // 2. List files and filter
    final List<FileSystemEntity> allEntities;
    try {
      allEntities = await baseDir.list(recursive: true).toList();
    } catch (e) {
      onError?.call('Error listing files in $basePath: $e');
      return;
    }

    final List<File> filesToProcess = [];

    // Helper to check supported extensions
    bool isSupported(String path) {
      final ext = p.extension(path).toLowerCase();
      return [
        '.pdf', '.png', '.jpg', '.jpeg', '.webp', '.heic', '.heif',
        // Add other supported types if necessary
      ].contains(ext);
    }

    // Iterate through all entities and add supported files to the list
    for (final entity in allEntities) {
      // Skip files/directories within any 'trash' folder
      if (p.split(entity.path).contains('trash')) {
        continue;
      }

      // Only add supported files
      if (entity is File && isSupported(entity.path)) {
        filesToProcess.add(entity);
      }
    } // Correct closing brace for the entity loop

    // Now process all supported files found
    final totalFiles = filesToProcess.length;
    if (totalFiles == 0) {
      // Update message slightly as we are not checking for "new" files anymore
      onProgress?.call('No supported files found to analyze.');
      return;
    }

    onProgress?.call('Found $totalFiles files to analyze.');

    // 3. Iterate and process the filtered files
    int processedCount = 0;
    for (final file in filesToProcess) {
      processedCount++;
      final progressMessage =
          'Analyzing file $processedCount of $totalFiles: ${p.basename(file.path)}';
      onProgress?.call(progressMessage);
      print(progressMessage); // Also log to console

      try {
        // Provide a dummy callback for batch processing
        final result = await _aiService.extractDataFromFile(file.path, (step) {
          // Batch progress callback - currently does nothing
        });
        if (result != null && result.startsWith('Error:')) {
          // Log specific file error but continue batch
          print('Error processing ${file.path}: $result');
          onError?.call('Error processing ${p.basename(file.path)}: $result');
        } else {
          print('Successfully processed ${file.path}');
        }
        onFileProcessed?.call(processedCount, totalFiles);
      } catch (e) {
        // Log unexpected error but continue batch
        print('Unexpected error processing ${file.path}: $e');
        onError?.call(
          'Unexpected error processing ${p.basename(file.path)}: $e',
        );
      }
      // Optional: Add a small delay between API calls if needed
      // await Future.delayed(const Duration(seconds: 1));
    } // Correct closing brace for the processing loop

    onProgress?.call(
      'Batch analysis completed. Processed $processedCount files.',
    );
  } // Correct closing brace for runBatchAnalysis method
} // Correct closing brace for BatchAnalysisService class

/// Provider for BatchAnalysisService
final batchAnalysisServiceProvider = Provider<BatchAnalysisService>((ref) {
  return BatchAnalysisService._(ref);
});
