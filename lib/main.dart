import 'dart:math'; // Import for math functions (log)
import 'package:flutter/material.dart';
import 'models/year.dart';
import 'pages/settings_page.dart'; // Import SettingsPage
import 'services/settings_service.dart'; // Import SettingsService
import 'services/year_service.dart'; // Re-add import for YearManagementDialog
import 'widgets/year_management_dialog.dart'; // Keep for now, but logic will change
import 'widgets/year_records_grid.dart'; // Import YearRecordsGrid
import 'widgets/summary_sidebar.dart'; // Import the new sidebar widget
import 'widgets/app_toolbar.dart'; // Import the new toolbar widget
import 'widgets/year_tab_page.dart'; // Import the new tab page widget
import 'providers/selected_file_provider.dart'; // Import the selected file provider
import 'providers/settings_provider.dart'; // Import the settings provider
import 'providers/year_service_provider.dart'; // Import the year service provider
import 'providers/years_provider.dart'; // Import the years provider
import 'dart:io'; // Import dart:io for File and Directory
import 'package:file_picker/file_picker.dart'; // Import file_picker
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:path/path.dart' as p; // Import path package

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize settings service
  await SettingsService().init();
  // Initialize year service
  final yearService = await YearService.create(); // Create instance
  runApp(
    // Wrap the entire app in a ProviderScope and provide the service instance
    ProviderScope(
      overrides: [yearServiceProvider.overrideWithValue(yearService)],
      child: const MyApp(), // Remove yearService parameter
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
            'Medoki - Analyse Medical Documents with AI', // Changed AppBar Title
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
  // late List<Year> years; // Removed - use yearsProvider
  int _currentIndex = 0; // To track the current tab index
  // String? _basePath; // Removed - use basePathProvider
  // bool _isBasePathLoading = true; // Removed - use basePathProvider state
  // Define the index for the static Analysis tab
  final int _analysisTabIndex = 0;
  // Map to hold refresh counters for each year grid
  Map<String, int> _yearRefreshCounters = {};
  // Removed local state for selected file - will use Riverpod provider

  // initState no longer needed for years initialization
  @override
  void initState() {
    super.initState();
    // Listener setup will happen in build after TabController is created
  }

  @override
  void dispose() {
    // Dispose the controller if it was created
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

  // Method to handle adding a new record
  Future<void> _addRecordForYear(String yearName) async {
    // 1. Read the current base path from the provider
    // Use read() as we are inside a button callback, not build()
    final currentBasePath = ref.read(basePathProvider).value;
    final years = ref.read(yearsProvider); // Read current years list

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

    // 2. Construct target directory path using the path from the provider
    final targetDirectoryPath = p.join(currentBasePath, yearName);

    try {
      // 3. Pick files
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        // 4. Create target directory if it doesn't exist
        final targetDir = Directory(targetDirectoryPath);
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }

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

        // 6. Show feedback
        String feedbackMessage;
        if (errors.isEmpty) {
          feedbackMessage =
              '$successCount file(s) added to $yearName successfully.';
        } else {
          feedbackMessage =
              '$successCount file(s) added to $yearName. Errors: ${errors.join(', ')}';
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(feedbackMessage)));

        // 7. Refresh grid by incrementing the counter for this year
        // TODO: This refresh mechanism might need rethinking with Riverpod state.
        // For now, keep the local counter map. A better approach might involve
        // invalidating a provider specific to that year's data.
        if (successCount > 0) {
          setState(() {
            _yearRefreshCounters[yearName] =
                (_yearRefreshCounters[yearName] ?? 0) + 1;
          });
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

  // TODO: Update _showYearManagementDialog to use ref.read(yearsProvider.notifier)
  // For now, keep the old logic but note it needs updating
  void _showYearManagementDialog() {
    // This dialog needs refactoring to use the yearsProvider notifier
    // instead of returning a list and calling setState here.
    // It also needs access to the YearService, ideally via the provider.
    final yearService = ref.read(
      yearServiceProvider,
    ); // Get service via provider
    showDialog<bool>(
      // Dialog likely just needs to signal success/failure now
      context: context,
      builder: (context) => YearManagementDialog(yearService: yearService),
    );
    // No .then() needed here as the provider handles state updates & UI rebuilds
  }

  @override
  Widget build(BuildContext context) {
    const double topPadding = 8.0; // Define padding amount

    // Watch providers
    final basePathAsyncValue = ref.watch(basePathProvider);
    final years = ref.watch(yearsProvider); // Watch the years list

    // --- TabController Initialization/Update ---
    // Check if TabController needs initialization or update due to years list change
    if (_tabController == null || _tabController!.length != years.length + 1) {
      final initialIndex =
          _tabController?.index ?? 0; // Preserve index if possible
      _tabController?.removeListener(
        _handleTabSelection,
      ); // Remove old listener
      _tabController?.dispose(); // Dispose old controller if exists
      _tabController = TabController(
        length: years.length + 1, // Use length from provider
        vsync: this,
        initialIndex: (initialIndex < years.length + 1) ? initialIndex : 0,
      );
      _tabController!.addListener(
        _handleTabSelection,
      ); // Add listener to new controller
      // Ensure _currentIndex is updated if the controller was recreated at a different index
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentIndex != _tabController!.index) {
          setState(() {
            _currentIndex = _tabController!.index;
          });
        }
      });
    }
    // --- End TabController ---

    // Sidebar instantiation removed - will be handled within YearTabPage

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
        actions: [
          // Add actions list for the settings button
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          // Adjust height to include padding
          preferredSize: const Size.fromHeight(
            kToolbarHeight +
                kTextTabBarHeight +
                1.0 +
                topPadding, // Add padding to height
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
                        controller:
                            _tabController!, // Use ! as it's guaranteed initialized here
                        tabs: [
                          // Static Analysis tab
                          const Tab(
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
                          // Dynamic year tabs
                          ...years.map((year) {
                            // Use years from provider
                            return Tab(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    year.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 0,
                                  ), // Removed explicit height
                                  const Text(
                                    'medical records',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    // Edit years button
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: _showYearManagementDialog,
                      tooltip: 'Add/Edit Years',
                    ),
                  ],
                ),
                // Use the extracted AppToolbar widget
                AppToolbar(
                  currentIndex: _currentIndex,
                  analysisTabIndex: _analysisTabIndex,
                  // selectedFilePath removed - AppToolbar gets it from provider
                  onAddRecord: () {
                    // Call add record for the currently selected year tab
                    // Adjust index because years list doesn't include Analysis tab
                    if (_currentIndex > 0 && _currentIndex <= years.length) {
                      // Use years list from provider
                      _addRecordForYear(years[_currentIndex - 1].name);
                    }
                  },
                  // onClearSelection removed - AppToolbar calls provider directly
                  // Pass other callbacks like onSearch, onFilter, onGenerateReport if needed
                ),
              ],
            ),
          ),
        ),
      ),
      // Use basePathAsyncValue.when for the main body
      body: basePathAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading path: $err')),
        data: (basePathData) {
          // Build the TabBarView only when basePathData is available
          return TabBarView(
            controller:
                _tabController!, // Use ! as it's guaranteed initialized here
            children: [
              // Analysis tab content view (unchanged)
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Medical Analysis',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text('This is the Analysis tab content'),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: null, // Placeholder action
                      child: Text('Generate Analysis'),
                    ),
                  ],
                ),
              ),
              // Dynamic year tabs
              ...years.map((year) {
                // Use years from provider
                final refreshCounter = _yearRefreshCounters[year.name] ?? 0;
                // Note: We removed the direct sidebar passing earlier.
                // YearTabPage now builds its own sidebar using providers.
                return YearTabPage(
                  key: ValueKey(
                    '${year.name}-$basePathData-$refreshCounter', // Use basePathData in key
                  ),
                  yearName: year.name,
                  basePath: basePathData, // Pass loaded base path
                  refreshCounter: refreshCounter,
                  onAddRecord: () => _addRecordForYear(year.name),
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }
}
