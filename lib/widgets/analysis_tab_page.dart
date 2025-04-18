import 'dart:io'; // Import dart:io for File operations
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:path_provider/path_provider.dart'; // No longer needed here
import 'package:path/path.dart' as p; // Import path package for joining paths
// Import both webview packages
import 'package:webview_flutter/webview_flutter.dart' as flutter_webview;
import 'package:webview_windows/webview_windows.dart' as windows_webview;

import '../services/file_service.dart'; // Import the file service
import '../services/settings_service.dart'; // Import settings service for initial load
import 'document_chat_widget.dart'; // Import the chat widget
import '../providers/selected_file_provider.dart'; // Import the provider
import 'medical_records_page.dart'; // Import medicalRecordsProvider (Renamed file)
import '../providers/analysis_providers.dart'; // Import the shared status and HTML path providers

// Provider to load the analysis summary from a file (REMOVED - Replaced by HTML path provider)
// final analysisSummaryProvider = FutureProvider<String>((ref) async { ... });

class AnalysisTabPage extends ConsumerStatefulWidget {
  // Changed to StatefulWidget
  const AnalysisTabPage({super.key});

  @override
  ConsumerState<AnalysisTabPage> createState() => _AnalysisTabPageState();
}

class _AnalysisTabPageState extends ConsumerState<AnalysisTabPage> {
  // Changed state class
  // WebViewController? _controller; // Controller for the WebView - REMOVED

  // Controller for Windows WebView
  windows_webview.WebviewController? _windowsController;
  bool _isWindowsControllerReady = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      _windowsController = windows_webview.WebviewController();
      _initWindowsWebView();
    }
    // Call _attemptInitialAnalysisLoad after the first frame to ensure providers are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Check if the widget is still mounted
        _attemptInitialAnalysisLoad();
      }
    });
  }

  // Method to attempt loading the default analysis file on startup
  Future<void> _attemptInitialAnalysisLoad() async {
    print("Attempting initial analysis load...");
    final settingsService = SettingsService();
    final recordsPath = await settingsService.getMedicalRecordsPath();
    // Need ref here, but initState doesn't have it. Access via `ref` member.
    final htmlPathNotifier = ref.read(analysisHtmlPathProvider.notifier);

    if (recordsPath != null && recordsPath.isNotEmpty) {
      final expectedFilePath = p.join(
        recordsPath,
        'data-files', // Correctly look inside the data-files subdirectory
        'analysis.medoki.analysis.html',
      );
      // Simpler: just set the path, let WebView try to load it.
      // Check if the current path is already set to avoid unnecessary updates
      if (htmlPathNotifier.state != expectedFilePath) {
        htmlPathNotifier.state = expectedFilePath;
        print("Setting initial analysis path to: $expectedFilePath");
      } else {
        print("Initial analysis path already set to: $expectedFilePath");
      }
    } else {
      print("Initial analysis load skipped: Medical records path not set.");
      // Optionally show a message if path isn't set?
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(content: Text('Medical records path not set. Cannot load initial analysis.')),
      //   );
      // }
    }
  }

  Future<void> _initWindowsWebView() async {
    if (!mounted || _windowsController == null) return;
    try {
      // Initialize the controller
      await _windowsController!.initialize();
      if (mounted) {
        setState(() {
          _isWindowsControllerReady = true;
        });
        // Initial load will be handled by the WindowsWebViewWrapper
      }
    } catch (e) {
      print('Error initializing Windows WebView: $e');
      if (mounted) {
        // Optionally show an error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing WebView: $e')),
        );
        setState(() {
          // Potentially mark as failed state?
        });
      }
    }
  }

  @override
  void dispose() {
    // Dispose the Windows controller when the state is disposed
    _windowsController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the overall medical records list to determine initial state
    final allRecordsAsyncValue = ref.watch(medicalRecordsProvider);
    // Watch the status provider for progress messages
    final analysisStatus = ref.watch(analysisStatusProvider);
    // Watch the HTML path provider
    final analysisHtmlPath = ref.watch(analysisHtmlPathProvider);
    final selectedFileState = ref.watch(selectedFileProvider);
    final refreshTrigger = ref.watch(
      analysisRefreshTriggerProvider,
    ); // Watch the trigger

    // Listen to the trigger provider to manually reload the Windows WebView
    ref.listen<int>(analysisRefreshTriggerProvider, (previous, next) {
      if (previous != next &&
          Platform.isWindows &&
          _windowsController != null &&
          _isWindowsControllerReady) {
        print('Refresh triggered for Windows WebView.');
        _windowsController!.reload();
      }
    });

    // Main Column to hold content and chat widget
    return Column(
      children: [
        // Expanded content area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(
              left: 32.0,
              right: 32.0,
              top: 24.0,
              bottom: 12.0,
            ),
            child: Container(
              width: double.infinity,
              // Remove internal padding for WebView to take full space
              // padding: const EdgeInsets.all(32.0),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300, width: 1.0),
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              // Clip WebView content to rounded corners
              clipBehavior: Clip.antiAlias,
              child: allRecordsAsyncValue.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (err, stack) =>
                        Center(child: Text('Error checking for files: $err')),
                data: (recordsData) {
                  if (recordsData.items.isEmpty) {
                    // --- No files exist: Show prompt to add records ---
                    return _buildAddRecordsPrompt(context, ref);
                  } else {
                    // --- Files exist: Show WebView, Progress, or "Run Analysis" prompt ---
                    if (analysisHtmlPath != null &&
                        analysisHtmlPath.isNotEmpty) {
                      // --- HTML Path exists: Show Platform-Specific WebView ---
                      if (Platform.isWindows) {
                        // --- Windows ---
                        if (_isWindowsControllerReady &&
                            _windowsController != null) {
                          // Schedule the URL load after the frame is built
                          // This ensures it runs on initial build and subsequent rebuilds (like hot reload)
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted &&
                                _windowsController != null &&
                                analysisHtmlPath != null &&
                                analysisHtmlPath.isNotEmpty) {
                              try {
                                final uri = Uri.file(analysisHtmlPath);
                                print(
                                  'Windows WebView: Loading URL post-frame: $uri',
                                );
                                _windowsController!.loadUrl(uri.toString());
                              } catch (e) {
                                print(
                                  "Error loading URL in postFrameCallback: $e",
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error loading content: $e',
                                      ),
                                    ),
                                  );
                                }
                              }
                            }
                          });
                          // Return the WebView widget directly
                          return windows_webview.Webview(_windowsController!);
                          // No ValueKey needed here as reload is handled by postFrameCallback
                        } else {
                          // Windows Controller initializing or failed
                          return const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue,
                              ),
                            ),
                          ); // Indicate loading
                        }
                      } else {
                        // --- Non-Windows (Use webview_flutter) ---
                        return flutter_webview.WebViewWidget(
                          // Combine path and trigger for the key to force reload on trigger change
                          key: ValueKey('$analysisHtmlPath-$refreshTrigger'),
                          controller:
                              flutter_webview.WebViewController() // Create controller inline
                                ..setJavaScriptMode(
                                  flutter_webview.JavaScriptMode.unrestricted,
                                )
                                ..setBackgroundColor(const Color(0x00000000))
                                ..setNavigationDelegate(
                                  flutter_webview.NavigationDelegate(
                                    onProgress: (int progress) {},
                                    onPageStarted: (String url) {},
                                    onPageFinished: (String url) {},
                                    onWebResourceError: (
                                      flutter_webview.WebResourceError error,
                                    ) {
                                      print(
                                        'WebView error: ${error.description}',
                                      );
                                    },
                                    onNavigationRequest: (
                                      flutter_webview.NavigationRequest request,
                                    ) {
                                      // Prevent navigation away from the local file
                                      if (!request.url.startsWith('file://')) {
                                        return flutter_webview
                                            .NavigationDecision
                                            .prevent;
                                      }
                                      return flutter_webview
                                          .NavigationDecision
                                          .navigate;
                                    },
                                  ),
                                )
                                ..loadFile(
                                  analysisHtmlPath,
                                ) // Load file on creation
                                ..setUserAgent("MedokiFlutterApp"),
                        );
                      }
                    } else {
                      // --- No HTML Path: Show Progress or "Run Analysis" prompt ---
                      final bool isAnalyzing = analysisStatus != 'Ready';
                      if (isAnalyzing) {
                        // --- Analysis in progress: Show status ---
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Padding(
                                // Add padding for status text
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32.0,
                                ),
                                child: Text(
                                  analysisStatus,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        // --- Analysis not run yet: Show prompt ---
                        return Center(
                          child: Padding(
                            // Add padding for prompt text
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32.0,
                            ),
                            child: Text(
                              'Analysis report not found. Click "Start Trend Analysis" in the toolbar.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        );
                      }
                    }
                  }
                },
              ),
            ),
          ),
        ),
        // Floating Chat Widget at the bottom
        DocumentChatWidget(selectedFilePath: selectedFileState.path),
      ],
    );
  }

  // Helper widget for the initial "Add Records" prompt
  Widget _buildAddRecordsPrompt(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            // Add padding for prompt text
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Add some medical records, then click "Start Trend Analysis" in the toolbar to generate a health report.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              final fileService = FileService(ref);
              final resultMessage = await fileService.pickAndAddFiles(context);
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(resultMessage)));
              }
            },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Add Medical Records'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              textStyle: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// REMOVED WindowsWebViewWrapper class entirely
