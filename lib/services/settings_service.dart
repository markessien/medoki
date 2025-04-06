import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Enum for AI Model selection
enum AiModelType { medoki, gemini, openai }

extension AiModelTypeExtension on AiModelType {
  String get name {
    switch (this) {
      case AiModelType.medoki:
        return 'Medoki AI';
      case AiModelType.gemini:
        return 'Gemini';
      case AiModelType.openai:
        return 'OpenAI';
    }
  }

  static AiModelType fromName(String? name) {
    switch (name) {
      case 'Gemini':
        return AiModelType.gemini;
      case 'OpenAI':
        return AiModelType.openai;
      case 'Medoki AI':
      default: // Default to Medoki AI if null or unknown
        return AiModelType.medoki;
    }
  }
}

class SettingsService {
  // Keys for SharedPreferences (non-sensitive)
  static const String _medicalFilesPathKey = 'medicalFilesPath';
  static const String _selectedAiModelKey = 'selectedAiModel';

  // Keys for FlutterSecureStorage (sensitive)
  static const String _secureGeminiApiKey = 'secure_geminiApiKey';
  static const String _secureOpenAiApiKey = 'secure_openAiApiKey';

  // Secure storage instance
  final _secureStorage = const FlutterSecureStorage();

  // Private constructor for singleton pattern
  SettingsService._privateConstructor();

  // Static instance variable
  static final SettingsService _instance =
      SettingsService._privateConstructor();

  // Factory constructor to return the static instance
  factory SettingsService() {
    return _instance;
  }

  // Use late initialization for SharedPreferences
  late SharedPreferences _prefs;
  bool _prefsInitialized = false;

  // Initialize SharedPreferences (only if needed)
  Future<void> _ensurePrefsInitialized() async {
    if (!_prefsInitialized) {
      _prefs = await SharedPreferences.getInstance();
      _prefsInitialized = true;
    }
  }

  // Get the stored medical files path
  Future<String?> getMedicalFilesPath() async {
    await _ensurePrefsInitialized();
    return _prefs.getString(_medicalFilesPathKey);
  }

  // Set the medical files path
  Future<void> setMedicalFilesPath(String path) async {
    await _ensurePrefsInitialized();
    await _prefs.setString(_medicalFilesPathKey, path);
  }

  // --- AI Model Selection (SharedPreferences) ---

  Future<AiModelType> getSelectedAiModel() async {
    await _ensurePrefsInitialized();
    final modelName = _prefs.getString(_selectedAiModelKey);
    return AiModelTypeExtension.fromName(modelName);
  }

  Future<void> setSelectedAiModel(AiModelType model) async {
    await _ensurePrefsInitialized();
    await _prefs.setString(_selectedAiModelKey, model.name);
  }

  // --- API Keys (Secure Storage) ---

  // Get the stored Gemini API key from secure storage
  Future<String?> getGeminiApiKey() async {
    return await _secureStorage.read(key: _secureGeminiApiKey);
  }

  // Set the Gemini API key in secure storage
  Future<void> setGeminiApiKey(String apiKey) async {
    await _secureStorage.write(key: _secureGeminiApiKey, value: apiKey);
  }

  // Get the stored OpenAI API key from secure storage
  Future<String?> getOpenAiApiKey() async {
    return await _secureStorage.read(key: _secureOpenAiApiKey);
  }

  // Set the OpenAI API key in secure storage
  Future<void> setOpenAiApiKey(String apiKey) async {
    await _secureStorage.write(key: _secureOpenAiApiKey, value: apiKey);
  }

  // Optional: Method to delete keys if needed
  Future<void> deleteGeminiApiKey() async {
    await _secureStorage.delete(key: _secureGeminiApiKey);
  }

  Future<void> deleteOpenAiApiKey() async {
    await _secureStorage.delete(key: _secureOpenAiApiKey);
  }
}
