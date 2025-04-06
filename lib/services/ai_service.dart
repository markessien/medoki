import 'dart:convert'; // For base64 encoding
import 'dart:io';
import 'dart:typed_data'; // Needed for Uint8List

import 'package:google_generative_ai/google_generative_ai.dart' as google_ai;
import 'package:dart_openai/dart_openai.dart'; // Import OpenAI
import 'package:path/path.dart' as p; // Import path package

import 'settings_service.dart'; // Import SettingsService for enum and keys

class AIService {
  final SettingsService _settingsService =
      SettingsService(); // Get singleton instance

  // Helper to get MIME type from file extension
  String? _getMimeType(String filePath) {
    final extension = p.extension(filePath).toLowerCase();
    switch (extension) {
      case '.pdf':
        return 'application/pdf';
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.webp':
        return 'image/webp';
      case '.heic':
        return 'image/heic';
      case '.heif':
        return 'image/heif';
      // Add more supported types as needed
      default:
        // Attempt text for unknown types? Or return null?
        // For now, return null to indicate we can't handle it as binary
        print("Unsupported file type for binary extraction: $extension");
        return null;
    }
  }

  // Updated method signature - no longer takes apiKey directly
  Future<String?> extractDataFromFile(String filePath) async {
    try {
      // --- 0. Get Settings ---
      final selectedModel = await _settingsService.getSelectedAiModel();
      String? apiKey;

      switch (selectedModel) {
        case AiModelType.gemini:
          apiKey = await _settingsService.getGeminiApiKey();
          if (apiKey == null || apiKey.isEmpty) {
            return "Error: Gemini API Key not configured in settings.";
          }
          break;
        case AiModelType.openai:
          apiKey = await _settingsService.getOpenAiApiKey();
          if (apiKey == null || apiKey.isEmpty) {
            return "Error: OpenAI API Key not configured in settings.";
          }
          // Initialize OpenAI client here
          OpenAI.apiKey = apiKey;
          OpenAI.requestsTimeOut = const Duration(
            seconds: 120,
          ); // Example timeout
          break;
        case AiModelType.medoki:
          // No API key needed for the placeholder Medoki AI
          print("Using Medoki AI (Placeholder)");
          // You might return a mock response or specific logic here
          return "Extraction using Medoki AI (Placeholder).";
      }

      // --- 1. Read File and Check Existence ---
      final file = File(filePath);
      if (!await file.exists()) {
        return "Error: File not found at $filePath";
      }

      // --- 1. Determine MIME type and read bytes ---
      final mimeType = _getMimeType(filePath);
      Uint8List fileBytes;
      try {
        fileBytes = await file.readAsBytes();
        if (fileBytes.isEmpty) {
          return "Error: File is empty.";
        }
      } catch (e) {
        print("Error reading file bytes for $filePath: $e");
        return "Error: Could not read file bytes.";
      }

      if (mimeType == null) {
        return "Error: Unsupported file type for AI extraction.";
      }

      // --- 3. Prepare Prompt ---
      final promptText =
          'Extract key medical information from the attached document/image. '
          'Focus on diagnoses, medications, dates, doctor names, and procedures. '
          'Format the output clearly in Markdown.';

      // --- 4. Call Selected AI API ---
      String? resultText;

      switch (selectedModel) {
        case AiModelType.gemini:
          print("Calling Gemini API for file: $filePath...");
          final geminiModel = google_ai.GenerativeModel(
            model: 'gemini-2.0-flash-exp', // Updated model name
            apiKey: apiKey!, // Already checked for null/empty
          );
          final content = [
            google_ai.Content.multi([
              google_ai.TextPart(promptText),
              google_ai.DataPart(mimeType, fileBytes),
            ]),
          ];
          try {
            final response = await geminiModel.generateContent(content);
            resultText = response.text;
            print("Gemini API response received.");
          } on google_ai.GenerativeAIException catch (e) {
            print("Gemini API Error: ${e.message}");
            return "Error: Gemini API Error: ${e.message}";
          }
          break;

        case AiModelType.openai:
          print("Calling OpenAI API for file: $filePath...");
          // Use a vision-capable model like gpt-4o or gpt-4-vision-preview
          // Note: dart_openai uses base64 for images in chat completion
          final base64Image = base64Encode(fileBytes);
          final imageUrl = 'data:$mimeType;base64,$base64Image';

          try {
            final chatCompletion = await OpenAI.instance.chat.create(
              model: "gpt-4o", // Or "gpt-4-vision-preview"
              messages: [
                OpenAIChatCompletionChoiceMessageModel(
                  role: OpenAIChatMessageRole.user,
                  content: [
                    // Text part first
                    OpenAIChatCompletionChoiceMessageContentItemModel.text(
                      promptText,
                    ),
                    // Then image part
                    OpenAIChatCompletionChoiceMessageContentItemModel.imageUrl(
                      imageUrl,
                    ),
                  ],
                ),
              ],
              // Optional: maxTokens, temperature etc.
              // maxTokens: 500,
            );
            resultText =
                chatCompletion.choices.first.message.content?.first.text;
            print("OpenAI API response received.");
          } on RequestFailedException catch (e) {
            print("OpenAI API Error: ${e.message}");
            return "Error: OpenAI API Error: ${e.message} (Code: ${e.statusCode})";
          }
          break;

        case AiModelType.medoki:
          // Logic already handled above, returning placeholder text.
          // This case is technically unreachable here if we return early.
          resultText = "Extraction using Medoki AI (Placeholder).";
          break;
      }

      // --- 5. Process and Return Response ---
      if (resultText != null && resultText.isNotEmpty) {
        return resultText;
      } else {
        print("${selectedModel.name} response was empty or null.");
        return "Error: ${selectedModel.name} model did not return any data.";
      }
    } catch (e, stacktrace) {
      print("Error during AI data extraction ($filePath): $e\n$stacktrace");
      return "Error: An unexpected error occurred during AI extraction: $e";
    }
  }
}
