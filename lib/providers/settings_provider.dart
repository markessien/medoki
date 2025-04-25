import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart'; // Import the service and enum

final languageProvider = StateProvider<Locale>((ref) => const Locale('de'));

// 1. State Model for Settings
class SettingsState {
  final String? medicalRecordsPath; // Rename property
  final AiModelType selectedAiModel; // Added
  final String? geminiApiKey;
  final String? openAiApiKey; // Added
  final bool isLoading;
  final String? error;

  const SettingsState({
    this.medicalRecordsPath, // Rename property
    this.selectedAiModel = AiModelType.medoki, // Default to Medoki
    this.geminiApiKey,
    this.openAiApiKey,
    this.isLoading = true, // Start in loading state
    this.error,
  });

  SettingsState copyWith({
    String? medicalRecordsPath, // Rename property
    AiModelType? selectedAiModel, // Added
    String? geminiApiKey,
    String? openAiApiKey, // Added
    bool? isLoading,
    String? error,
    bool clearError = false, // Helper to clear error explicitly
  }) {
    return SettingsState(
      medicalRecordsPath:
          medicalRecordsPath ?? this.medicalRecordsPath, // Rename property
      selectedAiModel: selectedAiModel ?? this.selectedAiModel, // Added
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      openAiApiKey: openAiApiKey ?? this.openAiApiKey, // Added
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// 2. StateNotifier for Settings
class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsService _settingsService;

  SettingsNotifier(this._settingsService) : super(const SettingsState()) {
    _loadSettings(); // Load initial settings when notifier is created
  }

  // Load both settings from the service
  Future<void> _loadSettings() async {
    state = state.copyWith(isLoading: true, clearError: true); // Start loading
    try {
      // Ensure service is initialized (might be redundant if done at startup)
      // Load all settings
      final path =
          await _settingsService
              .getMedicalRecordsPath(); // Use renamed function
      final selectedModel = await _settingsService.getSelectedAiModel();
      final geminiKey = await _settingsService.getGeminiApiKey();
      final openAiKey = await _settingsService.getOpenAiApiKey();

      state = state.copyWith(
        medicalRecordsPath: path, // Rename property
        selectedAiModel: selectedModel,
        geminiApiKey: geminiKey,
        openAiApiKey: openAiKey,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: "Failed to load settings: $e",
      );
    }
  }

  // Update Medical Records Path
  Future<void> updateMedicalRecordsPath(String path) async {
    // Rename function
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _settingsService.setMedicalRecordsPath(
        path,
      ); // Use renamed function
      state = state.copyWith(
        medicalRecordsPath: path,
        isLoading: false,
      ); // Rename property
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: "Failed to save path: $e",
      );
    }
  }

  // Update Selected AI Model
  Future<void> updateSelectedAiModel(AiModelType model) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _settingsService.setSelectedAiModel(model);
      state = state.copyWith(selectedAiModel: model, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: "Failed to save AI model selection: $e",
      );
    }
  }

  // Update Gemini API Key
  Future<void> updateGeminiApiKey(String apiKey) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _settingsService.setGeminiApiKey(apiKey);
      state = state.copyWith(geminiApiKey: apiKey, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: "Failed to save Gemini API key: $e",
      );
    }
  }

  // Update OpenAI API Key
  Future<void> updateOpenAiApiKey(String apiKey) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _settingsService.setOpenAiApiKey(apiKey);
      state = state.copyWith(openAiApiKey: apiKey, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: "Failed to save OpenAI API key: $e",
      );
    }
  }
}

// 3. Provider Definition
final settingsProvider = StateNotifierProvider<
  SettingsNotifier,
  SettingsState
>((ref) {
  // Assume SettingsService is a singleton and already initialized at app start
  final settingsService = SettingsService();
  return SettingsNotifier(settingsService);
});

// Note: The old basePathProvider is removed. Code using it needs to be updated.
