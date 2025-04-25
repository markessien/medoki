import 'dart:convert'; // For base64 encoding
import 'dart:io';
import 'dart:typed_data'; // Needed for Uint8List

import 'package:google_generative_ai/google_generative_ai.dart' as google_ai;
import 'package:dart_openai/dart_openai.dart'; // Import OpenAI
import 'package:path/path.dart' as p; // Import path package
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod

import 'settings_service.dart'; // Import SettingsService for enum and keys
import '../providers/file_processing_provider.dart'; // Import status provider
import '../widgets/medical_records_page.dart'; // Import for refreshing medicalRecordsProvider

class AIService {
  final Ref _ref; // Store the ref internally
  final SettingsService _settingsService =
      SettingsService(); // Get singleton instance

  // Private constructor
  AIService._(this._ref);

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
  Future<String?> extractDataFromFile(
    String filePath,
    void Function(String step) updateProgress, // Add callback parameter
  ) async {
    final statusNotifier = _ref.read(fileProcessingStatusProvider.notifier);
    // Update status to 'processing' immediately
    statusNotifier.setStatus(filePath, ProcessingStatus.processing);
    // Refresh the list provider *after* setting status to processing
    // This ensures the UI shows the spinner immediately.
    _ref.refresh(medicalRecordsProvider);

    try {
      // --- 0. Get Settings ---
      updateProgress("Loading settings..."); // Report progress
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
      updateProgress("Reading file..."); // Report progress
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
      updateProgress("Transcribing document..."); // Report progress
      print("Starting Transcription for: $filePath");
      final transcriptionPrompt =
          'Extract all text content from the attached document/image as accurately as possible. Format the output as Markdown.';
      String? transcriptionMarkdown;

      try {
        switch (selectedModel) {
          case AiModelType.gemini:
            final geminiModel = google_ai.GenerativeModel(
              model: 'gemini-2.0-flash', // Use a capable model
              apiKey: apiKey,
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

      // Check if transcription is null, empty, or just whitespace
      if (transcriptionMarkdown == null ||
          transcriptionMarkdown.trim().isEmpty) {
        print("Transcription result was null, empty, or only whitespace.");
        return "Error: Transcription failed to produce valid text.";
      }
      print("Transcription completed for: $filePath");

      // --- 4. Step 2: Classification (Is it Medical?) ---
      updateProgress("Classifying document type...");
      print("Starting Document Classification for: $filePath");
      final classificationPrompt = '''
Analyze the following transcription. Determine if it primarily contains medical information (e.g., lab results, doctor's notes, prescriptions, medical history, symptoms, diagnosis, treatment plans).

Respond with a JSON object containing a single key "is_medical" with a boolean value (true or false). Example: {"is_medical": true}

Transcription:
```markdown
$transcriptionMarkdown
```
''';
      bool isMedical = false; // Default to false

      try {
        String? rawClassificationResult;
        switch (selectedModel) {
          case AiModelType.gemini:
            final geminiModel = google_ai.GenerativeModel(
              model: 'gemini-2.0-flash',
              apiKey: apiKey,
              generationConfig: google_ai.GenerationConfig(
                responseMimeType: "application/json", // Request JSON output
              ),
            );
            final content = [google_ai.Content.text(classificationPrompt)];
            final response = await geminiModel.generateContent(content);
            rawClassificationResult = response.text?.trim();
            break;
          case AiModelType.openai:
            final chatCompletion = await OpenAI.instance.chat.create(
              model: "gpt-4o", // Or a cheaper model like gpt-3.5-turbo
              responseFormat: {"type": "json_object"}, // Request JSON output
              messages: [
                OpenAIChatCompletionChoiceMessageModel(
                  role: OpenAIChatMessageRole.user,
                  content: [
                    OpenAIChatCompletionChoiceMessageContentItemModel.text(
                      classificationPrompt,
                    ),
                  ],
                ),
              ],
            );
            rawClassificationResult =
                chatCompletion.choices.first.message.content?.first.text
                    ?.trim();
            break;
          case AiModelType.medoki:
            // Placeholder: Assume medical for testing, or add logic
            rawClassificationResult = '{"is_medical": true}';
            break;
        }

        if (rawClassificationResult != null &&
            rawClassificationResult.isNotEmpty) {
          try {
            final decodedJson = jsonDecode(rawClassificationResult);
            if (decodedJson is Map<String, dynamic> &&
                decodedJson.containsKey('is_medical') &&
                decodedJson['is_medical'] is bool) {
              isMedical = decodedJson['is_medical'];
            } else {
              print(
                "Warning: Classification returned invalid JSON structure: $rawClassificationResult",
              );
              // Decide how to handle - assume not medical? Or try a fallback?
              // For now, stick with the default 'false'.
            }
          } catch (e) {
            print(
              "Error decoding classification JSON ($selectedModel): $e. Raw: $rawClassificationResult",
            );
          }
        }
      } catch (e) {
        print("Error during Classification ($selectedModel): $e");
        // Decide how to handle - assume not medical? Or fail?
        // For now, stick with the default 'false' and log the error.
      }
      print("Classification completed for: $filePath. Is Medical: $isMedical");

      // --- Conditional Extraction based on Classification ---
      List<Map<String, dynamic>>? extractedLabResults;
      String? extractedDateString;
      String? summaryText;
      String finalStatusMessage = "Processing completed."; // Default message

      if (isMedical) {
        // --- 5. Step 3: Lab Result Extraction (if medical) ---
        updateProgress("Extracting lab results..."); // Report progress
        print("Starting Lab Result Extraction for: $filePath");
        final labExtractionPrompt = '''
Analyze the following medical record transcription. If it contains laboratory test results, extract each result into a JSON object with the following keys: "test_name", "value", "units", "reference_range".

Return the results as a JSON array of these objects.

Example format:
[
  {"test_name": "Hemoglobin A1c", "value": "6.5", "units": "%", "reference_range": "4.0-5.6"},
  {"test_name": "Glucose", "value": "110", "units": "mg/dL", "reference_range": "70-99"}
]

If no lab results are found, return an empty JSON array `[]`.

Transcription:
```markdown
$transcriptionMarkdown
```
''';
        // Removed redundant declaration of extractedLabResults

        try {
          String? rawLabResultString;
          switch (selectedModel) {
            case AiModelType.gemini:
              final geminiModel = google_ai.GenerativeModel(
                model: 'gemini-2.0-flash', // Or a model suitable for text tasks
                apiKey: apiKey,
              );
              final content = [google_ai.Content.text(labExtractionPrompt)];
              final response = await geminiModel.generateContent(content);
              rawLabResultString = response.text?.trim();
              break;
            case AiModelType.openai:
              final chatCompletion = await OpenAI.instance.chat.create(
                model: "gpt-4o", // Or a cheaper text model
                responseFormat: {"type": "json_object"}, // Request JSON output
                messages: [
                  OpenAIChatCompletionChoiceMessageModel(
                    role: OpenAIChatMessageRole.user,
                    content: [
                      OpenAIChatCompletionChoiceMessageContentItemModel.text(
                        labExtractionPrompt,
                      ),
                    ],
                  ),
                ],
              );
              rawLabResultString =
                  chatCompletion.choices.first.message.content?.first.text
                      ?.trim();
              break;
            case AiModelType.medoki:
              // Placeholder for Medoki AI lab extraction
              rawLabResultString = "[]"; // Default to empty array
              break;
          }

          // Attempt to parse the JSON response
          if (rawLabResultString != null && rawLabResultString.isNotEmpty) {
            // Clean potential markdown code fences
            if (rawLabResultString.startsWith('```json')) {
              rawLabResultString = rawLabResultString.substring(7);
            }
            if (rawLabResultString.endsWith('```')) {
              rawLabResultString = rawLabResultString.substring(
                0,
                rawLabResultString.length - 3,
              );
            }
            rawLabResultString =
                rawLabResultString.trim(); // Trim again after removing fences

            try {
              final decodedJson = jsonDecode(rawLabResultString);
              if (decodedJson is List) {
                // Validate structure (basic check)
                extractedLabResults =
                    decodedJson.whereType<Map<String, dynamic>>().toList();
                // Optional: Add deeper validation per item schema here
              } else {
                print(
                  "Warning: Lab result extraction returned valid JSON, but it wasn't a List: $rawLabResultString",
                );
                extractedLabResults = []; // Treat as no results if not a list
              }
            } catch (e) {
              print(
                "Error decoding lab results JSON ($selectedModel): $e. Raw response: $rawLabResultString",
              );
              extractedLabResults = []; // Treat as no results on decode error
            }
          } else {
            extractedLabResults = []; // Treat empty/null response as no results
          }
        } catch (e) {
          print("Error during Lab Result Extraction ($selectedModel): $e");
          extractedLabResults = []; // Default to empty list on error
        }
        print(
          "Lab Result Extraction completed for: $filePath. Found ${extractedLabResults.length ?? 0} results.",
        );

        // --- 6. Step 4: Date Extraction (if medical) ---
        updateProgress("Extracting date..."); // Report progress
        print("Starting Date Extraction for: $filePath");
        // Updated prompt to ask for ISO 8601 UTC date
        final dateExtractionPrompt =
            'From the following medical record transcription, extract the exact date when the test, procedure, or visit occurred. If multiple dates are present, use the primary date of the event described. Format the date as an ISO 8601 UTC string (YYYY-MM-DDTHH:MM:SSZ or YYYY-MM-DD if time is unknown, defaulting time to 00:00:00Z). If no specific date can be found, return the string "null".\n\nTranscription:\n```markdown\n$transcriptionMarkdown\n```';
        // Removed redundant declaration of extractedDateString

        try {
          switch (selectedModel) {
            case AiModelType.gemini:
              final geminiModel = google_ai.GenerativeModel(
                model: 'gemini-2.0-flash', // Or a model suitable for text tasks
                apiKey: apiKey,
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

        // --- 7. Step 5: Summarization (if medical) ---
        updateProgress("Summarizing content..."); // Report progress
        print("Starting Summarization for: $filePath");
        final summarizationPrompt =
            'Provide a concise summary (1-3 sentences) of the key information in the following medical record transcription:\n\n```markdown\n$transcriptionMarkdown\n```';
        // Removed redundant declaration of summaryText

        try {
          switch (selectedModel) {
            case AiModelType.gemini:
              final geminiModel = google_ai.GenerativeModel(
                model:
                    'gemini-2.0-flash', // Can use the same or a different text model
                apiKey: apiKey,
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

        // *** Add check for empty summary if medical ***
        if (summaryText.trim().isEmpty) {
          print(
            "Error: Summarization failed to produce text for medical document.",
          );
          statusNotifier.setStatus(filePath, ProcessingStatus.failed);
          _ref.refresh(medicalRecordsProvider);
          return "Error: Summarization failed to produce text."; // Return error before saving
        }
        finalStatusMessage =
            summaryText.trim(); // Already checked it's not null/empty
      } else {
        // Document is not medical
        updateProgress("Skipping medical extraction (not a medical doc)...");
        print("Skipping detailed extraction for non-medical file: $filePath");
        // Set default values for non-medical files
        extractedLabResults = [];
        extractedDateString = null;
        summaryText = "File classified as non-medical.";
        finalStatusMessage = summaryText;
      }

      // --- 8. Structure and Save JSON ---
      updateProgress("Saving results..."); // Report progress

      Map<String, dynamic> medokiData;
      String outputFileName;
      // Get original file name *before* potentially modifying it for the output path
      final originalFileName = p.basename(filePath);

      if (isMedical) {
        medokiData = {
          'summary': summaryText.trim() ?? "Summary not generated.",
          'testDateUTC': extractedDateString,
          'lab_results': extractedLabResults ?? [],
          // Optionally include transcription if needed later
          'transcription_markdown':
              transcriptionMarkdown.trim(), // Uncommented this line
        };
        outputFileName = '$originalFileName.medoki.json';
      } else {
        // Structure for non-medical files
        medokiData = {
          'classification': 'non-medical',
          'message':
              'This file was classified as non-medical and detailed extraction was skipped.',
          // Include transcription for reference if desired
          'transcription_markdown': transcriptionMarkdown.trim(),
        };
        outputFileName = '$originalFileName.medoki.invalid.json';
      }

      // Use an encoder with indentation for readability
      final jsonEncoder = JsonEncoder.withIndent('  ');
      final jsonString = jsonEncoder.convert(medokiData);

      // Construct the path for the data-files subdirectory
      final originalFileDir = p.dirname(filePath);
      // final originalFileName = p.basename(filePath); // Already have this from above
      final dataFilesDir = p.join(originalFileDir, 'data-files');
      final outputJsonFilePath = p.join(dataFilesDir, outputFileName);

      try {
        // Ensure the data-files directory exists
        await Directory(dataFilesDir).create(recursive: true);

        final outputFile = File(outputJsonFilePath);
        await outputFile.writeAsString(jsonString);
        print("Successfully wrote analysis data to: $outputJsonFilePath");
      } catch (e) {
        print("Error writing analysis file to $outputJsonFilePath: $e");
        statusNotifier.setStatus(filePath, ProcessingStatus.failed);
        _ref.refresh(medicalRecordsProvider); // Refresh on error too
        return "Error: Could not save analysis results.";
      }

      // --- 9. Update Status and Return Message ---
      statusNotifier.setStatus(
        filePath,
        ProcessingStatus.completed,
      ); // Set status to completed
      // Return the summary (if medical) or the non-medical message
      return finalStatusMessage;
    } catch (e, stacktrace) {
      print("Error during AI data extraction ($filePath): $e\n$stacktrace");
      statusNotifier.setStatus(
        filePath,
        ProcessingStatus.failed,
      ); // Set status to failed
      return "Error: An unexpected error occurred during AI extraction: $e";
    } finally {
      // Refresh list one last time in case state changed quickly
      _ref.refresh(medicalRecordsProvider);
    }
  }

  /// Sends a chat message in the analysis context, including the Health Analysis Document as context.
  /// Returns the AI's reply as a string.
  Future<String> sendAnalysisChatMessage({
    required String userMessage,
    required String healthAnalysisDocument,
  }) async {
    final selectedModel = await _settingsService.getSelectedAiModel();
    String? apiKey;

    try {
      switch (selectedModel) {
        case AiModelType.gemini:
          apiKey = await _settingsService.getGeminiApiKey();
          if (apiKey == null || apiKey.isEmpty) {
            return "Error: Gemini API Key not configured in settings.";
          }
          final geminiModel = google_ai.GenerativeModel(
            model: 'gemini-2.0-flash',
            apiKey: apiKey,
          );
          final content = [
            google_ai.Content.multi([
              google_ai.TextPart(
                "You are a medical assistant. The following is the Health Analysis Document for context:\n\n$healthAnalysisDocument\n\nNow answer the user's question based on this document.",
              ),
              google_ai.TextPart(userMessage),
            ]),
          ];
          final response = await geminiModel.generateContent(content);
          return response.text?.trim() ?? "No response from Gemini AI.";
        case AiModelType.openai:
          apiKey = await _settingsService.getOpenAiApiKey();
          if (apiKey == null || apiKey.isEmpty) {
            return "Error: OpenAI API Key not configured in settings.";
          }
          OpenAI.apiKey = apiKey;
          OpenAI.requestsTimeOut = const Duration(seconds: 120);
          final chatCompletion = await OpenAI.instance.chat.create(
            model: "gpt-4o",
            messages: [
              OpenAIChatCompletionChoiceMessageModel(
                role: OpenAIChatMessageRole.system,
                content: [
                  OpenAIChatCompletionChoiceMessageContentItemModel.text(
                    "You are a medical assistant. The following is the Health Analysis Document for context:\n\n$healthAnalysisDocument",
                  ),
                ],
              ),
              OpenAIChatCompletionChoiceMessageModel(
                role: OpenAIChatMessageRole.user,
                content: [
                  OpenAIChatCompletionChoiceMessageContentItemModel.text(
                    userMessage,
                  ),
                ],
              ),
            ],
          );
          return chatCompletion.choices.first.message.content?.first.text
                  ?.trim() ??
              "No response from OpenAI.";
        case AiModelType.medoki:
          // Placeholder for Medoki AI
          return "Medoki AI is not implemented for chat.";
      }
    } catch (e) {
      return "Error during AI chat: $e";
    }
  }
}

/// Provider for AIService
final aiServiceProvider = Provider<AIService>((ref) {
  return AIService._(ref);
});
