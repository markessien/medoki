import 'package:flutter/material.dart';
// import 'models/year.dart'; // Removed
import 'pages/settings_page.dart'; // Import SettingsPage
import 'services/settings_service.dart'; // Import SettingsService
// import 'services/year_service.dart'; // Removed
// import 'widgets/year_management_dialog.dart'; // Removed
// import 'widgets/year_records_grid.dart'; // Removed (will replace)
import 'widgets/summary_sidebar.dart'; // Import the new sidebar widget
import 'widgets/app_toolbar.dart'; // Import the new toolbar widget
// import 'widgets/year_tab_page.dart'; // Removed
import 'widgets/analysis_tab_page.dart'; // Import the new analysis tab page widget
// import 'widgets/analysis_sidebar.dart'; // Removed import
import 'widgets/medical_records_page.dart'; // Import the new medical records page widget (Renamed file)
import 'providers/selected_file_provider.dart'; // Import the selected file provider
import 'providers/settings_provider.dart'; // Import the settings provider
// import 'providers/year_service_provider.dart'; // Removed
// import 'providers/years_provider.dart'; // Removed
import 'dart:io'; // Import dart:io for File and Directory
import 'package:file_picker/file_picker.dart'; // Import file_picker
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:path/path.dart' as p; // Import path package

void main() {
  // No longer needs async or yearService
  WidgetsFlutterBinding.ensureInitialized();
  // SettingsService initialization is handled internally.
  // YearService initialization removed.
  runApp(
    // Wrap the entire app in a ProviderScope
    const ProviderScope(
      // Removed overrides
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  // final YearService yearService; // Removed

  const MyApp({super.key}); // Removed yearService parameter

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medoki', // Changed App Title
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
      ),
      home: const MyHomePage(
        // Can be const now
        title:
            'Medoki - Privately Analyse Your Medical Documents with AI', // Changed AppBar Title
        // yearService removed
      ),
    );
  }
}

// Change to ConsumerStatefulWidget
class MyHomePage extends ConsumerStatefulWidget {
  final String title;
  // final YearService yearService; // Removed

  const MyHomePage({super.key, required this.title}); // Removed yearService

  @override
  // Change to ConsumerState
  ConsumerState<MyHomePage> createState() => _MyHomePageState();
}

// Change to ConsumerState and remove TickerProvider if not needed elsewhere (TabController needs it)
class _MyHomePageState extends ConsumerState<MyHomePage>
    with TickerProviderStateMixin {
  TabController? _tabController; // Make nullable initially
  int _currentIndex = 0; // To track the current tab index
  // Define tab indices
  final int _analysisTabIndex = 0;
  final int _filesTabIndex = 1; // Define index for the new Files tab
  // Removed year-related state: years, _yearRefreshCounters

  @override
  void initState() {
    super.initState();
    // Initialize TabController with 2 tabs
    _tabController = TabController(length: 2, vsync: this);
    _tabController!.addListener(_handleTabSelection);
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabSelection);
    _tabController?.dispose();
    super.dispose();
  }

  // Listener function for TabController
  void _handleTabSelection() {
    if (_tabController != null && _tabController!.index != _currentIndex) {
      setState(() {
        _currentIndex = _tabController!.index;
      });
    }
  }

  // _formatBytes removed - moved to summary_sidebar.dart

  // _handleFileSelected removed - logic moved to SelectedFileNotifier

  // _loadBasePath removed - provider handles loading

  // Method to handle adding new files to the base directory
  Future<void> _addFiles() async {
    // 1. Read the current settings state from the provider
    final settingsState = ref.read(settingsProvider);
    final currentBasePath =
        settingsState.medicalRecordsPath; // Use renamed property

    // Check if base path is available and not empty
    if (currentBasePath == null || currentBasePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Medical records path not set. Please set it in Settings.',
          ),
        ),
      );
      return;
    }

    // Target directory is now just the base path
    final targetDirectoryPath = currentBasePath;

    try {
      // Pick files
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        // No need to create directory if copying to base path

        int successCount = 0;
        List<String> errors = [];

        // 5. Copy selected files
        for (var file in result.files) {
          if (file.path != null) {
            try {
              final sourceFile = File(file.path!);
              final destinationPath = p.join(targetDirectoryPath, file.name);
              await sourceFile.copy(destinationPath);
              successCount++;
            } catch (e) {
              errors.add('Error copying ${file.name}: $e');
            }
          } else {
            errors.add('Could not get path for ${file.name}');
          }
        }

        // Show feedback
        String feedbackMessage;
        if (errors.isEmpty) {
          feedbackMessage = '$successCount file(s) added successfully.';
        } else {
          feedbackMessage =
              '$successCount file(s) added. Errors: ${errors.join(', ')}';
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(feedbackMessage)));

        // TODO: Need a way to refresh the new file list widget after adding files.
        // This might involve a dedicated provider for the file list.
        if (successCount > 0) {
          // Invalidate or refresh the file list provider here
        }
      } else {
        // User canceled the picker or selected no files
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File selection cancelled.')),
        );
      }
    } catch (e) {
      // Handle exceptions during picking or directory creation
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('An error occurred: $e')));
    }
  }

  // Removed _showYearManagementDialog

  @override
  Widget build(BuildContext context) {
    const double topPadding = 8.0; // Define padding amount

    // Watch settings provider
    final settingsState = ref.watch(settingsProvider);
    // Removed years provider watch

    // TabController is now initialized in initState with fixed length 2

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700, // Adjusted dark blue
        elevation: 6.0, // Keep elevation for shadow
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
          ), // Ensure title is visible
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ), // Ensure icons are visible
        actionsIconTheme: const IconThemeData(
          color: Colors.white,
        ), // Ensure action icons are visible
        actions: [], // Remove settings button from here
        bottom: PreferredSize(
          // Toolbar is now always shown, so height is constant
          preferredSize: Size.fromHeight(
            kToolbarHeight + // Height of AppToolbar (always present)
                kTextTabBarHeight + // Height of TabBar
                1.0 + // Divider (if any, or just padding)
                topPadding, // Top padding
          ),
          // Wrap the bottom section content in a Material/Container to set its background
          child: Material(
            // Use Material for consistent theming/elevation effects if needed
            color: Colors.blue.shade100, // Adjusted lighter blue background
            child: Column(
              children: [
                const SizedBox(height: topPadding), // Add padding above the Row
                // REMOVED Divider here - AppBar elevation provides separation
                Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        controller: _tabController!,
                        isScrollable: true, // Align tabs to the left
                        tabAlignment:
                            TabAlignment.start, // Explicitly align start
                        tabs: const [
                          // Fixed tabs
                          Tab(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Analysis',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'medical insights',
                                  style: TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          Tab(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Medical Records', // Rename tab label
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'browse records',
                                  style: TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Add settings button here, aligned to the right
                    IconButton(
                      icon: const Icon(Icons.settings),
                      tooltip: 'Settings',
                      color:
                          Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant, // Use appropriate color
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8), // Add some padding
                  ],
                ),
                // Always display the AppToolbar (it handles its own content based on index)
                AppToolbar(
                  currentIndex: _currentIndex,
                  analysisTabIndex:
                      _analysisTabIndex, // Keep for logic inside toolbar if needed
                  onAddRecord: _addFiles, // Use the new add files method
                  // Pass other callbacks if needed
                ),
              ],
            ),
          ),
        ),
      ),
      // Use settingsState to handle loading/error for the main body
      body: Builder(
        // Use Builder to access settingsState easily
        builder: (context) {
          if (settingsState.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (settingsState.error != null) {
            return Center(
              child: Text('Error loading settings: ${settingsState.error}'),
            );
          }
          // Get path from loaded state (still needed for the file list)
          final basePathData =
              settingsState.medicalRecordsPath; // Use renamed property

          // Build the TabBarView with fixed children
          return TabBarView(
            controller: _tabController!,
            children: [
              // Analysis Tab - Now just the centered page
              const AnalysisTabPage(),
              // Medical Records Tab
              const MedicalRecordsPage(), // Use the renamed widget
            ],
          );
        },
      ),
    );
  }
}
