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

      // --- 2. Determine MIME type and read bytes ---
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

      // --- 3. Step 1: Transcription ---
      print("Starting Transcription for: $filePath");
      final transcriptionPrompt =
          'Extract all text content from the attached document/image as accurately as possible. Format the output as Markdown.';
      String? transcriptionMarkdown;

      try {
        switch (selectedModel) {
          case AiModelType.gemini:
            final geminiModel = google_ai.GenerativeModel(
              model: 'gemini-1.5-flash', // Use a capable model
              apiKey: apiKey!,
            );
            final content = [
              google_ai.Content.multi([
                google_ai.TextPart(transcriptionPrompt),
                google_ai.DataPart(mimeType, fileBytes),
              ]),
            ];
            final response = await geminiModel.generateContent(content);
            transcriptionMarkdown = response.text;
            break;
          case AiModelType.openai:
            final base64Image = base64Encode(fileBytes);
            final imageUrl = 'data:$mimeType;base64,$base64Image';
            final chatCompletion = await OpenAI.instance.chat.create(
              model: "gpt-4o",
              messages: [
                OpenAIChatCompletionChoiceMessageModel(
                  role: OpenAIChatMessageRole.user,
                  content: [
                    OpenAIChatCompletionChoiceMessageContentItemModel.text(
                      transcriptionPrompt,
                    ),
                    OpenAIChatCompletionChoiceMessageContentItemModel.imageUrl(
                      imageUrl,
                    ),
                  ],
                ),
              ],
            );
            transcriptionMarkdown =
                chatCompletion.choices.first.message.content?.first.text;
            break;
          case AiModelType.medoki:
            transcriptionMarkdown =
                "## Placeholder Transcription\n\nThis is placeholder Markdown content for Medoki AI.";
            break;
        }
      } catch (e) {
        print("Error during Transcription ($selectedModel): $e");
        return "Error during Transcription ($selectedModel): $e";
      }

      if (transcriptionMarkdown == null || transcriptionMarkdown.isEmpty) {
        print("Transcription result was empty.");
        return "Error: Transcription failed to produce text.";
      }
      print("Transcription completed for: $filePath");

      // --- 4. Step 2: Date Extraction ---
      print("Starting Date Extraction for: $filePath");
      // Updated prompt to ask for ISO 8601 UTC date
      final dateExtractionPrompt =
          'From the following medical record transcription, extract the exact date when the test, procedure, or visit occurred. If multiple dates are present, use the primary date of the event described. Format the date as an ISO 8601 UTC string (YYYY-MM-DDTHH:MM:SSZ or YYYY-MM-DD if time is unknown, defaulting time to 00:00:00Z). If no specific date can be found, return the string "null".\n\nTranscription:\n```markdown\n$transcriptionMarkdown\n```';
      String? extractedDateString;

      try {
        switch (selectedModel) {
          case AiModelType.gemini:
            final geminiModel = google_ai.GenerativeModel(
              model: 'gemini-1.5-flash', // Or a model suitable for text tasks
              apiKey: apiKey!,
            );
            final content = [google_ai.Content.text(dateExtractionPrompt)];
            final response = await geminiModel.generateContent(content);
            extractedDateString = response.text?.trim();
            break;
          case AiModelType.openai:
            final chatCompletion = await OpenAI.instance.chat.create(
              model: "gpt-4o", // Or a cheaper text model
              messages: [
                OpenAIChatCompletionChoiceMessageModel(
                  role: OpenAIChatMessageRole.user,
                  content: [
                    OpenAIChatCompletionChoiceMessageContentItemModel.text(
                      dateExtractionPrompt,
                    ),
                  ],
                ),
              ],
              // Optional: Add temperature or other parameters if needed
            );
            extractedDateString =
                chatCompletion.choices.first.message.content?.first.text
                    ?.trim();
            break;
          case AiModelType.medoki:
            // Placeholder for Medoki AI date extraction
            extractedDateString = "null"; // Default to null if not found
            break;
        }
      } catch (e) {
        print("Error during Date Extraction ($selectedModel): $e");
        // Decide if we should proceed without a date or fail
        // For now, let's proceed but log the error. The date will be null.
        extractedDateString = "null";
      }

      // Validate or clean the extracted date string
      if (extractedDateString == null ||
          extractedDateString.toLowerCase() == 'null' ||
          extractedDateString.isEmpty) {
        extractedDateString =
            null; // Store actual null if AI indicates none found
      } else {
        // Optional: Add more robust validation/parsing here if needed
        // For example, try DateTime.parseISO8601(extractedDateString) in a try-catch
        // to ensure it's a valid format before storing.
        try {
          // Attempt parsing to validate format (optional but recommended)
          DateTime.parse(extractedDateString);
          print("Extracted Date (Raw): $extractedDateString");
        } catch (e) {
          print(
            "Warning: AI returned a date string '$extractedDateString' that couldn't be parsed as ISO 8601 UTC. Storing as null.",
          );
          extractedDateString = null; // Store null if format is invalid
        }
      }
      print("Date Extraction completed for: $filePath");

      // --- 5. Step 3: Summarization ---
      print("Starting Summarization for: $filePath");
      final summarizationPrompt =
          'Provide a concise summary (1-3 sentences) of the key information in the following medical record transcription:\n\n```markdown\n$transcriptionMarkdown\n```';
      String? summaryText;

      try {
        switch (selectedModel) {
          case AiModelType.gemini:
            final geminiModel = google_ai.GenerativeModel(
              model:
                  'gemini-1.5-flash', // Can use the same or a different text model
              apiKey: apiKey!,
            );
            final content = [google_ai.Content.text(summarizationPrompt)];
            final response = await geminiModel.generateContent(content);
            summaryText = response.text;
            break;
          case AiModelType.openai:
            final chatCompletion = await OpenAI.instance.chat.create(
              model: "gpt-4o", // Or a cheaper text model like gpt-3.5-turbo
              messages: [
                OpenAIChatCompletionChoiceMessageModel(
                  role: OpenAIChatMessageRole.user,
                  content: [
                    OpenAIChatCompletionChoiceMessageContentItemModel.text(
                      summarizationPrompt,
                    ),
                  ],
                ),
              ],
            );
            summaryText =
                chatCompletion.choices.first.message.content?.first.text;
            break;
          case AiModelType.medoki:
            summaryText = "This is a placeholder summary from Medoki AI.";
            break;
        }
      } catch (e) {
        print("Error during Summarization ($selectedModel): $e");
        // Decide if we should still save the transcription or fail completely
        return "Error during Summarization ($selectedModel): $e";
      }

      if (summaryText == null || summaryText.isEmpty) {
        print("Summarization result was empty.");
        return "Error: Summarization failed to produce text.";
      }
      print("Summarization completed for: $filePath");

      // --- 6. Structure and Save JSON ---
      final medokiData = {
        'transcription': transcriptionMarkdown.trim(),
        'summary': summaryText.trim(),
        'testDateUTC':
            extractedDateString, // Add the extracted date (can be null)
      };
      // Use an encoder with indentation for readability
      final jsonEncoder = JsonEncoder.withIndent('  ');
      final jsonString = jsonEncoder.convert(medokiData);
      final medokiFilePath = '$filePath.medoki.md';

      try {
        final medokiFile = File(medokiFilePath);
        await medokiFile.writeAsString(jsonString);
        print("Successfully wrote medoki data to: $medokiFilePath");
      } catch (e) {
        print("Error writing .medoki.md file: $e");
        return "Error: Could not save analysis results.";
      }

      // --- 7. Return Summary for UI ---
      // Still return the summary, but the date is now saved in the file.
      return summaryText.trim();
    } catch (e, stacktrace) {
      print("Error during AI data extraction ($filePath): $e\n$stacktrace");
      return "Error: An unexpected error occurred during AI extraction: $e";
    }
  }
}
