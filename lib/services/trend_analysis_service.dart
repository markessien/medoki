import 'dart:convert'; // For base64 encoding if needed later, keep for consistency
import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart' as google_ai;
import 'package:dart_openai/dart_openai.dart'; // Import OpenAI
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod

import 'settings_service.dart'; // Import SettingsService for enum and keys
import '../providers/settings_provider.dart'; // To read settings provider if needed

// Note: This service focuses *only* on performing the trend analysis call.
// Data gathering/consolidation happens elsewhere (e.g., in the widget/controller).

class TrendAnalysisService {
  final Ref _ref; // Store the ref internally
  final SettingsService _settingsService =
      SettingsService(); // Get singleton instance

  // Private constructor
  TrendAnalysisService._(this._ref);

  Future<String?> performTrendAnalysis(
    String consolidatedData, // Expects pre-formatted string of historical data
    String analysisPrompt, // The specific prompt for the analysis task
    void Function(String step) updateProgress, // For progress feedback
  ) async {
    updateProgress("Starting trend analysis...");
    print("Starting Trend Analysis via TrendAnalysisService...");

    // Declare selectedModel outside the try block
    AiModelType selectedModel = AiModelType.medoki; // Default or initial value

    try {
      // --- 1. Get Settings ---
      updateProgress("Loading settings...");
      selectedModel =
          await _settingsService.getSelectedAiModel(); // Assign actual value
      String? apiKey;

      switch (selectedModel) {
        case AiModelType.gemini:
          apiKey = await _settingsService.getGeminiApiKey();
          if (apiKey == null || apiKey.isEmpty) {
            return "Error: Gemini API Key not configured.";
          }
          break;
        case AiModelType.openai:
          apiKey = await _settingsService.getOpenAiApiKey();
          if (apiKey == null || apiKey.isEmpty) {
            return "Error: OpenAI API Key not configured.";
          }
          OpenAI.apiKey = apiKey;
          OpenAI.requestsTimeOut = const Duration(
            seconds: 180,
          ); // Longer timeout?
          break;
        case AiModelType.medoki:
          print("Using Medoki AI (Placeholder) for Trend Analysis");
          await Future.delayed(const Duration(seconds: 2)); // Simulate work
          return "## Placeholder Trend Analysis\n\n*   Trend 1: Placeholder observation.\n*   Trend 2: Another placeholder point based on Medoki AI.";
      }

      // --- 2. Prepare Prompt ---
      // Combine the specific analysis prompt with the provided data
      final fullPrompt = '''
$analysisPrompt

Historical Data:
```
$consolidatedData
```
''';

      // --- 3. Call AI Model ---
      updateProgress("Sending data to AI for analysis...");
      print("Sending trend analysis request to $selectedModel...");
      String? analysisResult;

      switch (selectedModel) {
        case AiModelType.gemini:
          final geminiModel = google_ai.GenerativeModel(
            model: 'gemini-1.5-pro-latest', // Use a powerful model for analysis
            apiKey: apiKey!,
            generationConfig: google_ai.GenerationConfig(temperature: 0.5),
          );
          final content = [google_ai.Content.text(fullPrompt)];
          final response = await geminiModel.generateContent(content);
          analysisResult = response.text;
          break;
        case AiModelType.openai:
          final chatCompletion = await OpenAI.instance.chat.create(
            model: "gpt-4o", // Use a powerful model
            messages: [
              OpenAIChatCompletionChoiceMessageModel(
                role: OpenAIChatMessageRole.user,
                content: [
                  OpenAIChatCompletionChoiceMessageContentItemModel.text(
                    fullPrompt,
                  ),
                ],
              ),
            ],
            temperature: 0.5, // Adjust creativity
          );
          analysisResult =
              chatCompletion.choices.first.message.content?.first.text;
          break;
        case AiModelType.medoki:
          // Already handled above
          break;
      }

      updateProgress("Analysis received from AI.");
      print("Trend Analysis completed.");

      if (analysisResult == null || analysisResult.isEmpty) {
        return "Error: AI analysis returned an empty result.";
      }

      return analysisResult.trim();
    } catch (e, stacktrace) {
      // Now selectedModel is accessible here
      print("Error during Trend Analysis ($selectedModel): $e\n$stacktrace");
      updateProgress("Error during analysis.");
      return "Error: An unexpected error occurred during trend analysis: $e";
    }
  }
}

/// Provider for TrendAnalysisService
final trendAnalysisServiceProvider = Provider<TrendAnalysisService>((ref) {
  return TrendAnalysisService._(ref);
});
