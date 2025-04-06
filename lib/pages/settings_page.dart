import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsService _settingsService = SettingsService();
  String? _medicalFilesPath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedicalFilesPath();
  }

  Future<void> _loadMedicalFilesPath() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final path = await _settingsService.getMedicalFilesPath();
      setState(() {
        _medicalFilesPath = path;
        _isLoading = false;
      });
    } catch (e) {
      // Handle potential errors during loading
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading settings: $e')));
    }
  }

  Future<void> _pickDirectory() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Medical Files Directory',
      );

      if (selectedDirectory != null) {
        await _settingsService.setMedicalFilesPath(selectedDirectory);
        setState(() {
          _medicalFilesPath = selectedDirectory;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medical files path saved.')),
        );
      } else {
        // User canceled the picker
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Directory selection cancelled.')),
        );
      }
    } catch (e) {
      // Handle potential errors during picking/saving
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error selecting directory: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Medical Files Storage Path:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Text(
                  _medicalFilesPath ?? 'Not set',
                  style: const TextStyle(fontSize: 16),
                ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: _pickDirectory,
                icon: const Icon(Icons.folder_open),
                label: const Text('Select Directory'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
