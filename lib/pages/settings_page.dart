import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import '../providers/settings_provider.dart'; // Import the new provider
import '../services/settings_service.dart'; // Import the service for enum

// Change to ConsumerStatefulWidget
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

// Change to ConsumerState
class _SettingsPageState extends ConsumerState<SettingsPage> {
  // Controllers for the API Key TextFields
  late TextEditingController _geminiApiKeyController;
  late TextEditingController _openAiApiKeyController;
  final double _labelWidth = 150.0; // Define a width for the labels

  // Controllers for Account section
  late TextEditingController _emailController;
  late TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _geminiApiKeyController = TextEditingController();
    _openAiApiKeyController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    // Initialize controllers text after the first frame when provider state is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider);
      _geminiApiKeyController.text = settings.geminiApiKey ?? '';
      _openAiApiKeyController.text = settings.openAiApiKey ?? '';
    });
  }

  @override
  void dispose() {
    _geminiApiKeyController.dispose(); // Dispose the controllers
    _openAiApiKeyController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Method to pick directory (uses provider now)
  Future<void> _pickDirectory() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Medical Records Directory', // Rename title
      );

      if (selectedDirectory != null && mounted) {
        // Call provider notifier to update path
        await ref
            .read(settingsProvider.notifier)
            .updateMedicalRecordsPath(
              selectedDirectory,
            ); // Use renamed function
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medical records path saved.'),
          ), // Rename message
        );
      } else if (mounted) {
        // User canceled the picker
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Directory selection cancelled.')),
        );
      }
    } catch (e) {
      // Handle potential errors during picking/saving
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting directory: $e')),
        );
      }
    }
  }

  // Method to save Gemini API Key
  Future<void> _saveGeminiApiKey() async {
    final newApiKey = _geminiApiKeyController.text.trim();
    await ref.read(settingsProvider.notifier).updateGeminiApiKey(newApiKey);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gemini API Key saved.')));
      FocusScope.of(context).unfocus();
    }
  }

  // Method to save OpenAI API Key
  Future<void> _saveOpenAiApiKey() async {
    final newApiKey = _openAiApiKeyController.text.trim();
    await ref.read(settingsProvider.notifier).updateOpenAiApiKey(newApiKey);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('OpenAI API Key saved.')));
      FocusScope.of(context).unfocus();
    }
  }

  // Helper widget to build a setting row
  Widget _buildSettingRow({
    required String label,
    required Widget control,
    String? description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start, // Align top for multi-line controls
        children: [
          SizedBox(
            width: _labelWidth,
            child: Padding(
              padding: const EdgeInsets.only(
                right: 16.0,
                top: 8.0,
              ), // Add padding for alignment
              child: Text(
                label,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                control,
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper for Section Titles
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the settings provider state
    final settingsState = ref.watch(settingsProvider);

    // Update controllers if state changes externally (e.g., initial load)
    // Use a listener to avoid calling setState during build
    ref.listen<SettingsState>(settingsProvider, (previous, next) {
      if (mounted && !next.isLoading) {
        if (_geminiApiKeyController.text != (next.geminiApiKey ?? '')) {
          _geminiApiKeyController.text = next.geminiApiKey ?? '';
        }
        if (_openAiApiKeyController.text != (next.openAiApiKey ?? '')) {
          _openAiApiKeyController.text = next.openAiApiKey ?? '';
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body:
          settingsState.isLoading &&
                  settingsState.medicalRecordsPath ==
                      null // Use renamed property
              ? const Center(
                child: CircularProgressIndicator(),
              ) // Show loading only initially
              : Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16.0,
                ),
                child: ListView(
                  children: [
                    // --- Account Section ---
                    _buildSectionTitle("Account"),
                    _buildSettingRow(
                      label: "Email",
                      control: TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          hintText: "Enter your email",
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    _buildSettingRow(
                      label: "Password",
                      control: TextField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          hintText: "Enter your password",
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        obscureText: true,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 150.0, bottom: 8.0),
                      child: Row(
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              final email = _emailController.text.trim();
                              final password = _passwordController.text;
                              // TODO: Replace with real login logic
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Login attempted for $email'),
                                ),
                              );
                            },
                            child: const Text("Login"),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  final TextEditingController
                                  _newEmailController = TextEditingController();
                                  final TextEditingController
                                  _newPasswordController =
                                      TextEditingController();
                                  final TextEditingController
                                  _confirmPasswordController =
                                      TextEditingController();
                                  return AlertDialog(
                                    title: const Text("Create Account"),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextField(
                                          controller: _newEmailController,
                                          decoration: const InputDecoration(
                                            labelText: "Email",
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          keyboardType:
                                              TextInputType.emailAddress,
                                        ),
                                        const SizedBox(height: 12),
                                        TextField(
                                          controller: _newPasswordController,
                                          decoration: const InputDecoration(
                                            labelText: "Password",
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          obscureText: true,
                                        ),
                                        const SizedBox(height: 12),
                                        TextField(
                                          controller:
                                              _confirmPasswordController,
                                          decoration: const InputDecoration(
                                            labelText: "Confirm Password",
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          obscureText: true,
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text("Cancel"),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          final email =
                                              _newEmailController.text.trim();
                                          final password =
                                              _newPasswordController.text;
                                          final confirmPassword =
                                              _confirmPasswordController.text;
                                          if (email.isEmpty ||
                                              password.isEmpty ||
                                              confirmPassword.isEmpty) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Please fill in all fields.',
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                          if (password != confirmPassword) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Passwords do not match.',
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                          // TODO: Replace with real account creation logic
                                          Navigator.of(context).pop();
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Account created for $email',
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Text("Create"),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            child: const Text("Create Account"),
                          ),
                        ],
                      ),
                    ),
                    // --- Storage Section ---
                    _buildSectionTitle("Storage"),
                    _buildSettingRow(
                      label: "Medical Records Path", // Rename label
                      control: Column(
                        // Use Column for path text and button
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            settingsState.medicalRecordsPath ??
                                'Not set', // Use renamed property
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _pickDirectory,
                            child: const Text('Select Directory'),
                          ),
                        ],
                      ),
                      description:
                          "The base folder where your yearly medical records are stored.",
                    ),
                    const Divider(),

                    // --- AI Settings Section ---
                    _buildSectionTitle("AI Configuration"),
                    // AI Model Selection Dropdown
                    _buildSettingRow(
                      label: "AI Model",
                      control: DropdownButtonFormField<AiModelType>(
                        value: settingsState.selectedAiModel,
                        items:
                            AiModelType.values.map((model) {
                              return DropdownMenuItem<AiModelType>(
                                value: model,
                                child: Text(model.name),
                              );
                            }).toList(),
                        onChanged: (AiModelType? newValue) {
                          if (newValue != null) {
                            ref
                                .read(settingsProvider.notifier)
                                .updateSelectedAiModel(newValue);
                          }
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                        ),
                      ),
                      description: "Select the AI service for analysis.",
                    ),

                    // Conditional Gemini API Key Input
                    if (settingsState.selectedAiModel == AiModelType.gemini)
                      _buildSettingRow(
                        label: "Gemini API Key",
                        control: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _geminiApiKeyController,
                              decoration: const InputDecoration(
                                hintText: 'Enter your Gemini API Key',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                              ),
                              style: const TextStyle(fontSize: 14),
                              obscureText: true, // Hide the key
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _saveGeminiApiKey,
                              child: const Text('Save Gemini Key'),
                            ),
                          ],
                        ),
                        description: "Required if Gemini model is selected.",
                      ),

                    // Conditional OpenAI API Key Input
                    if (settingsState.selectedAiModel == AiModelType.openai)
                      _buildSettingRow(
                        label: "OpenAI API Key",
                        control: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _openAiApiKeyController,
                              decoration: const InputDecoration(
                                hintText: 'Enter your OpenAI API Key',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                              ),
                              style: const TextStyle(fontSize: 14),
                              obscureText: true, // Hide the key
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _saveOpenAiApiKey,
                              child: const Text('Save OpenAI Key'),
                            ),
                          ],
                        ),
                        description: "Required if OpenAI model is selected.",
                      ),

                    // Display error if any
                    if (settingsState.error != null) ...[
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 166,
                        ), // Align with controls
                        child: Text(
                          'Error: ${settingsState.error}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
    );
  }
}
