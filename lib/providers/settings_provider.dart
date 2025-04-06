import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart'; // Import the service

// FutureProvider to asynchronously fetch the base path
final basePathProvider = FutureProvider<String?>((ref) async {
  // Instantiate the service (or get it from another provider if needed)
  final settingsService = SettingsService();
  // No need to call init() here if it's already called at app startup
  return await settingsService.getMedicalFilesPath();
});
