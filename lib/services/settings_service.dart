import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _medicalFilesPathKey = 'medicalFilesPath';

  // Private constructor for singleton pattern
  SettingsService._privateConstructor();

  // Static instance variable
  static final SettingsService _instance =
      SettingsService._privateConstructor();

  // Factory constructor to return the static instance
  factory SettingsService() {
    return _instance;
  }

  late SharedPreferences _prefs;

  // Initialize SharedPreferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Get the stored medical files path
  Future<String?> getMedicalFilesPath() async {
    // Ensure prefs is initialized before using it
    if (!_prefs.containsKey(_medicalFilesPathKey)) {
      await init(); // Initialize if not already done (e.g., first run)
    }
    return _prefs.getString(_medicalFilesPathKey);
  }

  // Set the medical files path
  Future<void> setMedicalFilesPath(String path) async {
    if (!_prefs.containsKey(_medicalFilesPathKey)) {
      await init(); // Ensure initialized
    }
    await _prefs.setString(_medicalFilesPathKey, path);
  }
}
