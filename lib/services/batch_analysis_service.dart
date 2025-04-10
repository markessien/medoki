import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Ref

import 'ai_service.dart';
import 'settings_service.dart';
import '../providers/settings_provider.dart'; // For SettingsState access if needed directly

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
    final Set<String> existingMedokiFiles = {};

    // Helper to check supported extensions (copied from AppToolbar for now)
    bool isSupported(String path) {
      final ext = p.extension(path).toLowerCase();
      return [
        '.pdf', '.png', '.jpg', '.jpeg', '.webp', '.heic', '.heif',
        // Add other supported types if necessary
      ].contains(ext);
    }

    for (final entity in allEntities) {
      if (entity is File) {
        if (entity.path.endsWith('.medoki.md')) {
          existingMedokiFiles.add(entity.path.replaceAll('.medoki.md', ''));
        } else if (isSupported(entity.path)) {
          filesToProcess.add(entity);
        }
      }
    }

    // Filter out files that already have a .medoki.md file
    final filesRequiringAnalysis =
        filesToProcess
            .where((file) => !existingMedokiFiles.contains(file.path))
            .toList();

    final totalFiles = filesRequiringAnalysis.length;
    if (totalFiles == 0) {
      onProgress?.call('No new files found requiring analysis.');
      return;
    }

    onProgress?.call('Found $totalFiles files to analyze.');

    // 3. Iterate and process
    int processedCount = 0;
    for (final file in filesRequiringAnalysis) {
      processedCount++;
      final progressMessage =
          'Analyzing file $processedCount of $totalFiles: ${p.basename(file.path)}';
      onProgress?.call(progressMessage);
      print(progressMessage); // Also log to console

      try {
        // Provide a dummy callback for batch processing as detailed steps aren't shown here
        final result = await _aiService.extractDataFromFile(file.path, (step) {
          // Use the stored _aiService instance
          // Batch progress callback - currently does nothing, but could log if needed
          // print("Batch step for ${file.path}: $step");
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
    }

    onProgress?.call(
      'Batch analysis completed. Processed $processedCount files.',
    );
  }
}

/// Provider for BatchAnalysisService
final batchAnalysisServiceProvider = Provider<BatchAnalysisService>((ref) {
  return BatchAnalysisService._(ref);
});
