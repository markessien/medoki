import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart'; // Required for BuildContext
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../providers/settings_provider.dart'; // To get the base path
import '../widgets/medical_records_page.dart'; // To refresh the provider (Renamed file)

// Define allowed file types (adjust as needed)
const List<String> _allowedExtensions = [
  'pdf',
  'png',
  'jpg',
  'jpeg',
  'gif',
  'bmp',
  'webp',
  'txt', // Add other relevant types
  'md',
  'docx',
];

class FileService {
  final WidgetRef ref; // Use WidgetRef to access providers

  FileService(this.ref);

  Future<String> pickAndAddFiles(BuildContext context) async {
    final settings = ref.read(settingsProvider);
    final basePath = settings.medicalRecordsPath; // Use renamed property

    if (basePath == null || basePath.isEmpty) {
      return 'Error: Medical records path is not set in settings.';
    }

    final baseDir = Directory(basePath);
    if (!await baseDir.exists()) {
      try {
        await baseDir.create(recursive: true);
      } catch (e) {
        return 'Error: Could not create base directory: $e';
      }
    }

    try {
      // Pick files
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
      );

      if (result != null && result.files.isNotEmpty) {
        int successCount = 0;
        List<String> errors = [];

        for (PlatformFile file in result.files) {
          if (file.path != null) {
            final sourcePath = file.path!;
            final fileName = p.basename(sourcePath);
            final destinationPath = p.join(basePath, fileName);

            try {
              // Check if file already exists (optional: add overwrite logic later)
              if (await File(destinationPath).exists()) {
                errors.add('"$fileName" already exists.');
                continue; // Skip this file
              }
              // Copy the file
              await File(sourcePath).copy(destinationPath);
              successCount++;
            } catch (e) {
              errors.add('Error copying "$fileName": $e');
              print("Error copying file $sourcePath: $e");
            }
          } else {
            errors.add('Could not get path for one selected file.');
          }
        }

        // Refresh the file list provider after adding files
        if (successCount > 0) {
          ref.refresh(medicalRecordsProvider); // Use renamed provider
        }

        // Construct return message
        String message = '';
        if (successCount > 0) {
          message += 'Successfully added $successCount file(s).';
        }
        if (errors.isNotEmpty) {
          message +=
              (message.isNotEmpty ? '\n' : '') + 'Errors: ${errors.join(', ')}';
        }
        return message.isEmpty ? 'No files were added.' : message;
      } else {
        // User canceled the picker
        return 'File selection cancelled.';
      }
    } catch (e) {
      // Handle potential platform exceptions from file picker
      print("Error picking files: $e");
      return 'An error occurred during file selection: $e';
    }
  }
}
