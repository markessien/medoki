import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart'; // For kDebugMode

import 'package:google_generative_ai/google_generative_ai.dart' as google_ai;
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_service.dart';
import '../providers/settings_provider.dart';
import 'html_report_generator.dart'; // Import HTML generator
// Note: analysis_providers.dart is NOT imported here, status updates are handled via callbacks

// Note: This service focuses *only* on performing the trend analysis call.
// Data gathering/consolidation happens elsewhere (e.g., in the widget/controller).

class TrendAnalysisService {
  final Ref _ref; // Store the ref internally
  final SettingsService _settingsService =
      SettingsService(); // Get singleton instance

  // Private constructor
  TrendAnalysisService._(this._ref);

  // --- Prompt Structure ---
  // Defines how the analysis prompt and historical data are combined.
  // Use placeholders {analysisPrompt} and {consolidatedData}.
  static const String _promptTemplate = '''
{analysisPrompt}

Historical Data:
```
{consolidatedData}
```
''';

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
      // Combine the specific analysis prompt with the provided data using the template
      final fullPrompt = _promptTemplate
          .replaceAll('{analysisPrompt}', analysisPrompt)
          .replaceAll('{consolidatedData}', consolidatedData);

      // --- 3. Call AI Model ---
      updateProgress("Sending data to AI for analysis...");
      print("Sending trend analysis request to $selectedModel...");
      String? analysisResult;

      switch (selectedModel) {
        case AiModelType.gemini:
          final geminiModel = google_ai.GenerativeModel(
            model: 'gemini-1.5-pro-latest', // Use a powerful model for analysis
            apiKey: apiKey,
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
  // --- Full Trend Analysis Orchestration ---

  Future<void> runFullTrendAnalysis({
    required void Function(String message) onProgress,
    required void Function(String error) onError,
    required void Function(String? savedFilePath, List<String> fileErrors)
    onComplete,
  }) async {
    onProgress('Starting trend analysis... Preparing data.');

    try {
      // Use the existing instance from the service
      final recordsPath = await _settingsService.getMedicalRecordsPath();

      if (recordsPath == null || recordsPath.isEmpty) {
        onError('Error: Medical records path not set in Settings.');
        return;
      }

      final recordsDir = Directory(recordsPath);
      if (!await recordsDir.exists()) {
        onError('Error: Medical records directory not found: $recordsPath');
        return;
      }

      onProgress('Scanning for analysis files...');
      final List<Map<String, dynamic>> allData = [];
      final List<String> fileReadErrors = []; // Renamed from 'errors'

      await for (final entity in recordsDir.list(
        recursive: true,
        followLinks: false,
      )) {
        // Check if the file is a .medoki.json file inside a 'data-files' directory
        if (entity is File &&
            p.basename(p.dirname(entity.path)) == 'data-files' &&
            entity.path.endsWith('.medoki.json')) {
          try {
            final content = await entity.readAsString();
            // Use jsonDecode from dart:convert
            final jsonData = jsonDecode(content) as Map<String, dynamic>;
            if (jsonData.containsKey('summary') &&
                jsonData.containsKey('lab_results') &&
                jsonData.containsKey('testDateUTC')) {
              allData.add({
                'filePath': entity.path,
                'summary': jsonData['summary'],
                'testDateUTC': jsonData['testDateUTC'],
                'lab_results': jsonData['lab_results'],
              });
            } else {
              fileReadErrors.add(
                'Skipping ${p.basename(entity.path)}: Missing required keys.',
              );
            }
          } catch (e) {
            fileReadErrors.add(
              'Error reading/parsing ${p.basename(entity.path)}: $e',
            );
          }
        }
      }

      if (allData.isEmpty) {
        onError('No valid .medoki.json files found for analysis.');
        return;
      }

      // Sort data by date
      allData.sort((a, b) {
        final dateA =
            a['testDateUTC'] != null
                ? DateTime.tryParse(a['testDateUTC'])
                : null;
        final dateB =
            b['testDateUTC'] != null
                ? DateTime.tryParse(b['testDateUTC'])
                : null;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) {
          return -1; // Or 1 depending on desired sort for nulls
        }
        if (dateB == null) return 1; // Or -1
        return dateA.compareTo(dateB);
      });

      onProgress('Consolidating data from ${allData.length} records...');
      final buffer = StringBuffer();
      String latestRecordDataString = ''; // To store the latest record's data

      for (int i = 0; i < allData.length; i++) {
        final data = allData[i];
        final fileName = p.basename(data['filePath']);
        if (i == 0) {
          onProgress('Consolidating data starting with: $fileName');
        }

        final recordBuffer = StringBuffer();
        recordBuffer.writeln('---');
        recordBuffer.writeln('File: $fileName');
        recordBuffer.writeln('Date: ${data['testDateUTC'] ?? 'Unknown'}');
        recordBuffer.writeln('Summary: ${data['summary']}');
        if (data['lab_results'] is List &&
            (data['lab_results'] as List).isNotEmpty) {
          recordBuffer.writeln('Lab Results:');
          for (final lab in data['lab_results']) {
            if (lab is Map) {
              recordBuffer.writeln(
                '  - ${lab['test_name']}: ${lab['value']} ${lab['units']} (${lab['reference_range']})',
              );
            }
          }
        }
        recordBuffer.writeln();

        final currentRecordString = recordBuffer.toString();
        buffer.write(currentRecordString);

        if (i == allData.length - 1) {
          latestRecordDataString = currentRecordString;
        }
      }
      final consolidatedData = buffer.toString();

      // --- Step 1: Analyze Current Situation ---
      onProgress('Analyzing current health situation...');
      print("Step 1: Generating prompt for Current Situation");
      final currentSituationPrompt =
          HtmlReportGenerator.generateCurrentSituationPrompt(
            latestRecordDataString,
          );

      print("Step 1: Sending request to AI for Current Situation");
      final String? currentSituationResult = await performTrendAnalysis(
        latestRecordDataString,
        currentSituationPrompt,
        (step) => onProgress('AI Analysis (Current Situation): $step'),
      );

      if (currentSituationResult == null ||
          currentSituationResult.startsWith('Error:')) {
        onError(
          currentSituationResult ??
              'Error: Failed to analyze current situation.',
        );
        return; // Stop further processing
      }
      print("Step 1: Received result for Current Situation");

      // --- Step 2: Analyze Yearly Summaries ---
      onProgress('Analyzing yearly summaries...');
      print("Step 2: Generating prompt for Yearly Summaries");
      final yearlySummariesPrompt =
          HtmlReportGenerator.generateYearlySummariesPrompt(consolidatedData);

      print("Step 2: Sending request to AI for Yearly Summaries");
      final String? yearlySummariesResult = await performTrendAnalysis(
        consolidatedData,
        yearlySummariesPrompt,
        (step) => onProgress('AI Analysis (Yearly Summaries): $step'),
      );

      if (yearlySummariesResult == null ||
          yearlySummariesResult.startsWith('Error:')) {
        onError(
          yearlySummariesResult ?? 'Error: Failed to analyze yearly summaries.',
        );
        return; // Stop further processing
      }
      print("Step 2: Received result for Yearly Summaries");

      // --- Step 3: Analyze Trends ---
      onProgress('Analyzing historical trends...');
      print("Step 3: Generating prompt for Trends");
      final trendsPrompt = HtmlReportGenerator.generateTrendsPrompt(
        consolidatedData,
      );

      print("Step 3: Sending request to AI for Trends");
      final String? trendsResult = await performTrendAnalysis(
        consolidatedData,
        trendsPrompt,
        (step) => onProgress('AI Analysis (Trends): $step'),
      );

      if (trendsResult == null || trendsResult.startsWith('Error:')) {
        onError(trendsResult ?? 'Error: Failed to analyze trends.');
        return; // Stop further processing
      }
      print("Step 3: Received result for Trends");

      // --- Step 4: Analyze Organ Health ---
      onProgress('Analyzing organ health observations...');
      print("Step 4: Generating prompt for Organ Health");
      final organsPrompt = HtmlReportGenerator.generateOrgansPrompt(
        consolidatedData,
      );

      print("Step 4: Sending request to AI for Organ Health");
      final String? organsResult = await performTrendAnalysis(
        consolidatedData,
        organsPrompt,
        (step) => onProgress('AI Analysis (Organ Health): $step'),
      );

      if (organsResult == null || organsResult.startsWith('Error:')) {
        onError(organsResult ?? 'Error: Failed to analyze organ health.');
        return; // Stop further processing
      }
      print("Step 4: Received result for Organ Health");

      // --- Step 5: Combine and Save Report ---
      onProgress('Generating final report...');
      print("Step 5: Combining results into final HTML");
      final String finalHtmlContent =
          HtmlReportGenerator.generateFullHtmlReport(
            currentSituationResult,
            yearlySummariesResult,
            trendsResult,
            organsResult, // Added organs result
          );

      final String outputFileName = 'analysis.medoki.analysis.html';
      String? savedFilePath;

      try {
        // recordsPath is guaranteed non-null here due to earlier checks
        // Construct path within the data-files subdirectory
        final dataFilesDir = p.join(recordsPath, 'data-files');
        final filePath = p.join(dataFilesDir, outputFileName);

        // Ensure the data-files directory exists
        await Directory(dataFilesDir).create(recursive: true);

        final outputFile = File(filePath);
        await outputFile.writeAsString(finalHtmlContent);
        savedFilePath = filePath;
        print('Analysis HTML saved to: $filePath');
        onProgress('Analysis complete. Report saved.');

        if (kDebugMode) {
          print(
            "--- Trend Analysis Combined Report Saved ---\nPath: $savedFilePath\n--- End Report ---",
          );
        }

        // Report completion successfully
        onComplete(savedFilePath, fileReadErrors);
      } catch (e) {
        print('Error saving analysis HTML: $e');
        onError('Error saving analysis report: $e');
        // Report completion with error (null path)
        onComplete(null, fileReadErrors);
      }
    } catch (e, stacktrace) {
      print("Error during Full Trend Analysis orchestration: $e\n$stacktrace");
      onError(
        'Error: An unexpected error occurred during trend analysis orchestration: $e',
      );
      // Report completion with error (null path) and no file errors (as it failed before file processing)
      onComplete(null, []);
    }
  }
}

/// Provider for TrendAnalysisService
final trendAnalysisServiceProvider = Provider<TrendAnalysisService>((ref) {
  return TrendAnalysisService._(ref);
});
